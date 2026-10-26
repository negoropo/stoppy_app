import { test } from 'node:test';
import assert from 'node:assert/strict';
import { inTransaction } from '../src/transaction.js';
import { EventDatabaseClient, FakeDatabase } from './fakes.js';
import { protectTransactionConnection } from '../src/database.js';

test('feature transaction returns only after commit and releases once', async () => {
  const db = new FakeDatabase();
  assert.equal(await inTransaction(db, async (connection) => { await connection.query('operation'); return 5; }), 5);
  assert.deepEqual(db.calls.map((call) => call.sql), ['BEGIN', "SET LOCAL lock_timeout = '3s'", 'operation', 'COMMIT']);
  assert.deepEqual(db.released, [false]);
});

for (const stage of ['BEGIN', 'operation', 'COMMIT', 'rollback'] as const) {
  test(`feature transaction safely handles ${stage} failure without retry`, async () => {
    const db = new FakeDatabase();
    db.failureSql = stage === 'rollback' ? 'operation' : stage;
    db.rollbackFails = stage === 'rollback';
    await assert.rejects(inTransaction(db, async (connection) => connection.query('operation')));
    assert.deepEqual(db.released, [stage !== 'operation']);
    assert.equal(db.connections, 1);
    assert.equal(db.calls.filter((call) => call.sql === 'ROLLBACK').length, ['operation', 'rollback'].includes(stage) ? 1 : 0);
    assert.equal(db.calls.filter((call) => call.sql === 'COMMIT').length, stage === 'COMMIT' ? 1 : 0);
  });
}

for (const stage of ['before BEGIN', 'operation', 'between queries', 'COMMIT', 'ROLLBACK'] as const) {
  test(`emitted error ${stage} discards the connection and never replays the transaction`, async () => {
    const raw = new EventDatabaseClient();
    const connection = protectTransactionConnection(raw);
    let connects = 0;
    const database = {
      query: async () => ({ rows: [] }), close: async () => {},
      connect: async () => {
        connects++;
        if (stage === 'before BEGIN') raw.emit('error', new Error('SECRET_SOCKET'));
        return connection;
      },
    };
    raw.beforeQuery = (sql) => {
      if (stage === 'ROLLBACK' && sql === 'operation') throw new Error('SQL failure');
      if (sql === stage || (stage === 'operation' && sql === 'operation')) {
        raw.emit('error', new Error('SECRET_SOCKET'));
        // A real socket error is not necessarily accompanied by a rejected promise.
        return new Promise<void>(() => {});
      }
    };
    await assert.rejects(inTransaction(database, async (client) => {
      await client.query('operation');
      if (stage === 'between queries') raw.emit('error', new Error('SECRET_SOCKET'));
      return 'credentials';
    }));
    assert.equal(connects, 1);
    assert.deepEqual(raw.releases, [true]);
    assert.equal(raw.calls.filter((sql) => sql === 'COMMIT').length, stage === 'COMMIT' ? 1 : 0);
    assert.equal(raw.calls.filter((sql) => sql === 'BEGIN').length, stage === 'before BEGIN' ? 0 : 1);
    assert.equal(raw.calls.filter((sql) => sql === 'ROLLBACK').length, stage === 'ROLLBACK' ? 1 : 0);
    assert.deepEqual(raw.listeners('error'), [raw.idleError]);
  });
}

test('error immediately before release discards once without undoing a confirmed commit', async () => {
  const raw = new EventDatabaseClient();
  const guarded = protectTransactionConnection(raw);
  const database = {
    query: async () => ({ rows: [] }), close: async () => {},
    connect: async () => ({ query: guarded.query, release: (discard?: boolean) => {
      raw.emit('error', new Error('SECRET_SOCKET'));
      guarded.release(discard);
    } }),
  };
  assert.equal(await inTransaction(database, async () => 'confirmed'), 'confirmed');
  assert.equal(raw.calls.at(-1), 'COMMIT');
  assert.deepEqual(raw.releases, [true]);
  assert.deepEqual(raw.listeners('error'), [raw.idleError]);
});
