import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { buildApp } from '../../src/app.js';
import { loadConfig } from '../../src/config.js';
import { checkDatabase, createDatabase } from '../../src/database.js';
import { readMigrations, runMigrations } from '../../src/migrations.js';

test('real PostgreSQL connectivity, concurrent migration locking, replay and rollback', async () => {
  const url = process.env.TEST_DATABASE_URL;
  if (!url || process.env.NODE_ENV !== 'test' || !new URL(url).pathname.endsWith('_test')) {
    throw new Error('Use NODE_ENV=test and TEST_DATABASE_URL pointing to a disposable *_test database.');
  }
  const config = loadConfig({ ...process.env, NODE_ENV: 'test', LOG_LEVEL: 'silent', DATABASE_URL: url });
  const database = createDatabase(config, () => {}, 'migration');
  const app = buildApp(config, database);
  let ownsFixtures = false;
  try {
    await checkDatabase(database);
    const migrationTimeout = await database.query('SHOW statement_timeout');
    assert.equal(migrationTimeout.rows[0]!.statement_timeout, '2min');
    const apiDatabase = createDatabase(config, () => {});
    try {
      const apiTimeout = await apiDatabase.query('SHOW statement_timeout');
      assert.equal(apiTimeout.rows[0]!.statement_timeout, '5s');
    } finally { await apiDatabase.close(); }
    const existing = await database.query(`SELECT
      to_regclass('public.stoppy_schema_migrations') AS ledger,
      to_regnamespace('stoppy_runtime') AS runtime`);
    assert.equal(existing.rows[0]!.ledger, null, 'Test database already has migration state; refusing to alter it.');
    assert.equal(existing.rows[0]!.runtime, null, 'Test database already has runtime schema; refusing to alter it.');
    ownsFixtures = true;
    const migrations = await readMigrations();
    const results = await Promise.all([runMigrations(database, migrations), runMigrations(database, migrations)]);
    assert.deepEqual(results.sort(), [0, 1]);
    assert.equal(await runMigrations(database, migrations), 0);
    assert.equal((await app.inject('/api/v1/ready')).statusCode, 200);
    const failingSql = 'CREATE TABLE stoppy_runtime.rollback_probe (id integer); SELECT 1 / 0;';
    await assert.rejects(runMigrations(database, [...migrations, {
      version: '002_rollback_probe.sql',
      checksum: createHash('sha256').update(failingSql).digest('hex'),
      sql: failingSql,
    }]), (error: unknown) => {
      assert.ok(error instanceof Error && 'code' in error);
      assert.equal(error.code, '22012'); // Prove SQL executed and failed, not just list validation.
      return true;
    });
    const probe = await database.query("SELECT to_regclass('stoppy_runtime.rollback_probe') AS table_name");
    assert.equal(probe.rows[0]!.table_name, null);
    const ledger = await database.query('SELECT version FROM public.stoppy_schema_migrations');
    assert.equal(ledger.rows.length, 1);
  } finally {
    try {
      // Only these fixtures are owned by this test, in an explicit disposable DB.
      if (ownsFixtures) {
        await database.query('DROP SCHEMA IF EXISTS stoppy_runtime CASCADE');
        await database.query('DROP TABLE IF EXISTS public.stoppy_schema_migrations');
      }
    } finally { await app.close(); }
  }
});
