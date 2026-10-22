import { test } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import { loadConfig } from '../src/config.js';
import { databaseOptions } from '../src/database.js';
import { testConfig } from './fakes.js';

test('API and migration queries use separate finite budgets with cancellation margins', () => {
  const api = databaseOptions(testConfig);
  const migration = databaseOptions(testConfig, 'migration');
  assert.equal(api.statement_timeout, 5000);
  assert.equal(api.query_timeout, 6000);
  assert.equal(migration.statement_timeout, 120000);
  assert.equal(migration.query_timeout, 125000);
  for (const options of [api, migration]) {
    assert.equal(options.connectionTimeoutMillis, 3000);
    assert.ok(options.query_timeout! > Number(options.statement_timeout));
    assert.equal(options.max, 5);
  }
});

test('production pg options preserve certificate/hostname verification and ignore insecure PGSSLMODE', () => {
  const previous = process.env.PGSSLMODE;
  process.env.PGSSLMODE = 'no-verify';
  try {
  const config = loadConfig({
    NODE_ENV: 'production', DATABASE_SSL: 'verify-full',
    DATABASE_URL: 'postgresql://user:secret@db.example.test/stoppy',
  });
  for (const purpose of ['api', 'migration'] as const) {
    const options = databaseOptions(config, purpose);
    assert.deepEqual(options.ssl, { rejectUnauthorized: true });
    // Constructing a client exercises the installed driver's URL/environment
    // merge without opening a socket. No custom checkServerIdentity overrides
    // Node TLS's default hostname verification.
    const client = new pg.Client(options);
    assert.deepEqual(client.ssl, { rejectUnauthorized: true });
  }
  } finally {
    if (previous === undefined) delete process.env.PGSSLMODE;
    else process.env.PGSSLMODE = previous;
  }
});
