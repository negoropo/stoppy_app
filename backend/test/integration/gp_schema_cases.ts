import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import type { Database } from '../../src/database.js';
import { ArgonPasswordHasher } from '../../src/auth/password_hasher.js';

const intMax = 2147483647;
const fingerprint = 'a'.repeat(64);
const errorCode = (code: string) => (error: unknown): boolean =>
  error instanceof Error && 'code' in error && error.code === code;

export async function prepareGpBackfill(database: Database) {
  const ids: string[] = [];
  const hash = await new ArgonPasswordHasher().hash('migration-fixture-password');
  for (const [index, balance] of [0, 5, 37, intMax].entries()) {
    const id = randomUUID();
    ids.push(id);
    await database.query(`INSERT INTO stoppy_auth.players
      (id, username, password_hash, created_at, game_points, ads_removed,
       last_daily_gp_awarded_at, current_league_division, has_weekly_league_entry, reserved_league_slot)
      VALUES ($1, $2, $3, '2026-01-01T12:00:00Z', $4, true,
        '2026-01-02T12:00:00Z', 2, true, true)`, [id, `MigrationPlayer${index}`, hash, balance]);
    const sessionId = randomUUID();
    await database.query(`INSERT INTO stoppy_auth.auth_sessions (id, player_id, created_at, expires_at)
      VALUES ($1, $2, '2026-01-01T12:00:00Z', '2027-01-01T12:00:00Z')`, [sessionId, id]);
    await database.query(`INSERT INTO stoppy_auth.auth_refresh_tokens (id, session_id, token_digest, created_at, expires_at)
      VALUES ($1, $2, $3, '2026-01-01T12:00:00Z', '2027-01-01T12:00:00Z')`,
    [randomUUID(), sessionId, String(index + 1).repeat(64)]);
  }
  return { ids, before: await readAuthState(database) };
}

