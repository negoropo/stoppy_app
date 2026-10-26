import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import { startApplication } from '../src/lifecycle.js';
import { FakeDatabase, testConfig } from './fakes.js';

test('health returns the Flutter success/data envelope without querying PostgreSQL', async () => {
  const database = new FakeDatabase();
  database.failureSql = 'SELECT 1 AS connected';
  const app = buildApp(testConfig, database);
  try {
    const response = await app.inject({ method: 'GET', url: '/api/v1/health' });
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { success: true, data: { status: 'ok', service: 'stoppy-api' } });
    assert.equal(response.headers['cache-control'], 'no-store');
    assert.equal(response.headers['x-content-type-options'], 'nosniff');
    assert.equal(response.headers['access-control-allow-origin'], undefined);
    assert.equal(database.calls.length, 0);
  } finally { await app.close(); }
  assert.equal(database.closed, 1);
});

test('readiness checks connectivity and returns a safe 503 error on database outage', async () => {
  const database = new FakeDatabase();
  const app = buildApp(testConfig, database);
  try {
    assert.deepEqual((await app.inject('/api/v1/ready')).json(), { success: true, data: { status: 'ready' } });
    database.failureSql = 'SELECT 1 AS connected';
    const response = await app.inject('/api/v1/ready');
    assert.equal(response.statusCode, 503);
    assert.deepEqual(response.json(), { success: false, error: { code: 'serverError', message: 'Service is not ready.' } });
    assert.equal((await app.inject('/api/v1/health')).statusCode, 200);
  } finally { await app.close(); }
});

test('unknown paths and unimplemented competitive endpoints return notFound envelopes', async () => {
  const app = buildApp(testConfig, new FakeDatabase());
  try {
    for (const url of ['/missing', '/health', '/api/v1/auth/logout', '/api/v1/runs/knockout', '/api/v1/runs/league']) {
      const response = await app.inject({ method: 'POST', url });
      assert.equal(response.statusCode, 404);
      assert.deepEqual(response.json(), { success: false, error: { code: 'notFound', message: 'Route not found.' } });
    }
  } finally { await app.close(); }
});

test('central handler hides unexpected internals and normalizes invalid/oversized JSON', async () => {
  const app = buildApp(testConfig, new FakeDatabase());
  // Test-only routes exercise the shared boundary without adding runtime APIs.
  app.get('/test-error', async () => { throw new Error('password=secret SQL'); });
  app.post('/test-body', async () => ({ success: true, data: {} }));
  try {
    const error = await app.inject('/test-error');
    assert.equal(error.statusCode, 500);
    assert.deepEqual(error.json(), { success: false, error: { code: 'serverError', message: 'Internal server error.' } });
    for (const [payload, status] of [['{', 400], ['"' + 'a'.repeat(17000) + '"', 413]] as const) {
      const response = await app.inject({ method: 'POST', url: '/test-body', payload, headers: { 'content-type': 'application/json' } });
      assert.equal(response.statusCode, status);
      assert.equal(response.json().error.code, 'validationFailed');
    }
  } finally { await app.close(); }
});

test('startup fails before binding and closes resources when database is unavailable', async () => {
  const database = new FakeDatabase();
  database.failureSql = 'SELECT 1 AS connected';
  let listened = false;
  await assert.rejects(startApplication(testConfig, database, async () => { listened = true; }));
  assert.equal(listened, false);
  assert.equal(database.closed, 1);
});

test('listen failure closes database and normal shutdown closes it once', async () => {
  const failed = new FakeDatabase();
  await assert.rejects(startApplication(testConfig, failed, async () => { throw new Error('bind failed'); }));
  assert.equal(failed.closed, 1);
  const database = new FakeDatabase();
  const app = await startApplication(testConfig, database, async (instance) => { await instance.ready(); });
  await app.close();
  await app.close();
  assert.equal(database.closed, 1);
});
