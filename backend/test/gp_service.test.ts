import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { canonicalIntent, gpIntegerMax, InvalidGpIntent, prepareGpIntent, type GpCommand } from '../src/economy/gp_intent.js';
import { GpExecutionFailure, GpService } from '../src/economy/gp_service.js';
import { GpRepository, type GpOutcome } from '../src/economy/gp_repository.js';
import { FakeDatabase } from './fakes.js';

const command = (overrides: Partial<GpCommand> = {}): GpCommand => ({
  playerId: randomUUID(), operationName: 'test_reward', operationVersion: 1, idempotencyKey: randomUUID(),
  amount: 3, reason: 'test_reward', sourceType: 'test_event', sourceId: randomUUID(), context: { event: 'original' }, ...overrides,
});

class GpDatabase extends FakeDatabase {
  balance: number | null = 5;
  opening = true;
  duplicateSource = false;
  previous: { fingerprint_version: number; request_fingerprint: string; semantic_outcome: GpOutcome } | null = null;
  failWhen: (sql: string) => boolean = () => false;
  override async query(sql: string, values?: unknown[]) {
    await super.query(sql, values);
    if (this.failWhen(sql)) throw new Error('PRIVATE_DATABASE_DIAGNOSTIC');
    if (sql.includes('FOR UPDATE')) return { rows: this.balance === null ? [] : [{ game_points: this.balance }] };
    if (sql.includes('SELECT fingerprint_version')) return { rows: this.previous ? [this.previous] : [] };
    if (sql.includes("movement_type = 'opening_snapshot'")) return { rows: this.opening ? [{ id: randomUUID() }] : [] };
    if (sql.includes('SELECT id FROM stoppy_economy.gp_ledger')) return { rows: this.duplicateSource ? [{ id: randomUUID() }] : [] };
    if (sql.startsWith('UPDATE stoppy_auth.players')) return { rows: [{ game_points: (values![1] as number) + (values![2] as number) }] };
    return { rows: [] };
  }
}

const failure = (code: GpExecutionFailure['code']) => (error: unknown) => {
  assert.ok(error instanceof GpExecutionFailure);
  assert.equal(error.code, code);
  assert.ok(!String(error).includes('PRIVATE'));
  return true;
};

test('canonical V1 intent ignores object property order, but preserves JSON types and array order', () => {
  const original = command({ context: { b: [1, '2', null], a: { z: true, c: 7 } } });
  const equivalent = { ...original, context: { a: { c: 7, z: true }, b: [1, '2', null] } };
  assert.equal(prepareGpIntent(original, 'credit').fingerprint, prepareGpIntent(equivalent, 'credit').fingerprint);
  assert.notEqual(canonicalIntent(1), canonicalIntent('1'));
  assert.notEqual(canonicalIntent([1, 2]), canonicalIntent([2, 1]));
  for (const changed of [command({ ...original, amount: 4 }), command({ ...original, sourceId: 'different' }),
    command({ ...original, context: { b: [1, 2, null], a: { z: true, c: 7 } } })]) {
    assert.notEqual(prepareGpIntent(original, 'credit').fingerprint, prepareGpIntent(changed, 'credit').fingerprint);
  }
  assert.notEqual(prepareGpIntent(original, 'credit').fingerprint, prepareGpIntent(original, 'debit').fingerprint);
});

test('non-JSON or ambiguous intent values are rejected, not coerced', () => {
  const circular: Record<string, unknown> = {}; circular.self = circular;
  for (const value of [undefined, NaN, Infinity, 1.5, Number.MAX_SAFE_INTEGER + 1, BigInt(1), new Date(), circular,
    [undefined], Array(1), { hidden: undefined }, '\0', '\ud800', '\udfff',
    { get value() { throw new Error('must not execute'); } }]) {
    assert.throws(() => canonicalIntent(value), InvalidGpIntent);
  }
  assert.throws(() => prepareGpIntent(command({ context: { large: 'x'.repeat(16384) } }), 'credit'), InvalidGpIntent);
  assert.equal(canonicalIntent('\ud83d\ude80'), JSON.stringify('\ud83d\ude80'));
  assert.throws(() => prepareGpIntent(command({ context: 'invalid' as unknown as GpCommand['context'] }), 'credit'), InvalidGpIntent);
});