export async function readAuthState(database: Database) {
  return {
    players: (await database.query('SELECT * FROM stoppy_auth.players ORDER BY id')).rows,
    sessions: (await database.query('SELECT * FROM stoppy_auth.auth_sessions ORDER BY id')).rows,
    tokens: (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens ORDER BY id')).rows,
  };
}

export async function testGpSchema(t: TestContext, database: Database, fixtures: Awaited<ReturnType<typeof prepareGpBackfill>>) {
  const playerId = fixtures.ids[1]!;
  const otherPlayerId = fixtures.ids[2]!;
  interface MutationOptions {
    player?: string; operation?: string; version?: number; key?: string; fingerprintVersion?: number;
    digest?: string; status?: string; outcome?: unknown; context?: unknown;
  }
  const mutation = async (options: MutationOptions = {}) => {
    const result = await database.query(`INSERT INTO stoppy_economy.gp_mutations
      (player_id, operation_name, operation_version, idempotency_key, fingerprint_version,
       request_fingerprint, outcome_status, semantic_outcome, resolved_context)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9::jsonb) RETURNING *`, [
      options.player ?? playerId, options.operation ?? 'fixture_operation', options.version ?? 1,
      options.key ?? randomUUID(), options.fingerprintVersion ?? 1, options.digest ?? fingerprint,
      options.status ?? 'accepted', JSON.stringify(options.outcome === undefined ? { result: 'fixture' } : options.outcome),
      JSON.stringify(options.context === undefined ? { sourceId: 'fixture-source' } : options.context),
    ]);
    return result.rows[0]!;
  };
  interface MovementOptions {
    player?: string; mutationId?: unknown; movement?: string; reason?: string; sourceType?: string;
    sourceId?: string; delta?: number; before?: number; after?: number;
  }
  const movement = async (options: MovementOptions = {}) => {
    const result = await database.query(`INSERT INTO stoppy_economy.gp_ledger
      (player_id, mutation_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`, [options.player ?? playerId,
      options.mutationId ?? null, options.movement ?? 'credit', options.reason ?? 'fixture_credit',
      options.sourceType ?? 'fixture_source', options.sourceId ?? randomUUID(), options.delta ?? 1,
      options.before ?? 5, options.after ?? 6]);
    return result.rows[0]!;
  };

  await t.test('003 preserves all existing player/profile/session/token fields and backfills one snapshot per player', async () => {
    assert.deepEqual(await readAuthState(database), fixtures.before);
    const rows = (await database.query(`SELECT * FROM stoppy_economy.gp_ledger
      WHERE movement_type = 'opening_snapshot' ORDER BY player_id`)).rows;
    assert.equal(rows.length, fixtures.ids.length);
    for (const player of fixtures.before.players) {
      const openings = rows.filter((row) => row.player_id === player.id);
      assert.equal(openings.length, 1);
      const opening = openings[0]!;
      assert.equal(opening.delta, 0);
      assert.equal(opening.balance_before, player.game_points);
      assert.equal(opening.balance_after, player.game_points);
      assert.equal(opening.source_type, 'opening_snapshot');
      assert.equal(opening.source_id, player.id);
      assert.equal(opening.mutation_id, null);
      assert.ok(opening.created_at instanceof Date);
      assert.match(opening.id as string, /^[0-9a-f-]{36}$/);
    }
    assert.ok(rows.some((row) => row.balance_after === 0));
    assert.ok(rows.some((row) => row.balance_after === intMax));
    assert.equal((await database.query('SELECT count(*)::int AS count FROM stoppy_economy.gp_mutations')).rows[0]!.count, 0);
  });

  await t.test('ledger permits signed credits/debits with exact integer arithmetic and no wallet side effects', async () => {
    const before = (await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [playerId])).rows[0]!.game_points;
    const credit = await movement({ before: 0, after: intMax, delta: intMax });
    const debit = await movement({ movement: 'debit', reason: 'fixture_debit', before: intMax, after: 0, delta: -intMax });
    assert.equal(credit.balance_after, intMax);
    assert.equal(debit.balance_after, 0);
    assert.equal((await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [playerId])).rows[0]!.game_points, before);
  });

  await t.test('ledger rejects inconsistent arithmetic, negative balances and invalid movement signs', async () => {
    for (const options of [
      { after: 7 }, { before: -1, after: 0 }, { before: 0, after: -1, delta: -1, movement: 'debit' },
      { delta: 0, before: 5, after: 5 }, { movement: 'debit' },
      { movement: 'credit', delta: -1, after: 4 },
      { before: intMax, after: 0, delta: 1 },
      { movement: 'credit', reason: 'opening_snapshot' }, { movement: 'unknown' },
    ]) await assert.rejects(movement(options), errorCode('23514'));
    for (const options of [{ before: intMax + 1 }, { after: intMax + 1 }, { delta: intMax + 1 }, { delta: -intMax - 2 }]) {
      await assert.rejects(movement(options), errorCode('22003'));
    }
  });

  await t.test('opening snapshots are unique observations and cannot be disguised as credits', async () => {
    const opening = { movement: 'opening_snapshot', reason: 'opening_snapshot', sourceType: 'opening_snapshot',
      sourceId: playerId, delta: 0, before: 5, after: 5 };
    await assert.rejects(movement(opening), errorCode('23505'));
    for (const options of [{ ...opening, sourceId: randomUUID() }, { ...opening, delta: 1, after: 6 },
      { ...opening, mutationId: (await mutation()).id }]) {
      await assert.rejects(movement(options), errorCode('23514'));
    }
  });

  await t.test('different idempotency keys cannot duplicate a logical source but distinct actions remain valid', async () => {
    const first = await mutation({ key: 'source-first' });
    const second = await mutation({ key: 'source-second' });
    const sourceId = randomUUID();
    await movement({ mutationId: first.id, sourceId });
    await assert.rejects(movement({ mutationId: second.id, sourceId }), errorCode('23505'));
    await movement({ mutationId: second.id, sourceId: randomUUID() });
    await movement({ sourceId, sourceType: 'another_fixture_component' });
    await movement({ player: otherPlayerId, sourceId });
  });

  await t.test('ledger foreign keys bind optional mutations to accepted outcomes of the same player', async () => {
    await assert.rejects(movement({ player: randomUUID() }), errorCode('23503'));
    await assert.rejects(mutation({ player: randomUUID() }), errorCode('23503'));
    await assert.rejects(movement({ mutationId: randomUUID() }), errorCode('23503'));
    const other = await mutation({ player: otherPlayerId });
    await assert.rejects(movement({ mutationId: other.id }), errorCode('23503'));
    const rejected = await mutation({ status: 'rejected', outcome: { rejectionCode: 'fixture_rejection' } });
    await assert.rejects(movement({ mutationId: rejected.id }), errorCode('23503'));
    const accepted = await mutation();
    const result = await movement({ mutationId: accepted.id });
    assert.equal(result.mutation_id, accepted.id);
  });

  await t.test('idempotency uniqueness includes player, operation, version and case-sensitive key', async () => {
    await mutation({ key: 'Stable-Key' });
    await assert.rejects(mutation({ key: 'Stable-Key' }), errorCode('23505'));
    await assert.rejects(mutation({ key: 'Stable-Key', digest: 'b'.repeat(64) }), errorCode('23505'));
    await mutation({ key: 'Stable-Key', player: otherPlayerId });
    await mutation({ key: 'Stable-Key', operation: 'another_operation' });
    await mutation({ key: 'Stable-Key', version: 2 });
    await mutation({ key: 'stable-key' });
  });

  await t.test('concurrent inserts cannot create two outcomes for the same scoped idempotency key', async () => {
    const key = randomUUID();
    const results = await Promise.allSettled([mutation({ key }), mutation({ key })]);
    assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
    const rejected = results.find((result) => result.status === 'rejected') as PromiseRejectedResult;
    assert.ok(errorCode('23505')(rejected.reason));
    const rows = (await database.query(`SELECT id FROM stoppy_economy.gp_mutations
      WHERE player_id = $1 AND operation_name = 'fixture_operation' AND operation_version = 1 AND idempotency_key = $2`,
    [playerId, key])).rows;
    assert.equal(rows.length, 1);
  });

  await t.test('idempotency keys and fingerprints enforce their explicit format and bounds', async () => {
    await mutation({ key: 'A0._:-'.repeat(21) + 'zz' }); // Exactly 128 characters.
    for (const key of ['', ' ', ' bad', 'bad ', 'bad/key', 'a\nb', 'bad\n', 'a'.repeat(129), '\u0085']) {
      await assert.rejects(mutation({ key }), errorCode('23514'));
    }
    for (const options of [{ operation: 'bad operation' }, { operation: '' }, { version: 0 }, { fingerprintVersion: 0 },
      { digest: '' }, { digest: 'a'.repeat(63) }, { digest: 'A'.repeat(64) }, { digest: 'g'.repeat(64) }]) {
      await assert.rejects(mutation(options), errorCode('23514'));
    }
  });

  await t.test('final accepted/rejected semantic outcomes and resolved context persist without changing GP', async () => {
    const originalBalance = (await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [playerId])).rows[0]!.game_points;
    for (const status of ['accepted', 'rejected']) {
      const outcome = { status, result: { balance: originalBalance, reason: 'fixture_only' } };
      const context = { seasonId: 'original-context', sourceId: randomUUID() };
      const row = await mutation({ status, outcome, context });
      const stored = (await database.query('SELECT * FROM stoppy_economy.gp_mutations WHERE id = $1', [row.id])).rows[0]!;
      assert.deepEqual(stored.semantic_outcome, outcome);
      assert.deepEqual(stored.resolved_context, context);
      assert.ok(stored.created_at instanceof Date);
      assert.ok((stored.completed_at as Date) >= (stored.created_at as Date));
    }
    assert.equal((await database.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1', [playerId])).rows[0]!.game_points, originalBalance);
    for (const options of [{ status: 'pending' }, { outcome: null }, { outcome: [] }, { context: [] }]) {
      await assert.rejects(mutation(options), errorCode('23514'));
    }
    await assert.rejects(database.query(`INSERT INTO stoppy_economy.gp_mutations
      (player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint,
       outcome_status, semantic_outcome, created_at, completed_at)
      VALUES ($1, 'fixture_operation', 1, $2, 1, $3, 'accepted', '{}',
        '2026-01-02T00:00:00Z', '2026-01-01T00:00:00Z')`, [playerId, randomUUID(), fingerprint]), errorCode('23514'));
  });

  await t.test('audit ledger and final mutation outcomes reject UPDATE, DELETE and TRUNCATE even for their owner', async () => {
    const ledgerBefore = (await database.query('SELECT * FROM stoppy_economy.gp_ledger ORDER BY id')).rows;
    const mutationsBefore = (await database.query('SELECT * FROM stoppy_economy.gp_mutations ORDER BY id')).rows;
    for (const table of ['gp_ledger', 'gp_mutations']) {
      for (const sql of [`UPDATE stoppy_economy.${table} SET created_at = created_at`,
        `DELETE FROM stoppy_economy.${table}`, `TRUNCATE stoppy_economy.${table} CASCADE`]) {
        await assert.rejects(database.query(sql), errorCode('55000'));
      }
    }
    assert.deepEqual((await database.query('SELECT * FROM stoppy_economy.gp_ledger ORDER BY id')).rows, ledgerBefore);
    assert.deepEqual((await database.query('SELECT * FROM stoppy_economy.gp_mutations ORDER BY id')).rows, mutationsBefore);
    await assert.rejects(database.query('DELETE FROM stoppy_auth.players WHERE id = $1', [playerId]), errorCode('23503'));
  });
}
