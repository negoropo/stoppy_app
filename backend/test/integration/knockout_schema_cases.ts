import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import { setImmediate } from 'node:timers/promises';
import type { Database, QueryConnection } from '../../src/database.js';
import { inTransaction } from '../../src/transaction.js';
import { GpExecutor } from '../../src/economy/gp_executor.js';

const code = (expected: string) => (error: unknown) => error instanceof Error && 'code' in error && error.code === expected;

/** Controlled persistence fixtures only; no registration decision/service. */
export async function insertRegistrationFixture(connection: QueryConnection, playerId: string, tournamentId: string) {
  // Allocate the business identity before the debit; no circular registration FK.
  const registrationId = randomUUID();
  const result = await new GpExecutor(connection).debit({ playerId, operationName: 'schema_fixture', operationVersion: 1,
    idempotencyKey: randomUUID(), amount: 25, reason: 'test_only', sourceType: 'knockout_registration',
    sourceId: `${tournamentId}:${registrationId}`, context: { tournamentId, registrationId } });
  assert.ok(result.status === 'completed' && result.outcome.status === 'accepted');
  const ledgerId = result.outcome.ledgerId;
  const mutationId = result.outcome.mutationId;
  const row = (await connection.query(`INSERT INTO stoppy_knockout.registrations
    (id, player_id, tournament_id, gp_ledger_id, gp_mutation_id) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
  [registrationId, playerId, tournamentId, ledgerId, mutationId])).rows[0]!;
  return row;
}

export async function insertOperationFixture(connection: QueryConnection, playerId: string, tournamentId: string | null,
  registrationId: string | null = null, options: { key?: string; status?: string; reason?: string | null; version?: number; name?: string; fingerprint?: string; fingerprintVersion?: number; outcome?: unknown } = {}) {
  return (await connection.query(`INSERT INTO stoppy_knockout.registration_operations
    (player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint,
     tournament_id, outcome_status, registration_id, rejection_reason, semantic_outcome)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb) RETURNING *`,
  [playerId, options.name ?? 'knockout_register', options.version ?? 1, options.key ?? randomUUID(),
    options.fingerprintVersion ?? 1, options.fingerprint ?? 'a'.repeat(64), tournamentId,
    options.status ?? (registrationId ? 'accepted' : 'rejected'), registrationId,
    options.reason === undefined ? (registrationId ? null : 'insufficientGp') : options.reason,
    JSON.stringify(options.outcome === undefined ? { fixture: 'stable-business-outcome' } : options.outcome)])).rows[0]!;
}

export async function testKnockoutSchema(t: TestContext, db: Database) {
  const player = async (balance = 100) => {
    const id = randomUUID();
    await db.query(`INSERT INTO stoppy_auth.players (id, username, password_hash, created_at, game_points)
      VALUES ($1, $2, '$argon2id$fixture-only', CURRENT_TIMESTAMP, $3)`, [id, 'K' + id.replaceAll('-', '').slice(0, 24), balance]);
    await db.query(`INSERT INTO stoppy_economy.gp_ledger
      (player_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      VALUES ($1::uuid, 'opening_snapshot', 'opening_snapshot', 'opening_snapshot', $1::uuid::text, 0, $2, $2)`, [id, balance]);
    return id;
  };
  const tournament = async (month: string, opens = '2026-01-01T00:00:00Z', closes = '2026-01-30T23:59:00Z', status = 'registrationOpen') =>
    (await db.query(`INSERT INTO stoppy_knockout.tournaments
      (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
      VALUES ($1, 'Trusted fixture', $2, $3, '2026-02-01T00:00:00Z', $4) RETURNING *`, [month, opens, closes, status])).rows[0]!;
  const first = await tournament('2026-02-01');
  const second = await tournament('2026-03-01');
  const tournamentId = first.id as string;

  await t.test('catalog enforces unique first-of-month labels, window ordering and explicit states', async () => {
    await assert.rejects(tournament('2026-02-01'), code('23505'));
    await assert.rejects(tournament('2026-04-02'), code('23514'));
    await assert.rejects(tournament('2026-04-01', '2026-01-02T00:00:00Z', '2026-01-01T00:00:00Z'), code('23514'));
    await assert.rejects(tournament('2026-04-01', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'), code('23514'));
    await assert.rejects(tournament('2026-04-01', '2026-01-01T00:00:00Z', '2026-02-01T00:00:00Z'), code('23514'));
    await assert.rejects(tournament('2026-04-01', undefined, undefined, 'invalid'), code('23514'));
    for (const [index, status] of ['unavailable', 'registrationClosed', 'inProgress', 'completed'].entries()) {
      await tournament(`2027-${String(index + 1).padStart(2, '0')}-01`, undefined, undefined, status);
    }
  });

  await t.test('absolute windows use inclusive opening/exclusive closing regardless of session timezone', async () => {
    await inTransaction(db, async (connection) => {
      for (const timezone of ['UTC', 'Europe/Lisbon', 'Pacific/Auckland']) {
        await connection.query("SELECT set_config('TimeZone', $1, true)", [timezone]);
        const rows = (await connection.query(`SELECT instant >= registration_opens_at AND instant < registration_closes_at AS available
          FROM stoppy_knockout.tournaments CROSS JOIN unnest(ARRAY[
            '2025-12-31T23:59:59.999Z'::timestamptz, '2026-01-01T00:00:00Z'::timestamptz, '2026-01-30T23:58:59.999Z'::timestamptz,
            '2026-01-30T23:59:00Z'::timestamptz]) WITH ORDINALITY AS times(instant, position)
          WHERE id = $1 ORDER BY position`, [tournamentId])).rows;
        assert.deepEqual(rows.map((r) => r.available), [false, true, true, false]);
      }
    });
  });

  await t.test('registration requires same-player accepted 25 GP debit and existing player/tournament', async () => {
    const id = await player();
    const other = await player();
    for (const kind of ['missingPlayer', 'missingTournament', 'missingLedger', 'wrongMutation', 'credit', 'wrongFee', 'crossPlayer', 'nullLedger']) {
      await assert.rejects(inTransaction(db, async (connection) => {
        const executor = new GpExecutor(connection);
        const registrationId = randomUUID();
        const input = { playerId: id, operationName: 'link_fixture', operationVersion: 1, idempotencyKey: randomUUID(), amount: kind === 'wrongFee' ? 24 : 25,
          reason: 'fixture', sourceType: 'knockout_registration', sourceId: `${tournamentId}:${registrationId}`, context: {} };
        const financial = await (kind === 'credit' ? executor.credit(input) : executor.debit(input));
        assert.ok(financial.status === 'completed' && financial.outcome.status === 'accepted');
        await connection.query(`INSERT INTO stoppy_knockout.registrations (id, player_id, tournament_id, gp_ledger_id, gp_mutation_id)
          VALUES ($1, $2, $3, $4, $5)`, [registrationId, kind === 'missingPlayer' ? randomUUID() : kind === 'crossPlayer' ? other : id,
          kind === 'missingTournament' ? randomUUID() : tournamentId,
          kind === 'nullLedger' ? null : kind === 'missingLedger' ? randomUUID() : financial.outcome.ledgerId,
          kind === 'wrongMutation' ? randomUUID() : financial.outcome.mutationId]);
      }), code(kind === 'nullLedger' ? '23502' : '23503'));
    }
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 100);
    const registration = await inTransaction(db, (c) => insertRegistrationFixture(c, id, tournamentId));
    await assert.rejects(inTransaction(db, (c) => insertRegistrationFixture(c, id, tournamentId)), code('23505'));
    await assert.rejects(db.query(`INSERT INTO stoppy_knockout.registrations (player_id, tournament_id, gp_ledger_id, gp_mutation_id)
      VALUES ($1, $2, $3, $4)`, [id, second.id, registration.gp_ledger_id, registration.gp_mutation_id]), code('23505'));
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 75);
  });

  await t.test('an unrelated or differently attributed 25 GP debit cannot finance a registration', async () => {
    const id = await player();
    for (const kind of ['otherPurpose', 'otherRegistration', 'otherTournament']) {
      await assert.rejects(inTransaction(db, async (connection) => {
        const registrationId = randomUUID();
        const sourceId = kind === 'otherRegistration' ? randomUUID() : registrationId;
        const sourceTournament = kind === 'otherTournament' ? second.id as string : tournamentId;
        const result = await new GpExecutor(connection).debit({ playerId: id, operationName: 'attribution_fixture',
          operationVersion: 1, idempotencyKey: randomUUID(), amount: 25, reason: 'test_only',
          sourceType: kind === 'otherPurpose' ? 'unrelated_purchase' : 'knockout_registration',
          sourceId: `${sourceTournament}:${sourceId}`, context: {} });
        assert.ok(result.status === 'completed' && result.outcome.status === 'accepted');
        await connection.query(`INSERT INTO stoppy_knockout.registrations
          (id, player_id, tournament_id, gp_ledger_id, gp_mutation_id) VALUES ($1, $2, $3, $4, $5)`,
        [registrationId, id, tournamentId, result.outcome.ledgerId, result.outcome.mutationId]);
      }), code('23503'));
    }
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 100);
    const registration = await inTransaction(db, (c) => insertRegistrationFixture(c, id, tournamentId));
    const ledger = (await db.query('SELECT * FROM stoppy_economy.gp_ledger WHERE id = $1', [registration.gp_ledger_id])).rows[0]!;
    assert.equal(ledger.source_type, 'knockout_registration');
    assert.equal(ledger.source_id, `${tournamentId}:${registration.id}`);
    assert.equal(ledger.mutation_id, registration.gp_mutation_id);
    assert.equal(ledger.delta, -25);
    await assert.rejects(db.query('UPDATE stoppy_economy.gp_ledger SET source_id = $1 WHERE id = $2',
      [randomUUID(), ledger.id]), code('55000'));
    await assert.rejects(db.query('UPDATE stoppy_economy.gp_mutations SET request_fingerprint = $1 WHERE id = $2',
      ['b'.repeat(64), registration.gp_mutation_id]), code('55000'));
  });

  await t.test('business outcomes bind accepted registration to the same player and tournament', async () => {
    const id = await player();
    const other = await player();
    const registration = await inTransaction(db, (c) => insertRegistrationFixture(c, id, tournamentId));
    await assert.rejects(insertOperationFixture(db, other, tournamentId, registration.id as string), code('23503'));
    await assert.rejects(insertOperationFixture(db, id, second.id as string, registration.id as string), code('23503'));
    await assert.rejects(insertOperationFixture(db, id, tournamentId, randomUUID()), code('23503'));
    await assert.rejects(insertOperationFixture(db, id, tournamentId, registration.id as string, { reason: 'insufficientGp' }), code('23514'));
    await assert.rejects(insertOperationFixture(db, id, tournamentId, registration.id as string, { status: 'rejected', reason: 'insufficientGp' }), code('23514'));
    const outcome = await insertOperationFixture(db, id, tournamentId, registration.id as string, { outcome: { registrationId: registration.id, historicalRemainingGp: 75 } });
    assert.equal(outcome.outcome_status, 'accepted');
    assert.equal(outcome.registration_id, registration.id);
    await assert.rejects(insertOperationFixture(db, id, tournamentId, registration.id as string), code('23505'));
    await inTransaction(db, (connection) => new GpExecutor(connection).credit({ playerId: id,
      operationName: 'later_balance_fixture', operationVersion: 1, idempotencyKey: randomUUID(), amount: 2,
      reason: 'test_only', sourceType: 'fixture', sourceId: randomUUID(), context: {} }));
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 77);
    const stored = (await db.query('SELECT semantic_outcome FROM stoppy_knockout.registration_operations WHERE id = $1', [outcome.id])).rows[0]!.semantic_outcome;
    assert.deepEqual(stored, { registrationId: registration.id, historicalRemainingGp: 75 });
  });

  await t.test('business idempotency scope, formats and rejected outcomes do not consume a registration or movement', async () => {
    const id = await player(5);
    const key = 'same-key';
    const first = await insertOperationFixture(db, id, tournamentId, null, { key });
    await assert.rejects(insertOperationFixture(db, id, tournamentId, null, { key }), code('23505'));
    await assert.rejects(insertOperationFixture(db, id, tournamentId, null, { key, fingerprint: 'b'.repeat(64) }), code('23505'));
    await insertOperationFixture(db, id, tournamentId, null, { key, version: 2 });
    await insertOperationFixture(db, id, tournamentId, null, { key, name: 'other_operation' });
    await insertOperationFixture(db, await player(), tournamentId, null, { key });
    await insertOperationFixture(db, id, null, null, { reason: 'tournamentUnavailable' });
    await assert.rejects(insertOperationFixture(db, id, null), code('23514'));
    for (const options of [{ status: 'pending' }, { status: 'accepted' }, { reason: null }, { reason: 'bad' },
      { key: 'bad key' }, { version: 0 }, { fingerprintVersion: 0 }, { fingerprint: 'bad' }, { outcome: [] }]) {
      await assert.rejects(insertOperationFixture(db, id, tournamentId, null, options), code('23514'));
    }
    assert.equal((await db.query('SELECT id FROM stoppy_knockout.registrations WHERE player_id = $1', [id])).rows.length, 0);
    assert.equal((await db.query('SELECT id FROM stoppy_economy.gp_ledger WHERE player_id = $1', [id])).rows.length, 1);
    assert.equal((await db.query('SELECT id FROM stoppy_economy.gp_mutations WHERE player_id = $1', [id])).rows.length, 0);
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 5);
    assert.equal(first.rejection_reason, 'insufficientGp');
  });

  await t.test('outer failure rolls back provisional registration, financial writes and final business outcome', async () => {
    const id = await player();
    await assert.rejects(inTransaction(db, async (connection) => {
      const registration = await insertRegistrationFixture(connection, id, tournamentId);
      await insertOperationFixture(connection, id, tournamentId, registration.id as string);
      await connection.query('SELECT 1 / 0');
    }), code('22012'));
    for (const table of ['stoppy_knockout.registrations', 'stoppy_knockout.registration_operations', 'stoppy_economy.gp_mutations']) {
      assert.equal((await db.query(`SELECT id FROM ${table} WHERE player_id = $1`, [id])).rows.length, 0);
    }
    assert.equal((await db.query('SELECT movement_type FROM stoppy_economy.gp_ledger WHERE player_id = $1', [id])).rows.length, 1);
    assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 100);
  });

  await t.test('registration evidence and final outcomes reject updates/deletes/truncation', async () => {
    for (const table of ['registrations', 'registration_operations']) {
      for (const sql of [`UPDATE stoppy_knockout.${table} SET player_id = player_id`, `DELETE FROM stoppy_knockout.${table}`,
        `TRUNCATE stoppy_knockout.${table} CASCADE`]) await assert.rejects(db.query(sql), code('55000'));
    }
  });

  await t.test('overlapping registration attempts cannot commit twice or retain two fixture debits', async () => {
    const id = await player();
    const firstConnection = await db.connect();
    let secondPid = 0;
    let attempted!: () => void;
    const started = new Promise<void>((resolve) => { attempted = resolve; });
    await firstConnection.query('BEGIN');
    try {
      await insertRegistrationFixture(firstConnection, id, tournamentId);
      const wrapped: Database = { query: (s, v) => db.query(s, v), close: async () => {}, connect: async () => {
        const c = await db.connect();
        secondPid = (await c.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number;
        return { release: (d) => c.release(d), query: (s, v) => { if (s.includes('FOR UPDATE')) attempted(); return c.query(s, v); } };
      } };
      const secondAttempt = assert.rejects(inTransaction(wrapped, (c) => insertRegistrationFixture(c, id, tournamentId)), code('23505'));
      await started;
      let blocked = false;
      const deadline = Date.now() + 1500;
      do {
        blocked = ((await db.query('SELECT cardinality(pg_blocking_pids($1)) AS count', [secondPid])).rows[0]!.count as number) > 0;
        if (!blocked) await setImmediate();
      } while (!blocked && Date.now() < deadline);
      // Release the lock even on an assertion failure so no test connection hangs.
      await firstConnection.query('COMMIT');
      await secondAttempt;
      assert.equal(blocked, true);
      assert.equal((await db.query('SELECT id FROM stoppy_knockout.registrations WHERE player_id = $1', [id])).rows.length, 1);
      assert.equal((await db.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [id])).rows[0]!.game_points, 75);
    } catch (error) { await firstConnection.query('ROLLBACK'); throw error; }
    finally { firstConnection.release(); }
  });
}