test('invalid amounts, identifiers and reserved opening sources fail before acquiring a connection', async () => {
  const db = new GpDatabase();
  const service = new GpService(db);
  for (const amount of [0, -1, 1.5, NaN, Infinity, gpIntegerMax + 1]) {
    await assert.rejects(service.credit(command({ amount })), InvalidGpIntent);
    await assert.rejects(service.debit(command({ amount })), InvalidGpIntent);
  }
  for (const overrides of [{ sourceId: '' }, { sourceId: ' bad ' }, { sourceId: 'bad\n' }, { sourceId: 'x'.repeat(257) },
    { sourceType: 'opening_snapshot' }, { reason: 'opening_snapshot' }, { idempotencyKey: 'bad key' },
    { operationVersion: 0 }, { playerId: 'bad' }]) await assert.rejects(service.credit(command(overrides)), InvalidGpIntent);
  assert.equal(db.connections, 0);
});

test('repository is transaction-bound and credit writes only GP, final outcome and ledger in FK-safe order', async () => {
  const db = new GpDatabase();
  const result = await new GpService(db).credit(command());
  assert.equal(result.status, 'completed');
  if (result.status !== 'completed') return;
  assert.equal(result.outcome.status, 'accepted');
  assert.equal(result.currentBalance, 8);
  assert.equal(db.connections, 1);
  assert.deepEqual(db.released, [false]);
  const sql = db.calls.map((call) => call.sql);
  assert.ok(sql.findIndex((s) => s.includes('FOR UPDATE')) < sql.findIndex((s) => s.includes('SELECT fingerprint_version')));
  assert.ok(sql.findIndex((s) => s.startsWith('UPDATE')) < sql.findIndex((s) => s.startsWith('INSERT INTO stoppy_economy.gp_mutations')));
  assert.ok(sql.findIndex((s) => s.startsWith('INSERT INTO stoppy_economy.gp_mutations')) < sql.findIndex((s) => s.startsWith('INSERT INTO stoppy_economy.gp_ledger')));
  assert.equal(sql.at(-1), 'COMMIT');
  assert.equal(sql.filter((s) => s.startsWith('UPDATE')).length, 1);
  assert.match(sql.find((s) => s.startsWith('UPDATE'))!, /game_points::bigint/);
  assert.match(sql.find((s) => s.startsWith('UPDATE'))!, /BETWEEN 0 AND 2147483647/);
});

test('repository guarded-update failure is an invariant error, not an insufficient-funds decision', async () => {
  const repository = new GpRepository({ query: async () => ({ rows: [] }) });
  await assert.rejects(repository.applyDelta(randomUUID(), 5, 1), /invariant/);
});

for (const reason of ['insufficientFunds', 'balanceOverflow', 'duplicateSource'] as const) {
  test(`${reason} persists only a final rejection, with no balance update or movement`, async () => {
    const db = new GpDatabase();
    db.balance = reason === 'balanceOverflow' ? gpIntegerMax : 5;
    db.duplicateSource = reason === 'duplicateSource';
    const service = new GpService(db);
    const result = await (reason === 'insufficientFunds' ? service.debit(command({ amount: 6 })) : service.credit(command()));
    assert.equal(result.status, 'completed');
    if (result.status !== 'completed') return;
    assert.equal(result.outcome.status, 'rejected');
    if (result.outcome.status === 'rejected') assert.equal(result.outcome.reason, reason);
    assert.equal(db.calls.filter((c) => c.sql.startsWith('UPDATE') || c.sql.startsWith('INSERT INTO stoppy_economy.gp_ledger')).length, 0);
    assert.equal(db.calls.filter((c) => c.sql.startsWith('INSERT INTO stoppy_economy.gp_mutations')).length, 1);
  });
}

