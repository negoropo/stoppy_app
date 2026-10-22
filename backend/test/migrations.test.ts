import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readMigrations, runMigrations } from '../src/migrations.js';
import { FakeDatabase } from './fakes.js';

function migration(version: string, sql = 'SELECT 1') {
  return { version, sql, checksum: createHash('sha256').update(sql).digest('hex') };
}

test('direct migration execution rejects empty, malformed, missing, duplicate or unordered versions before connection', async () => {
  const first = migration('001_first.sql');
  const second = migration('002_second.sql');
  for (const migrations of [[], [second], [first, first], [second, first],
    [first, migration('003_third.sql')], [migration('000_zero.sql')],
    [migration('1_short.sql')], [migration('001_bad-name.sql')],
    [migration('001_first.sql', ' ')], [{ ...first, checksum: 'incorrect' }],
    [{ ...first, sql: 'SELECT 2' }]]) {
    const database = new FakeDatabase();
    await assert.rejects(runMigrations(database, migrations));
    assert.equal(database.connections, 0);
    assert.deepEqual(database.calls, []);
  }
});

test('direct migration execution accepts consecutive additions and detects invalid applied prefixes', async () => {
  const first = migration('001_first.sql');
  const second = migration('002_second.sql', 'SELECT 2');
  const database = new FakeDatabase();
  database.applied = [{ version: first.version, checksum: first.checksum }];
  assert.equal(await runMigrations(database, [first, second]), 1);
  assert.ok(!database.calls.some((call) => call.sql === first.sql));
  for (const applied of [
    [{ version: second.version, checksum: second.checksum }],
    [{ version: first.version, checksum: first.checksum }, { version: first.version, checksum: first.checksum }],
  ]) {
    const invalid = new FakeDatabase();
    invalid.applied = applied;
    await assert.rejects(runMigrations(invalid, [first, second]), /history differs/);
    assert.equal(invalid.calls.at(-1)!.sql, 'ROLLBACK');
  }
});

test('execution uses a validated snapshot even when the supplied list changes while acquiring a connection', async () => {
  const first = migration('001_first.sql');
  const supplied = [first];
  const database = new FakeDatabase();
  const originalConnect = database.connect.bind(database);
  database.connect = async () => {
    first.sql = 'SELECT 99';
    supplied.length = 0;
    return originalConnect();
  };
  assert.equal(await runMigrations(database, supplied), 1);
  assert.ok(database.calls.some((call) => call.sql === 'SELECT 1'));
  assert.ok(!database.calls.some((call) => call.sql === 'SELECT 99'));
});

for (const stage of ['BEGIN', 'COMMIT']) {
  test(`${stage} failure discards the uncertain connection without replay or subsequent SQL`, async () => {
    const database = new FakeDatabase();
    database.failureSql = stage;
    await assert.rejects(runMigrations(database, await readMigrations()));
    assert.equal(database.calls.filter((call) => call.sql === stage).length, 1);
    assert.equal(database.calls.at(-1)!.sql, stage);
    assert.deepEqual(database.released, [true]);
  });
}

test('migration files have stable ordered checksums and execute transactionally', async () => {
  const migrations = await readMigrations();
  assert.equal(migrations.length, 1);
  assert.equal(migrations[0]!.version, '001_runtime_foundation.sql');
  assert.match(migrations[0]!.checksum, /^[0-9a-f]{64}$/);
  const database = new FakeDatabase();
  assert.equal(await runMigrations(database, migrations), 1);
  assert.equal(database.calls[0]!.sql, 'BEGIN');
  assert.equal(database.calls.at(-1)!.sql, 'COMMIT');
  const insert = database.calls.find((call) => call.sql.startsWith('INSERT'))!;
  assert.ok(insert.sql.includes('$1, $2'));
  assert.deepEqual(insert.values, [migrations[0]!.version, migrations[0]!.checksum]);
  assert.deepEqual(database.released, [false]);
});

test('an applied migration is not executed again', async () => {
  const migrations = await readMigrations();
  const database = new FakeDatabase();
  database.applied = migrations.map(({ version, checksum }) => ({ version, checksum }));
  assert.equal(await runMigrations(database, migrations), 0);
  assert.ok(!database.calls.some((call) => call.sql === migrations[0]!.sql));
});

test('changed or missing migration history is rejected and rolled back', async () => {
  for (const applied of [[{ version: '001_runtime_foundation.sql', checksum: 'changed' }],
    [{ version: '999_missing.sql', checksum: 'unknown' }]]) {
    const database = new FakeDatabase();
    database.applied = applied;
    await assert.rejects(runMigrations(database, await readMigrations()), /history differs/);
    assert.equal(database.calls.at(-1)!.sql, 'ROLLBACK');
    assert.deepEqual(database.released, [false]);
  }
});

test('failed migration rolls back and discards connection if rollback also fails', async () => {
  const migrations = await readMigrations();
  for (const rollbackFails of [false, true]) {
    const database = new FakeDatabase();
    database.failureSql = migrations[0]!.sql;
    database.rollbackFails = rollbackFails;
    await assert.rejects(runMigrations(database, migrations));
    assert.ok(!database.calls.some((call) => call.sql === 'COMMIT'));
    assert.deepEqual(database.released, [rollbackFails]);
  }
});
