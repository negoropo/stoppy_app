import { test } from 'node:test';
import assert from 'node:assert/strict';
import { get } from 'node:http';
import { setImmediate as nextTurn } from 'node:timers/promises';
import { buildApp } from '../../src/app.js';
import { FakeDatabase, testConfig } from '../fakes.js';

test('real HTTP shutdown drains an in-flight request before closing the database pool', async () => {
  const database = new FakeDatabase();
  const app = buildApp(testConfig, database);
  let enter!: () => void;
  let finish!: () => void;
  const entered = new Promise<void>((resolve) => { enter = resolve; });
  const gate = new Promise<void>((resolve) => { finish = resolve; });
  app.get('/test-in-flight', async () => {
    enter();
    await gate;
    return { success: true, data: {} };
  });
  try {
    await app.listen({ host: '127.0.0.1', port: 0 });
    const address = app.server.address();
    assert.ok(address && typeof address === 'object');
    // Injection does not open a server socket and cannot test Node's drain
    // behavior. This opt-in test uses an ephemeral loopback socket and gates.
    const response = new Promise<number | undefined>((resolve, reject) => {
      get(`http://127.0.0.1:${address.port}/test-in-flight`, (res) => {
        res.resume();
        res.on('end', () => resolve(res.statusCode));
        res.on('error', reject);
      }).on('error', reject);
    });
    await entered;
    const closed = app.close();
    await nextTurn();
    assert.equal(database.closed, 0);
    finish();
    assert.equal(await response, 200);
    await closed;
    assert.equal(database.closed, 1);
  } finally {
    finish();
    await app.close();
  }
});
