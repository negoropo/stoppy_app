import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import { setImmediate } from 'node:timers/promises';
import type { Database, TransactionConnection } from '../../src/database.js';
import { ArgonPasswordHasher } from '../../src/auth/password_hasher.js';
import { gpIntegerMax, type GpCommand } from '../../src/economy/gp_intent.js';
import { GpService, GpExecutionFailure, type GpExecutionResult } from '../../src/economy/gp_service.js';
import { GpExecutor } from '../../src/economy/gp_executor.js';
import { inTransaction } from '../../src/transaction.js';

function completed(result: GpExecutionResult) {
  assert.equal(result.status, 'completed');
  assert.ok(result.status === 'completed');
  return result;
}

function gate() {
  let open!: () => void;
  const wait = new Promise<void>((resolve) => { open = resolve; });
  return { wait, open };
}

function intercepted(database: Database, wrap: (connection: TransactionConnection) => TransactionConnection): Database {
  return { query: (sql, values) => database.query(sql, values), close: async () => {},
    connect: async () => wrap(await database.connect()) };
}

/** Prove the second transaction is waiting on a real PostgreSQL lock, not just
 * scheduled after the first commit. Neither caller is a process-local mutex. */
async function contended(database: Database, first: (service: GpService) => Promise<GpExecutionResult>,
  second: (service: GpService) => Promise<GpExecutionResult>) {
  const locked = gate();
  const attempted = gate();
  const release = gate();
  let ordinal = 0;
  let secondPid = 0;
  const db = intercepted(database, (connection) => {
    const index = ordinal++;
    return { release: (discard) => connection.release(discard), query: async (sql, values) => {
      if (index === 1 && sql.includes('FOR UPDATE')) {
        secondPid = (await connection.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number;
        attempted.open();
      }
      const result = await connection.query(sql, values);
      if (index === 0 && sql.includes('FOR UPDATE')) { locked.open(); await release.wait; }
      return result;
    } };
  });
  const service = new GpService(db);
  const one = first(service);
  await locked.wait;
  const two = second(service);
  const outcomes = Promise.all([one, two]);
  try {
    await attempted.wait;
    const deadline = Date.now() + 1500;
    let blockers = 0;
    do {
      blockers = (await database.query('SELECT cardinality(pg_blocking_pids($1)) AS blockers', [secondPid])).rows[0]!.blockers as number;
      if (blockers === 0) await setImmediate();
    } while (blockers === 0 && Date.now() < deadline);
    assert.ok(blockers > 0, 'Second transaction must actually wait on the first player lock.');
  } finally { release.open(); }
  return outcomes;
}

export async function testGpService(t: TestContext, database: Database) {
  const hash = await new ArgonPasswordHasher().hash('economy-fixture-password');
  let players = 0;
  const player = async (balance = 5, opening = true) => {
    const id = randomUUID();
    await database.query(`INSERT INTO stoppy_auth.players (id, username, password_hash, game_points, created_at)
      VALUES ($1, $2, $3, $4, '2026-01-01T12:00:00Z')`, [id, `EconomyFixture${players++}`, hash, balance]);
    if (opening) await database.query(`INSERT INTO stoppy_economy.gp_ledger
      (player_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      VALUES ($1::uuid, 'opening_snapshot', 'opening_snapshot', 'opening_snapshot', $1::uuid::text, 0, $2, $2)`, [id, balance]);
    return id;
  };
  const command = (playerId: string, overrides: Partial<GpCommand> = {}): GpCommand => ({
    playerId, operationName: 'integration_reward', operationVersion: 1, idempotencyKey: randomUUID(),
    amount: 3, reason: 'integration_reward', sourceType: 'integration_event', sourceId: randomUUID(),
    context: { eventId: 'stable-event', periodId: 'original-period' }, ...overrides,
  });
  const state = async (id: string) => ({
    balance: (await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points,
    ledger: (await database.query('SELECT * FROM stoppy_economy.gp_ledger WHERE player_id = $1 ORDER BY id', [id])).rows,
    mutations: (await database.query('SELECT * FROM stoppy_economy.gp_mutations WHERE player_id = $1 ORDER BY id', [id])).rows,
  });
  const service = new GpService(database);

  await t.test('two executor operations share one outer transaction and remain invisible until commit', async () => {
    const id = await player();
    const before = await state(id);
    let connects = 0;
    const sql: string[] = [];
    const db = intercepted(database, (connection) => {
      connects++;
      return { release: (discard) => connection.release(discard), query: (query, values) => {
        sql.push(query); return connection.query(query, values);
      } };
    });
    await inTransaction(db, async (connection) => {
      await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
      // A caller may perform trusted business reads/locks before GP execution.
      await connection.query('SELECT 1');
      const executor = new GpExecutor(connection);
      assert.equal(completed(await executor.credit(command(id))).currentBalance, 8);
      assert.equal(completed(await executor.debit(command(id, { amount: 2 }))).currentBalance, 6);
      assert.deepEqual(await state(id), before, 'Executor must not independently commit.');
      assert.ok(!sql.includes('COMMIT'));
    });
    assert.equal(connects, 1);
    assert.equal(sql.filter((s) => s === 'BEGIN').length, 1);
    assert.equal(sql.filter((s) => s === 'COMMIT').length, 1);
    const after = await state(id);
    assert.equal(after.balance, 6);
    assert.equal(after.ledger.length, 3);
    assert.equal(after.mutations.length, 2);
  });

  for (const sqlFailure of [false, true]) {
    await t.test(`outer ${sqlFailure ? 'SQL' : 'business'} failure rolls back both GP operations and allows same-key recovery`, async () => {
      const id = await player();
      const input = command(id);
      const before = await state(id);
      await assert.rejects(inTransaction(database, async (connection) => {
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const executor = new GpExecutor(connection);
        await executor.credit(input);
        await executor.debit(command(id, { amount: 2 }));
        if (sqlFailure) await connection.query('SELECT 1 / 0');
        throw new Error('Business persistence failed after GP execution.');
      }));
      assert.deepEqual(await state(id), before);
      assert.equal(completed(await service.credit(input)).replayed, false);
    });
  }

  await t.test('direct executor preserves accepted/rejected replay and conflicts within an outer transaction', async () => {
    const id = await player();
    await inTransaction(database, async (connection) => {
      await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
      const executor = new GpExecutor(connection);
      const input = command(id);
      const accepted = completed(await executor.credit(input));
      const replay = completed(await executor.credit(input));
      assert.equal(replay.replayed, true);
      assert.deepEqual(replay.outcome, accepted.outcome);
      assert.equal((await executor.credit({ ...input, amount: 4 })).status, 'idempotencyConflict');
      const rejectedInput = command(id, { amount: 9 });
      const rejected = completed(await executor.debit(rejectedInput));
      assert.equal(rejected.outcome.status, 'rejected');
      const rejectedReplay = completed(await executor.debit(rejectedInput));
      assert.equal(rejectedReplay.replayed, true);
      assert.deepEqual(rejectedReplay.outcome, rejected.outcome);
    });
    assert.equal((await state(id)).ledger.length, 2);
  });

  await t.test('internal credit/debit persist signed movements, linked outcomes and authoritative wallet only', async () => {
    const id = await player();
    const beforeProfile = (await database.query('SELECT * FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!;
    const credit = completed(await service.credit(command(id)));
    assert.equal(credit.outcome.status, 'accepted');
    assert.equal(credit.currentBalance, 8);
    const debit = completed(await service.debit(command(id, { amount: 8 })));
    assert.equal(debit.currentBalance, 0);
    const after = await state(id);
    assert.equal(after.balance, 0);
    assert.equal(after.ledger.length, 3);
    assert.equal(after.mutations.length, 2);
    for (const row of after.ledger) {
      assert.equal(row.balance_after, (row.balance_before as number) + (row.delta as number));
      if (row.movement_type !== 'opening_snapshot') {
        const mutation = after.mutations.find((m) => m.id === row.mutation_id)!;
        assert.equal(mutation.player_id, id);
        assert.equal(mutation.outcome_status, 'accepted');
        assert.equal((mutation.semantic_outcome as { ledgerId: string }).ledgerId, row.id);
      }
    }
    const afterProfile = (await database.query('SELECT * FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!;
    assert.deepEqual(afterProfile, { ...beforeProfile, game_points: 0 });
  });

  await t.test('insufficient funds is durable and replays the rejection even after balance grows', async () => {
    const id = await player();
    const input = command(id, { amount: 6 });
    const original = completed(await service.debit(input));
    assert.equal(original.outcome.status, 'rejected');
    if (original.outcome.status === 'rejected') assert.equal(original.outcome.reason, 'insufficientFunds');
    assert.equal((await state(id)).ledger.length, 1);
    await service.credit(command(id, { amount: 10 }));
    const replay = completed(await new GpService(database).debit(input));
    assert.deepEqual(replay.outcome, original.outcome);
    assert.equal(replay.replayed, true);
    assert.equal(replay.currentBalance, 15);
    assert.equal((await state(id)).mutations.length, 2);
  });

  await t.test('overflow is a persisted rejection with no balance/ledger effects; int4 endpoints remain valid', async () => {
    const id = await player(gpIntegerMax);
    const input = command(id, { amount: 1 });
    const result = completed(await service.credit(input));
    assert.equal(result.outcome.status, 'rejected');
    if (result.outcome.status === 'rejected') assert.equal(result.outcome.reason, 'balanceOverflow');
    const after = await state(id);
    assert.equal(after.balance, gpIntegerMax);
    assert.equal(after.ledger.length, 1);
    assert.equal(after.mutations.length, 1);
    assert.deepEqual(completed(await service.credit(input)).outcome, result.outcome);
    await service.debit(command(id, { amount: gpIntegerMax }));
    await service.credit(command(id, { amount: gpIntegerMax }));
    assert.equal((await state(id)).balance, gpIntegerMax);
  });

  await t.test('accepted replay survives a new service and preserves historical balance without overwriting current balance', async () => {
    const id = await player();
    const input = command(id);
    const original = completed(await service.credit(input));
    await service.credit(command(id, { amount: 7 }));
    const before = await state(id);
    const replay = completed(await new GpService(database).credit(input));
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.outcome, original.outcome);
    assert.equal(replay.currentBalance, 15);
    assert.deepEqual(await state(id), before);
  });

  await t.test('same key with changed amount, direction, source or context conflicts without changing the original outcome', async () => {
    const id = await player();
    const input = command(id);
    await service.credit(input);
    const before = await state(id);
    for (const overrides of [{ amount: 4 }, { sourceId: 'another-event' }, { context: { periodId: 'new-period' } }]) {
      assert.equal((await service.credit({ ...input, ...overrides })).status, 'idempotencyConflict');
    }
    assert.equal((await service.debit(input)).status, 'idempotencyConflict');
    assert.deepEqual(await state(id), before);
  });

  await t.test('canonical context ordering replays identically and stores the original resolved context', async () => {
    const id = await player();
    const input = command(id, { context: { z: 1, a: { b: 'event', a: [true, null] } } });
    const original = completed(await service.credit(input));
    const replay = completed(await service.credit({ ...input, context: { a: { a: [true, null], b: 'event' }, z: 1 } }));
    assert.equal(replay.replayed, true);
    assert.deepEqual(replay.outcome, original.outcome);
    assert.deepEqual((await state(id)).mutations[0]!.resolved_context, input.context);
  });

  await t.test('concurrent credits wait on the player row and never lose an update', async () => {
    const id = await player();
    const results = await contended(database, (s) => s.credit(command(id, { amount: 2 })), (s) => s.credit(command(id, { amount: 3 })));
    assert.deepEqual(results.map((r) => completed(r).currentBalance), [7, 10]);
    assert.equal((await state(id)).balance, 10);
  });

  await t.test('concurrent debits cannot overspend and persist one rejection', async () => {
    const id = await player();
    const results = await contended(database, (s) => s.debit(command(id, { amount: 4 })), (s) => s.debit(command(id, { amount: 4 })));
    assert.deepEqual(results.map((r) => completed(r).outcome.status), ['accepted', 'rejected']);
    const after = await state(id);
    assert.equal(after.balance, 1);
    assert.equal(after.ledger.length, 2);
    assert.equal(after.mutations.length, 2);
  });

  await t.test('concurrent credit and debit use the locked committed balance', async () => {
    const id = await player();
    const results = await contended(database, (s) => s.credit(command(id, { amount: 2 })), (s) => s.debit(command(id, { amount: 6 })));
    assert.deepEqual(results.map((r) => completed(r).currentBalance), [7, 1]);
    assert.equal((await state(id)).balance, 1);
  });

  await t.test('concurrent same-key callers execute once and waiter replays the durable outcome', async () => {
    const id = await player();
    const input = command(id);
    const [one, two] = (await contended(database, (s) => s.credit(input), (s) => s.credit(input))).map(completed);
    assert.equal(one!.replayed, false);
    assert.equal(two!.replayed, true);
    assert.deepEqual(two!.outcome, one!.outcome);
    const after = await state(id);
    assert.equal(after.balance, 8);
    assert.equal(after.ledger.length, 2);
    assert.equal(after.mutations.length, 1);
  });

  await t.test('concurrent duplicate sources under different keys cannot produce another movement', async () => {
    const id = await player();
    const input = command(id);
    const [one, two] = (await contended(database, (s) => s.credit(input),
      (s) => s.credit({ ...input, idempotencyKey: randomUUID() }))).map(completed);
    assert.equal(one!.outcome.status, 'accepted');
    assert.equal(two!.outcome.status, 'rejected');
    if (two!.outcome.status === 'rejected') assert.equal(two!.outcome.reason, 'duplicateSource');
    const after = await state(id);
    assert.equal(after.balance, 8);
    assert.equal(after.ledger.length, 2);
    assert.equal(after.mutations.length, 2);
  });

  await t.test('duplicate-source rejection replays across new keys and changed current balance without a second effect', async () => {
    const id = await player();
    const input = command(id);
    await service.credit(input);
    const duplicate = { ...input, idempotencyKey: randomUUID() };
    const rejected = completed(await service.credit(duplicate));
    await service.credit(command(id));
    const replay = completed(await new GpService(database).credit(duplicate));
    assert.deepEqual(replay.outcome, rejected.outcome);
    assert.equal(replay.replayed, true);
    assert.equal(replay.currentBalance, 11);
    assert.equal((await state(id)).ledger.length, 3);
  });

  await t.test('same key is independent across players, operation names and operation versions', async () => {
    const id = await player();
    const other = await player();
    const input = command(id);
    for (const next of [input, { ...input, playerId: other },
      { ...input, operationName: 'other_operation', sourceId: randomUUID() },
      { ...input, operationVersion: 2, sourceId: randomUUID() }]) {
      assert.equal(completed(await service.credit(next)).outcome.status, 'accepted');
    }
    assert.equal((await state(id)).balance, 14);
    assert.equal((await state(other)).balance, 8);
  });

  // With the immediate FK there cannot be a ledger insert before its final
  // mutation row. Test every actual write boundary, including after both rows.
  for (const stage of ['balance', 'mutation', 'ledger'] as const) {
    await t.test(`failure after ${stage} write rolls back wallet, outcome and movement together`, async () => {
      const id = await player();
      const input = command(id);
      const before = await state(id);
      const db = intercepted(database, (connection) => ({ release: (discard) => connection.release(discard),
        query: async (sql, values) => {
          const result = await connection.query(sql, values);
          if ((stage === 'balance' && sql.startsWith('UPDATE stoppy_auth.players')) ||
              (stage === 'mutation' && sql.startsWith('INSERT INTO stoppy_economy.gp_mutations')) ||
              (stage === 'ledger' && sql.startsWith('INSERT INTO stoppy_economy.gp_ledger'))) {
            // Real server error aborts the transaction, not merely a fake return.
            await connection.query('SELECT 1 / 0');
          }
          return result;
        } }));
      await assert.rejects(new GpService(db).credit(input), (error: unknown) =>
        error instanceof GpExecutionFailure && error.code === 'infrastructureFailure');
      assert.deepEqual(await state(id), before);
      assert.equal(completed(await service.credit(input)).replayed, false);
    });
  }

  for (const committed of [false, true]) {
    await t.test(`uncertain COMMIT (${committed ? 'persisted' : 'not sent'}) is not retried; explicit same-key retry is safe`, async () => {
      const id = await player();
      const input = command(id);
      const releases: boolean[] = [];
      let commits = 0;
      const db = intercepted(database, (connection) => ({ release: (discard = false) => { releases.push(discard); connection.release(discard); },
        query: async (sql, values) => {
          if (sql === 'COMMIT') {
            commits++;
            if (committed) await connection.query(sql, values);
            throw new Error('Lost COMMIT acknowledgement.');
          }
          return connection.query(sql, values);
        } }));
      await assert.rejects(new GpService(db).credit(input), (error: unknown) =>
        error instanceof GpExecutionFailure && error.code === 'commitOutcomeUnknown');
      assert.equal(commits, 1);
      assert.deepEqual(releases, [true]);
      const retry = completed(await new GpService(database).credit(input));
      assert.equal(retry.replayed, committed);
      const after = await state(id);
      assert.equal(after.balance, 8);
      assert.equal(after.ledger.length, 2);
      assert.equal(after.mutations.length, 1);
    });
  }

  await t.test('missing player and missing opening baseline never produce unaudited credits', async () => {
    assert.deepEqual(await service.credit(command(randomUUID())), { status: 'missingPlayer' });
    const id = await player(5, false);
    await assert.rejects(service.credit(command(id)), (error: unknown) =>
      error instanceof GpExecutionFailure && error.code === 'infrastructureFailure');
    assert.deepEqual(await state(id), { balance: 5, ledger: [], mutations: [] });
  });

  await t.test('opening observation plus committed deltas reconciles after concurrent movements, replays and rejections', async () => {
    const id = await player(37);
    const input = command(id, { amount: 10 });
    await contended(database, (s) => s.credit(input), (s) => s.debit(command(id, { amount: 20 })));
    await service.credit(input); // Replay is not a new earning.
    await service.debit(command(id, { amount: 100 }));
    await service.credit({ ...input, idempotencyKey: randomUUID() });
    const after = await state(id);
    const opening = after.ledger.find((r) => r.movement_type === 'opening_snapshot')!;
    assert.equal(opening.delta, 0);
    assert.equal((opening.balance_after as number) + after.ledger.reduce((sum, r) => sum + (r.delta as number), 0), after.balance);
    assert.equal(after.balance, 27);
    assert.equal(after.ledger.length, 3);
    assert.equal(after.mutations.length, 4);
  });
}
