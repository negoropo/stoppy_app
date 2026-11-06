import assert from 'node:assert/strict';
import { test } from 'node:test';
import { randomUUID } from 'node:crypto';
import { FakeDatabase } from './fakes.js';
import { KnockoutRegistrationService, KnockoutRegistrationFailure, InvalidKnockoutRegistrationIntent } from '../src/knockout/knockout_registration_service.js';

const command = () => ({ playerId: randomUUID(), tournamentId: randomUUID(), idempotencyKey: randomUUID() });
class RegistrationDatabase extends FakeDatabase {
  balance: number | null = 50;
  failAdmission = false;
  override async query(sql: string, values?: unknown[]) {
    const result = await super.query(sql, values);
    if (sql.includes('FROM stoppy_knockout.tournaments')) return { rows: [{ id: values![0], status: 'registrationClosed',
      registration_opens_at: new Date('2030-01-01Z'), registration_closes_at: new Date('2030-02-01Z'), starts_at: new Date('2030-03-01Z') }] };
    if (sql.includes('FROM stoppy_auth.players')) return { rows: this.balance === null ? [] : [{ game_points: this.balance }] };
    if (sql.startsWith('WITH admission_clock')) {
      if (this.failAdmission) throw new Error('password=secret');
      return { rows: [{ admitted_at: '2030-01-15 00:00:00.123456+00', started: false, within_window: true }] };
    }
    return result;
  }
}

test('registration validates and snapshots trusted identity/key before acquiring a connection', async () => {
  for (const invalid of [{ playerId: '' }, { tournamentId: 'client-month' }, { idempotencyKey: ' ' }, { idempotencyKey: 'x'.repeat(129) }]) {
    const db = new RegistrationDatabase();
    await assert.rejects(new KnockoutRegistrationService(db).register({ ...command(), ...invalid }), InvalidKnockoutRegistrationIntent);
    assert.equal(db.connections, 0);
  }
  const db = new RegistrationDatabase();
  const input = command();
  const expected = { ...input };
  const connect = db.connect.bind(db);
  db.connect = async () => { input.playerId = randomUUID(); input.tournamentId = randomUUID(); input.idempotencyKey = randomUUID(); return connect(); };
  await new KnockoutRegistrationService(db).register(input);
  const insert = db.calls.find((c) => c.sql.includes('INSERT INTO stoppy_knockout.registration_operations'))!;
  assert.equal(insert.values![0], expected.playerId);
  assert.equal(insert.values![3], expected.idempotencyKey);
  assert.equal(insert.values![6], expected.tournamentId);
});

test('closed admission commits only a durable business rejection, under ordered catalog/player locks', async () => {
  const db = new RegistrationDatabase();
  const result = await new KnockoutRegistrationService(db).register(command());
  assert.ok(result.status === 'completed' && result.outcome.status === 'rejected');
  assert.equal(result.outcome.reason, 'registrationClosed');
  const calls = db.calls.map((c) => c.sql);
  assert.ok(calls.findIndex((s) => s.includes('pg_advisory_xact_lock_shared')) < calls.findIndex((s) => s.includes('FOR UPDATE')));
  assert.ok(calls.findIndex((s) => s.includes('FOR UPDATE')) < calls.findIndex((s) => s.includes('clock_timestamp')));
  assert.equal(calls.filter((s) => s === 'BEGIN').length, 1);
  assert.equal(calls.at(-1), 'COMMIT');
  assert.ok(!calls.some((s) => s.includes('INSERT INTO stoppy_economy')));
  assert.deepEqual(db.released, [false]);
  const outcome = db.calls.find((c) => c.sql.includes('INSERT INTO stoppy_knockout.registration_operations'))!;
  assert.equal(outcome.values![11], '2030-01-15 00:00:00.123456+00');
  assert.ok(outcome.sql.includes('GREATEST($12::timestamptz, clock_timestamp())'));
});

test('missing authenticated player is distinct and cannot persist an operation', async () => {
  const db = new RegistrationDatabase();
  db.balance = null;
  assert.deepEqual(await new KnockoutRegistrationService(db).register(command()), { status: 'missingPlayer' });
  assert.ok(!db.calls.some((c) => c.sql.includes('INSERT')));
});

for (const failure of ['BEGIN', 'setup', 'COMMIT', 'operation', 'acquire']) {
  test(`registration ${failure} failure is sanitized and never retried`, async () => {
    const db = new RegistrationDatabase();
    if (failure === 'acquire') db.connect = async () => { db.connections++; throw new Error('password=secret'); };
    else if (failure === 'operation') db.failAdmission = true;
    else db.failureSql = failure === 'setup' ? 'SET TRANSACTION ISOLATION LEVEL READ COMMITTED' : failure;
    await assert.rejects(new KnockoutRegistrationService(db).register(command()), (error: unknown) => {
      assert.ok(error instanceof KnockoutRegistrationFailure);
      assert.equal(error.code, failure === 'COMMIT' ? 'commitOutcomeUnknown' : 'infrastructureFailure');
      assert.ok(!error.message.includes('secret'));
      return true;
    });
    assert.equal(db.connections, 1);
    if (failure !== 'acquire') assert.equal(db.calls.filter((c) => c.sql === 'BEGIN').length, 1);
    if (failure === 'COMMIT') { assert.equal(db.calls.at(-1)!.sql, 'COMMIT'); assert.deepEqual(db.released, [true]); }
  });
}
