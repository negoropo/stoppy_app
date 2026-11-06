import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import { setImmediate } from 'node:timers/promises';
import type { Database, TransactionConnection } from '../../src/database.js';
import { KnockoutRegistrationService, KnockoutRegistrationFailure, type KnockoutRegistrationResult } from '../../src/knockout/knockout_registration_service.js';
import { GpService } from '../../src/economy/gp_service.js';

function completed(result: KnockoutRegistrationResult) {
  assert.ok(result.status === 'completed');
  return result;
}
function gate() { let open!: () => void; const wait = new Promise<void>((resolve) => { open = resolve; }); return { wait, open }; }
function intercept(db: Database, wrap: (c: TransactionConnection) => TransactionConnection): Database {
  return { query: (s, v) => db.query(s, v), close: async () => {}, connect: async () => wrap(await db.connect()) };
}

export async function testKnockoutRegistration(t: TestContext, database: Database) {
  let time: Date | string = new Date('2030-02-15T12:00:00Z');
  // Only this test adapter substitutes the database clock query. Production has
  // no caller-provided clock or timestamp and samples after acquiring all locks.
  const db = intercept(database, (c) => ({ release: (d) => c.release(d), query: (s, v) =>
    s.startsWith('WITH admission_clock')
      ? c.query(s.replace('clock_timestamp()', '$2::timestamptz'), [v![0], time]) : c.query(s, v) }));
  const service = new KnockoutRegistrationService(db);
  let month = 2;
  const tournament = async (status = 'registrationOpen', id = randomUUID()) => {
    const label = new Date(Date.UTC(2100, month++, 1)).toISOString().slice(0, 10);
    return (await database.query(`INSERT INTO stoppy_knockout.tournaments
      (id, tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
      VALUES ($1, $2, 'Service fixture', '2030-02-01T00:00:00Z', '2030-02-28T23:59:00Z', '2030-03-01T00:00:00Z', $3) RETURNING id`, [id, label, status])).rows[0]!.id as string;
  };
  const player = async (balance = 50, opening = true) => {
    const id = randomUUID();
    await database.query(`INSERT INTO stoppy_auth.players (id, username, password_hash, created_at, game_points)
      VALUES ($1, $2, '$argon2id$fixture-only', CURRENT_TIMESTAMP, $3)`, [id, 'R' + id.replaceAll('-', '').slice(0, 24), balance]);
    if (opening) await database.query(`INSERT INTO stoppy_economy.gp_ledger
      (player_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      VALUES ($1::uuid, 'opening_snapshot', 'opening_snapshot', 'opening_snapshot', $1::uuid::text, 0, $2, $2)`, [id, balance]);
    return id;
  };
  const state = async (id: string) => ({
    balance: (await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points,
    registrations: (await database.query('SELECT * FROM stoppy_knockout.registrations WHERE player_id = $1 ORDER BY id', [id])).rows,
    operations: (await database.query('SELECT * FROM stoppy_knockout.registration_operations WHERE player_id = $1 ORDER BY id', [id])).rows,
    mutations: (await database.query('SELECT * FROM stoppy_economy.gp_mutations WHERE player_id = $1 ORDER BY id', [id])).rows,
    ledger: (await database.query('SELECT * FROM stoppy_economy.gp_ledger WHERE player_id = $1 ORDER BY id', [id])).rows,
  });
  const funding = (playerId: string, amount: number) => new GpService(db).credit({ playerId, amount,
    operationName: 'service_fixture_funding', operationVersion: 1, idempotencyKey: randomUUID(), reason: 'test_only',
    sourceType: 'fixture', sourceId: randomUUID(), context: {} });

  await t.test('internal registration commits exact fee, source and linked business/financial identities', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const result = completed(await service.register(input));
    assert.equal(result.replayed, false);
    assert.ok(result.outcome.status === 'accepted');
    assert.equal(result.outcome.remainingGamePoints, 25);
    const rows = await state(input.playerId);
    assert.equal(rows.balance, 25);
    assert.equal(rows.registrations.length, 1);
    assert.equal(rows.operations.length, 1);
    assert.equal(rows.mutations.length, 1);
    assert.equal(rows.ledger.length, 2);
    const reg = rows.registrations[0]!;
    const ledger = rows.ledger.find((r) => r.movement_type === 'debit')!;
    assert.equal(ledger.delta, -25);
    assert.equal(ledger.source_type, 'knockout_registration');
    assert.equal(ledger.source_id, `${input.tournamentId}:${reg.id}`);
    assert.equal(reg.id, result.outcome.registrationId);
    assert.equal(reg.gp_ledger_id, ledger.id);
    assert.equal(reg.gp_mutation_id, rows.mutations[0]!.id);
    assert.equal(ledger.mutation_id, reg.gp_mutation_id);
    assert.equal(rows.operations[0]!.registration_id, reg.id);
    assert.equal(rows.mutations[0]!.idempotency_key, input.idempotencyKey);
    assert.deepEqual(rows.mutations[0]!.resolved_context, { businessOperation: 'knockout_register', businessVersion: 1,
      tournamentId: input.tournamentId, registrationId: reg.id });
  });

  await t.test('insufficient GP persists both rejections without a debit and replays after funding', async () => {
    const input = { playerId: await player(5), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const first = completed(await service.register(input));
    assert.ok(first.outcome.status === 'rejected');
    assert.equal(first.outcome.reason, 'insufficientGp');
    const before = await state(input.playerId);
    assert.equal(before.balance, 5); assert.equal(before.registrations.length, 0); assert.equal(before.ledger.length, 1);
    assert.equal(before.mutations.length, 1); assert.equal(before.mutations[0]!.outcome_status, 'rejected');
    await funding(input.playerId, 50);
    const funded = await state(input.playerId);
    const replay = completed(await new KnockoutRegistrationService(db).register(input));
    assert.equal(replay.replayed, true); assert.deepEqual(replay.outcome, first.outcome);
    assert.deepEqual(await state(input.playerId), funded);
    assert.equal(completed(await service.register({ ...input, idempotencyKey: randomUUID() })).outcome.status, 'accepted');
  });

  await t.test('missing opening snapshot fails closed without a registration, rejection or financial write', async () => {
    const input = { playerId: await player(50, false), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const before = await state(input.playerId);
    await assert.rejects(service.register(input),
      (e: unknown) => e instanceof KnockoutRegistrationFailure && e.code === 'infrastructureFailure');
    assert.deepEqual(await state(input.playerId), before);
  });

  await t.test('a conflicting financial source is not adopted or charged again by registration', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    let sourceId = '';
    // Obtain the real service-derived source without duplicating its UUID/fingerprint
    // algorithm, then roll back this controlled probe before seeding a conflict.
    const probe = intercept(db, (c) => ({ release: (d) => c.release(d), query: (s, v) => {
      if (s.includes('INSERT INTO stoppy_economy.gp_ledger')) { sourceId = v![6] as string; return c.query('SELECT 1/0'); }
      return c.query(s, v);
    } }));
    await assert.rejects(new KnockoutRegistrationService(probe).register(input), KnockoutRegistrationFailure);
    assert.notEqual(sourceId, '');
    const fixture = await new GpService(db).debit({ playerId: input.playerId, amount: 25,
      operationName: 'conflicting_source_fixture', operationVersion: 1, idempotencyKey: randomUUID(),
      reason: 'fixture', sourceType: 'knockout_registration', sourceId, context: {} });
    assert.ok(fixture.status === 'completed' && fixture.outcome.status === 'accepted');
    const before = await state(input.playerId);
    assert.equal(before.balance, 25); assert.equal(before.registrations.length, 0);
    await assert.rejects(service.register(input),
      (e: unknown) => e instanceof KnockoutRegistrationFailure && e.code === 'infrastructureFailure');
    assert.deepEqual(await state(input.playerId), before);
  });

  for (const scenario of ['unknown', 'unavailable', 'closed', 'before', 'atClose', 'started', 'inProgress', 'completed']) {
    await t.test(`registration rejects ${scenario} without a GP mutation/debit`, async () => {
      const tournamentId = scenario === 'unknown' ? randomUUID() : await tournament(
        scenario === 'unavailable' ? 'unavailable' : scenario === 'closed' ? 'registrationClosed'
          : scenario === 'inProgress' || scenario === 'completed' ? scenario : 'registrationOpen');
      time = new Date(scenario === 'before' ? '2030-01-31T23:59:59Z' : scenario === 'atClose' ? '2030-02-28T23:59:00Z'
        : scenario === 'started' ? '2030-03-01T00:00:00Z' : '2030-02-15T12:00:00Z');
      try {
        const input = { playerId: await player(), tournamentId, idempotencyKey: randomUUID() };
        const result = completed(await service.register(input));
        assert.ok(result.outcome.status === 'rejected');
        assert.equal(result.outcome.reason, scenario === 'unknown' || scenario === 'unavailable' ? 'tournamentUnavailable'
          : ['started', 'inProgress', 'completed'].includes(scenario) ? 'tournamentAlreadyStarted' : 'registrationClosed');
        const rows = await state(input.playerId);
        assert.equal(rows.balance, 50); assert.equal(rows.registrations.length, 0); assert.equal(rows.ledger.length, 1);
        assert.equal(rows.mutations.length, 0); assert.equal(rows.operations.length, 1);
        if (scenario === 'unknown') assert.equal(rows.operations[0]!.tournament_id, null);
      } finally { time = new Date('2030-02-15T12:00:00Z'); }
    });
  }

  await t.test('inclusive opening admits a player and missing player produces no outcome', async () => {
    const tournamentId = await tournament();
    time = new Date('2030-02-01T00:00:00Z');
    try { assert.equal(completed(await service.register({ playerId: await player(), tournamentId, idempotencyKey: randomUUID() })).outcome.status, 'accepted'); }
    finally { time = new Date('2030-02-15T12:00:00Z'); }
    assert.deepEqual(await service.register({ playerId: randomUUID(), tournamentId, idempotencyKey: randomUUID() }), { status: 'missingPlayer' });
  });

  await t.test('database comparisons preserve inclusive/exclusive boundaries at microsecond precision', async () => {
    const tournamentId = await tournament();
    await database.query(`UPDATE stoppy_knockout.tournaments SET
      registration_opens_at = '2030-02-15T12:00:00.000100Z', registration_closes_at = '2030-02-15T12:00:00.000900Z'
      WHERE id = $1`, [tournamentId]);
    try {
      for (const [suffix, expected] of [['000099', 'rejected'], ['000100', 'accepted'], ['000899', 'accepted'], ['000900', 'rejected']]) {
        time = `2030-02-15T12:00:00.${suffix}Z`;
        const result = completed(await service.register({ playerId: await player(), tournamentId, idempotencyKey: randomUUID() }));
        assert.equal(result.outcome.status, expected);
      }
    } finally { time = new Date('2030-02-15T12:00:00Z'); }
  });

  await t.test('accepted replay is historical after funding/closure, changed target conflicts, and new-key duplicate cannot charge', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const first = completed(await service.register(input));
    const duplicate = completed(await service.register({ ...input, idempotencyKey: randomUUID() }));
    assert.ok(duplicate.outcome.status === 'rejected'); assert.equal(duplicate.outcome.reason, 'duplicateRegistration');
    await funding(input.playerId, 3);
    await database.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationClosed' WHERE id = $1", [input.tournamentId]);
    const before = await state(input.playerId);
    const replay = completed(await new KnockoutRegistrationService(db).register(input));
    assert.equal(replay.replayed, true); assert.deepEqual(replay.outcome, first.outcome);
    assert.deepEqual(await service.register({ ...input, tournamentId: await tournament() }), { status: 'idempotencyConflict' });
    assert.deepEqual(await state(input.playerId), before);
  });

  await t.test('closed rejection remains historical after reopening', async () => {
    const input = { playerId: await player(), tournamentId: await tournament('registrationClosed'), idempotencyKey: randomUUID() };
    const first = completed(await service.register(input));
    await database.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationOpen' WHERE id = $1", [input.tournamentId]);
    const replay = completed(await service.register(input));
    assert.equal(replay.replayed, true); assert.deepEqual(replay.outcome, first.outcome);
  });

  await t.test('unknown tournament rejection replays unchanged after that exact identity is provisioned', async () => {
    const input = { playerId: await player(), tournamentId: randomUUID(), idempotencyKey: randomUUID() };
    const original = completed(await service.register(input));
    await tournament('registrationOpen', input.tournamentId);
    const replay = completed(await service.register(input));
    assert.equal(replay.replayed, true); assert.deepEqual(replay.outcome, original.outcome);
    const rows = await state(input.playerId); assert.equal(rows.balance, 50); assert.equal(rows.ledger.length, 1);
  });

  for (const stage of ['beforeDebit', 'afterDebit', 'registration', 'outcome']) {
    await t.test(`${stage} failure rolls back every business and financial write`, async () => {
      const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
      const before = await state(input.playerId);
      const failing = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
        if ((stage === 'beforeDebit' && s.includes('FROM stoppy_knockout.registrations'))
          || (stage === 'registration' && s.includes('INSERT INTO stoppy_knockout.registrations'))
          || (stage === 'outcome' && s.includes('INSERT INTO stoppy_knockout.registration_operations'))) return c.query('SELECT 1/0');
        const result = await c.query(s, v);
        if (stage === 'afterDebit' && s.includes('INSERT INTO stoppy_economy.gp_ledger')) await c.query('SELECT 1/0');
        return result;
      } }));
      await assert.rejects(new KnockoutRegistrationService(failing).register(input),
        (e: unknown) => e instanceof KnockoutRegistrationFailure && e.code === 'infrastructureFailure');
      assert.deepEqual(await state(input.playerId), before);
      assert.equal(completed(await service.register(input)).outcome.status, 'accepted');
    });
  }

  for (const persisted of [false, true]) {
    await t.test(`uncertain COMMIT (${persisted ? 'persisted' : 'not sent'}) recovers the exact financial intent only on explicit retry`, async () => {
      const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
      const original = await state(input.playerId);
      let connects = 0;
      let attempted: unknown[] | undefined;
      const uncertain = intercept(db, (c) => {
        connects++;
        return { release: (d) => c.release(d), query: async (s, v) => {
          if (s.includes('INSERT INTO stoppy_economy.gp_mutations')) attempted = v;
          if (s === 'COMMIT') { if (persisted) await c.query(s); throw new Error('Lost COMMIT acknowledgement with credentials.'); }
          return c.query(s, v);
        } };
      });
      await assert.rejects(new KnockoutRegistrationService(uncertain).register(input),
        (e: unknown) => e instanceof KnockoutRegistrationFailure && e.code === 'commitOutcomeUnknown' && !e.message.includes('credentials'));
      assert.equal(connects, 1);
      // Destroyed sockets roll uncommitted transactions back; await visibility
      // through a fresh connection/player lock rather than timing a sleep.
      const recovery = completed(await service.register(input));
      assert.equal(recovery.replayed, persisted);
      assert.ok(recovery.outcome.status === 'accepted');
      const rows = await state(input.playerId);
      assert.equal(rows.registrations.length, 1); assert.equal(rows.balance, 25); assert.equal(rows.operations.length, 1);
      assert.equal(rows.mutations.length, 1); assert.equal(rows.ledger.length, original.ledger.length + 1);
      assert.equal(rows.mutations[0]!.request_fingerprint, attempted![6]);
      assert.deepEqual(rows.mutations[0]!.resolved_context, JSON.parse(attempted![9] as string));
      assert.equal(rows.mutations[0]!.idempotency_key, attempted![4]);
    });
  }

  for (const sameKey of [true, false]) {
    await t.test(`overlapping ${sameKey ? 'same-key' : 'different-key'} registrations serialize and charge once`, async () => {
      const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
      const locked = gate(); const release = gate(); const attempted = gate();
      let ordinal = 0; let pid = 0;
      const concurrent = intercept(db, (c) => {
        const index = ordinal++;
        return { release: (d) => c.release(d), query: async (s, v) => {
          if (index === 1 && s.includes('FOR UPDATE')) { pid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number; attempted.open(); }
          const result = await c.query(s, v);
          if (index === 0 && s.includes('FOR UPDATE')) { locked.open(); await release.wait; }
          return result;
        } };
      });
      const one = new KnockoutRegistrationService(concurrent).register(input);
      await locked.wait;
      const two = new KnockoutRegistrationService(concurrent).register({ ...input, idempotencyKey: sameKey ? input.idempotencyKey : randomUUID() });
      const both = Promise.all([one, two]);
      try {
        await attempted.wait;
        await waitForBlocker(database, pid);
      } finally { release.open(); }
      const results = (await both).map(completed);
      assert.equal(results[0]!.outcome.status, 'accepted');
      if (sameKey) { assert.equal(results[1]!.replayed, true); assert.deepEqual(results[1]!.outcome, results[0]!.outcome); }
      else { assert.ok(results[1]!.outcome.status === 'rejected'); assert.equal(results[1]!.outcome.reason, 'duplicateRegistration'); }
      const rows = await state(input.playerId);
      assert.equal(rows.balance, 25); assert.equal(rows.registrations.length, 1); assert.equal(rows.ledger.length, 2); assert.equal(rows.mutations.length, 1);
    });
  }

  await t.test('different players sharing a tournament/key can complete independently under shared catalog locks', async () => {
    const first = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const second = { ...first, playerId: await player() };
    const held = gate(); const release = gate();
    const paused = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      const result = await c.query(s, v);
      if (s.includes('FOR UPDATE')) { held.open(); await release.wait; }
      return result;
    } }));
    const pending = new KnockoutRegistrationService(paused).register(first);
    await held.wait;
    try {
      // This must finish while the first transaction still holds its catalog and
      // player locks; an exclusive catalog lock would fail under lock_timeout.
      const result = completed(await service.register(second));
      assert.equal(result.outcome.status, 'accepted');
      assert.equal((await state(first.playerId)).registrations.length, 0);
    } finally { release.open(); await pending; }
    const one = await state(first.playerId); const two = await state(second.playerId);
    assert.equal(one.balance, 25); assert.equal(two.balance, 25);
    assert.equal(one.registrations.length, 1); assert.equal(two.registrations.length, 1);
    assert.notEqual(one.registrations[0]!.id, two.registrations[0]!.id);
  });

  await t.test('catalog lock timeout is infrastructure failure with no durable rejection or automatic retry', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const before = await state(input.playerId);
    const owner = await database.connect();
    let attempts = 0;
    await owner.query('BEGIN');
    try {
      await owner.query("SELECT pg_advisory_xact_lock(hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))", [input.tournamentId]);
      const bounded = intercept(db, (c) => ({ release: (d) => c.release(d), query: (s, v) => {
        if (s.includes('pg_advisory_xact_lock_shared')) attempts++;
        return c.query(s === "SET LOCAL lock_timeout = '3s'" ? "SET LOCAL lock_timeout = '25ms'" : s, v);
      } }));
      await assert.rejects(new KnockoutRegistrationService(bounded).register(input),
        (e: unknown) => e instanceof KnockoutRegistrationFailure && e.code === 'infrastructureFailure');
      assert.equal(attempts, 1);
      assert.deepEqual(await state(input.playerId), before);
      await owner.query('COMMIT');
    } catch (error) { await owner.query('ROLLBACK'); throw error; }
    finally { owner.release(); }
    assert.equal(completed(await service.register(input)).outcome.status, 'accepted');
  });

  await t.test('closure holding the exclusive catalog lock blocks admission until closed state is visible', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const closure = await database.connect();
    await closure.query('BEGIN');
    try {
      await closure.query("SELECT pg_advisory_xact_lock(hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))", [input.tournamentId]);
      await closure.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationClosed' WHERE id = $1", [input.tournamentId]);
      const attempted = gate(); let pid = 0;
      const waiting = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
        if (s.includes('pg_advisory_xact_lock_shared')) { pid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number; attempted.open(); }
        return c.query(s, v);
      } }));
      const pending = new KnockoutRegistrationService(waiting).register(input);
      await attempted.wait; await waitForBlocker(database, pid);
      await closure.query('COMMIT');
      const result = completed(await pending);
      assert.ok(result.outcome.status === 'rejected'); assert.equal(result.outcome.reason, 'registrationClosed');
      const rows = await state(input.playerId); assert.equal(rows.balance, 50); assert.equal(rows.ledger.length, 1);
    } catch (error) { await closure.query('ROLLBACK'); throw error; }
    finally { closure.release(); }
  });

  await t.test('registration holding the shared catalog lock completes before a concurrent closure can change state', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const holding = gate(); const release = gate();
    const paused = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      const result = await c.query(s, v);
      if (s.includes('FOR UPDATE')) { holding.open(); await release.wait; }
      return result;
    } }));
    const registration = new KnockoutRegistrationService(paused).register(input);
    await holding.wait;
    const closure = await database.connect();
    await closure.query('BEGIN');
    try {
      const pid = (await closure.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number;
      const change = (async () => {
        await closure.query("SELECT pg_advisory_xact_lock(hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))", [input.tournamentId]);
        await closure.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationClosed' WHERE id = $1", [input.tournamentId]);
        await closure.query('COMMIT');
      })();
      const both = Promise.all([registration, change]);
      try { await waitForBlocker(database, pid); } finally { release.open(); }
      const [result] = await both;
      assert.equal(completed(result).outcome.status, 'accepted');
      assert.equal((await database.query('SELECT status FROM stoppy_knockout.tournaments WHERE id = $1', [input.tournamentId])).rows[0]!.status, 'registrationClosed');
    } catch (error) { await closure.query('ROLLBACK'); throw error; }
    finally { release.open(); closure.release(); }
  });

  await t.test('admission samples fresh database time after waiting, so a newly closed window cannot charge', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const owner = await database.connect();
    await owner.query('BEGIN');
    await owner.query('SELECT id FROM stoppy_auth.players WHERE id = $1 FOR UPDATE', [input.playerId]);
    const attempted = gate(); let pid = 0;
    const waiting = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      if (s.includes('FOR UPDATE')) { pid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number; attempted.open(); }
      return c.query(s, v);
    } }));
    try {
      const pending = new KnockoutRegistrationService(waiting).register(input);
      await attempted.wait; await waitForBlocker(database, pid);
      time = new Date('2030-02-28T23:59:00Z');
      await owner.query('COMMIT');
      const result = completed(await pending);
      assert.ok(result.outcome.status === 'rejected'); assert.equal(result.outcome.reason, 'registrationClosed');
      const rows = await state(input.playerId); assert.equal(rows.balance, 50); assert.equal(rows.ledger.length, 1); assert.equal(rows.mutations.length, 0);
      const timestamps = (await database.query(`SELECT created_at = $2::timestamptz AS matches_admission,
        completed_at >= created_at AS ordered FROM stoppy_knockout.registration_operations WHERE player_id = $1`,
      [input.playerId, time])).rows[0]!;
      assert.deepEqual(timestamps, { matches_admission: true, ordered: true });
    } catch (error) { await owner.query('ROLLBACK'); throw error; }
    finally { time = new Date('2030-02-15T12:00:00Z'); owner.release(); }
  });

  await t.test('a transaction begun before opening persists the exact post-lock admission instant and replays it unchanged', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const owner = await database.connect();
    await owner.query('BEGIN');
    await owner.query('SELECT id FROM stoppy_auth.players WHERE id = $1 FOR UPDATE', [input.playerId]);
    const begun = gate(); const proceed = gate(); const attempted = gate();
    let beganAt = ''; let pid = 0;
    const waiting = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      if (s === 'BEGIN') {
        const result = await c.query(s, v);
        beganAt = (await c.query('SELECT CURRENT_TIMESTAMP::text AS began_at')).rows[0]!.began_at as string;
        begun.open(); await proceed.wait;
        return result;
      }
      if (s.includes('FOR UPDATE')) { pid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number; attempted.open(); }
      return c.query(s, v);
    } }));
    const pending = new KnockoutRegistrationService(waiting).register(input);
    try {
      await begun.wait;
      // Configure the trusted fixture before admission takes its catalog lock.
      // Boundaries derive from the actual transaction start, not a wall-clock guess.
      const window = (await database.query(`UPDATE stoppy_knockout.tournaments SET
        registration_opens_at = $2::timestamptz + interval '1 second',
        registration_closes_at = $2::timestamptz + interval '1 day', starts_at = $2::timestamptz + interval '2 days'
        WHERE id = $1 RETURNING (registration_opens_at + interval '1 microsecond')::text AS admitted_at`,
      [input.tournamentId, beganAt])).rows[0]!;
      proceed.open();
      await attempted.wait; await waitForBlocker(database, pid);
      time = window.admitted_at as string;
      await owner.query('COMMIT');
      const result = completed(await pending);
      assert.ok(result.outcome.status === 'accepted');
      const timestamps = (await database.query(`SELECT
        r.registered_at = $2::timestamptz AS exact_admission,
        r.registered_at > $3::timestamptz AS after_begin,
        r.registered_at >= t.registration_opens_at AS inside_opening,
        r.registered_at < t.registration_closes_at AS before_closing,
        o.created_at = r.registered_at AS same_event,
        o.completed_at >= o.created_at AS ordered
        FROM stoppy_knockout.registrations r JOIN stoppy_knockout.tournaments t ON t.id = r.tournament_id
        JOIN stoppy_knockout.registration_operations o ON o.registration_id = r.id WHERE r.player_id = $1`,
      [input.playerId, time, beganAt])).rows[0]!;
      assert.deepEqual(timestamps, { exact_admission: true, after_begin: true, inside_opening: true,
        before_closing: true, same_event: true, ordered: true });
      assert.equal(result.outcome.registeredAt, new Date(time).toISOString());
      const before = await state(input.playerId);
      time = '2000-01-01T00:00:00Z';
      const replay = completed(await service.register(input));
      assert.equal(replay.replayed, true); assert.deepEqual(replay.outcome, result.outcome);
      assert.deepEqual(await state(input.playerId), before);
    } catch (error) { await owner.query('ROLLBACK'); throw error; }
    finally { proceed.open(); time = new Date('2030-02-15T12:00:00Z'); owner.release(); }
  });

  for (const direction of ['backward', 'forward']) {
    await t.test(`business completion timestamps remain ordered after a ${direction} database clock step`, async () => {
      const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
      const clockStep = intercept(db, (c) => ({ release: (d) => c.release(d), query: (s, v) =>
        s.includes('INSERT INTO stoppy_knockout.registration_operations')
          ? c.query(s.replace('clock_timestamp()', `($12::timestamptz ${direction === 'backward' ? '-' : '+'} interval '1 second')`), v)
          : c.query(s, v) }));
      assert.equal(completed(await new KnockoutRegistrationService(clockStep).register(input)).outcome.status, 'accepted');
      const row = (await database.query(`SELECT o.created_at = r.registered_at AS same_event,
        o.completed_at = o.created_at + $2::interval AS completion_time
        FROM stoppy_knockout.registration_operations o JOIN stoppy_knockout.registrations r ON r.id = o.registration_id
        WHERE o.player_id = $1`, [input.playerId, direction === 'backward' ? '0 seconds' : '1 second'])).rows[0]!;
      assert.deepEqual(row, { same_event: true, completion_time: true });
    });
  }

  await t.test('waiting on a competing debit reads the committed balance and cannot overspend', async () => {
    const input = { playerId: await player(), tournamentId: await tournament(), idempotencyKey: randomUUID() };
    const holding = gate(); const release = gate(); const attempted = gate(); let pid = 0;
    const spenderDb = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      const result = await c.query(s, v);
      if (s.includes('FOR UPDATE')) { holding.open(); await release.wait; }
      return result;
    } }));
    const spend = new GpService(spenderDb).debit({ playerId: input.playerId, amount: 40, operationName: 'competing_purchase', operationVersion: 1,
      idempotencyKey: randomUUID(), reason: 'fixture', sourceType: 'fixture', sourceId: randomUUID(), context: {} });
    await holding.wait;
    const waiting = intercept(db, (c) => ({ release: (d) => c.release(d), query: async (s, v) => {
      if (s.includes('FOR UPDATE')) { pid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number; attempted.open(); }
      return c.query(s, v);
    } }));
    const pending = new KnockoutRegistrationService(waiting).register(input);
    const both = Promise.all([spend, pending]);
    try { await attempted.wait; await waitForBlocker(database, pid); }
    finally { release.open(); }
    const [, registration] = await both;
    const result = completed(registration); assert.ok(result.outcome.status === 'rejected'); assert.equal(result.outcome.reason, 'insufficientGp');
    const rows = await state(input.playerId); assert.equal(rows.balance, 10); assert.equal(rows.registrations.length, 0);
    assert.equal(rows.ledger.length, 2);
  });
}

async function waitForBlocker(database: Database, pid: number) {
  const deadline = Date.now() + 1500;
  do {
    if (((await database.query('SELECT cardinality(pg_blocking_pids($1)) AS count', [pid])).rows[0]!.count as number) > 0) return;
    await setImmediate();
  } while (Date.now() < deadline);
  assert.fail('Expected a real PostgreSQL lock wait.');
}
