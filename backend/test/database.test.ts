import { test } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import { loadConfig } from '../src/config.js';
import { databaseOptions, protectTransactionConnection } from '../src/database.js';
import { EventDatabaseClient, testConfig } from './fakes.js';
import { spawnSync } from 'node:child_process';

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
    AUTH_PRIVATE_KEY: testConfig.auth.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
    AUTH_ISSUER: 'stoppy-test', AUTH_AUDIENCE: 'stoppy-test-app',
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

test('healthy checked-out connections hand listeners back to the pool and release only once', async () => {
  const raw = new EventDatabaseClient();
  const connection = protectTransactionConnection(raw);
  assert.equal(raw.listenerCount('error'), 1);
  await connection.query('SELECT 1');
  connection.release();
  connection.release(true);
  assert.deepEqual(raw.releases, [false]);
  assert.deepEqual(raw.listeners('error'), [raw.idleError]);
  await assert.rejects(connection.query('after release'), /unavailable/);
  assert.deepEqual(raw.calls, ['SELECT 1']);
  // A subsequent healthy checkout does not accumulate wrapper listeners.
  raw.removeListener('error', raw.idleError);
  const next = protectTransactionConnection(raw);
  await next.query('SELECT 2');
  next.release();
  assert.deepEqual(raw.releases, [false, false]);
  assert.deepEqual(raw.listeners('error'), [raw.idleError]);
});

test('connection error events before a query are handled and force discard without executing SQL', async () => {
  const raw = new EventDatabaseClient();
  const connection = protectTransactionConnection(raw);
  assert.doesNotThrow(() => raw.emit('error', new Error('SECRET_CONNECTION')));
  await assert.rejects(connection.query('BEGIN'), (error: unknown) => error instanceof Error &&
    error.message === 'Database connection is unavailable.');
  connection.release();
  connection.release();
  assert.deepEqual(raw.calls, []);
  assert.deepEqual(raw.releases, [true]);
  assert.deepEqual(raw.listeners('error'), [raw.idleError]);
});

test('error event rejects a pending query even if the driver never rejects its promise', async () => {
  const raw = new EventDatabaseClient();
  raw.beforeQuery = () => new Promise<void>(() => {});
  const connection = protectTransactionConnection(raw);
  const query = connection.query('pending');
  raw.emit('error', new Error('SECRET_CONNECTION'));
  await assert.rejects(query, /Database connection is unavailable/);
  connection.release();
  assert.deepEqual(raw.releases, [true]);
});

test('error event between successful queries prevents further use and forces discard', async () => {
  const raw = new EventDatabaseClient();
  const connection = protectTransactionConnection(raw);
  await connection.query('first');
  raw.emit('error', new Error('SECRET_CONNECTION'));
  await assert.rejects(connection.query('second'), /unavailable/);
  connection.release();
  assert.deepEqual(raw.calls, ['first']);
  assert.deepEqual(raw.releases, [true]);
});

test('ordinary SQL errors retain machine-readable codes without marking the socket broken', async () => {
  const raw = new EventDatabaseClient();
  const duplicate = Object.assign(new Error('duplicate'), { code: '23505' });
  raw.beforeQuery = (sql) => { if (sql === 'INSERT') throw duplicate; };
  const connection = protectTransactionConnection(raw);
  await assert.rejects(connection.query('INSERT'), (error: unknown) => error === duplicate);
  await connection.query('ROLLBACK');
  connection.release();
  assert.deepEqual(raw.releases, [false]);
});

test('acquired socket errors do not crash or expose raw credentials in application logs', () => {
  const script = `
    import { buildApp } from './src/app.ts';
    import { protectTransactionConnection } from './src/database.ts';
    import { inTransaction } from './src/transaction.ts';
    import { EventDatabaseClient, testConfig } from './test/fakes.ts';
    const raw = new EventDatabaseClient();
    raw.beforeQuery = (sql) => {
      if (sql === 'COMMIT') {
        raw.emit('error', new Error('SECRET_DATABASE_CREDENTIALS'));
        return new Promise(() => {});
      }
    };
    const db = {query:async()=>({rows:[]}),connect:async()=>protectTransactionConnection(raw),close:async()=>{}};
    const app = buildApp({...testConfig,logLevel:'info'},db);
    app.get('/probe',async()=>inTransaction(db,async()=>({credentials:'must-not-be-returned'})));
    const result=await app.inject('/probe');
    if(result.statusCode!==500 || raw.releases.length!==1 || raw.releases[0]!==true || result.body.includes('credentials')) process.exitCode=1;
    await app.close();
  `;
  const result = spawnSync(process.execPath, ['--import', 'tsx', '--input-type=module', '-e', script], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Request failed/);
  assert.doesNotMatch(result.stdout + result.stderr, /SECRET_DATABASE_CREDENTIALS/);
});