test('replay precedes source/business decisions and preserves original semantic balance separately from current balance', async () => {
  const db = new GpDatabase();
  const input = command();
  const outcome: GpOutcome = { status: 'accepted', mutationId: randomUUID(), ledgerId: randomUUID(), delta: 3, balanceBefore: 5, balanceAfter: 8 };
  db.previous = { fingerprint_version: 1, request_fingerprint: prepareGpIntent(input, 'credit').fingerprint, semantic_outcome: outcome };
  db.balance = 11;
  const result = await new GpService(db).credit(input);
  assert.deepEqual(result, { status: 'completed', replayed: true, outcome, currentBalance: 11 });
  assert.ok(!db.calls.some((c) => c.sql.includes('SELECT id FROM') || c.sql.startsWith('UPDATE') || c.sql.startsWith('INSERT')));
  assert.equal((await new GpService(db).credit({ ...input, amount: 4 })).status, 'idempotencyConflict');
});

test('missing player is distinct; missing audit baseline is infrastructure failure, never silently fabricated', async () => {
  const db = new GpDatabase(); db.balance = null;
  assert.deepEqual(await new GpService(db).credit(command()), { status: 'missingPlayer' });
  db.balance = 5; db.opening = false;
  await assert.rejects(new GpService(db).credit(command()), failure('infrastructureFailure'));
  assert.ok(!db.calls.some((c) => c.sql.startsWith('INSERT') || c.sql.startsWith('UPDATE')));
});

for (const stage of ['BEGIN', 'balance', 'mutation', 'ledger', 'COMMIT', 'ROLLBACK'] as const) {
  test(`${stage} failure is never a business rejection or automatically retried`, async () => {
    const db = new GpDatabase();
    db.failureSql = stage === 'BEGIN' || stage === 'COMMIT' ? stage : undefined;
    db.failWhen = (sql) => stage === 'balance' ? sql.startsWith('UPDATE') :
      stage === 'mutation' || stage === 'ROLLBACK' ? sql.startsWith('INSERT INTO stoppy_economy.gp_mutations') :
        stage === 'ledger' ? sql.startsWith('INSERT INTO stoppy_economy.gp_ledger') : false;
    db.rollbackFails = stage === 'ROLLBACK';
    await assert.rejects(new GpService(db).credit(command()), failure(stage === 'COMMIT' ? 'commitOutcomeUnknown' : 'infrastructureFailure'));
    assert.equal(db.connections, 1);
    assert.deepEqual(db.released, [['BEGIN', 'COMMIT', 'ROLLBACK'].includes(stage)]);
    assert.equal(db.calls.filter((c) => c.sql === 'COMMIT').length, stage === 'COMMIT' ? 1 : 0);
  });
}

test('connection acquisition failure is sanitized and never retried', async () => {
  let attempts = 0;
  const db = new GpDatabase();
  db.connect = async () => { attempts++; throw new Error('PRIVATE_DATABASE_DIAGNOSTIC'); };
  await assert.rejects(new GpService(db).credit(command()), failure('infrastructureFailure'));
  assert.equal(attempts, 1);
  assert.deepEqual(db.released, []);
});

test('intent is snapshotted before asynchronous transaction acquisition', async () => {
  const db = new GpDatabase();
  const context = { season: 'original' };
  const input = { ...command(), context };
  const pending = new GpService(db).credit(input);
  input.amount = 999;
  context.season = 'changed';
  const result = await pending;
  assert.equal(result.status, 'completed');
  if (result.status === 'completed') assert.equal(result.currentBalance, 8);
  const mutation = db.calls.find((c) => c.sql.startsWith('INSERT INTO stoppy_economy.gp_mutations'))!;
  assert.deepEqual(JSON.parse(mutation.values![9] as string), { season: 'original' });
});
