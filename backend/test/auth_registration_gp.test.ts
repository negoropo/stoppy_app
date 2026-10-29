import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PostgresAuthRepository, type NewSession } from '../src/auth/auth_repository.js';
import { AuthService } from '../src/auth/auth_service.js';
import { TokenService } from '../src/auth/token_service.js';
import { GpRepository } from '../src/economy/gp_repository.js';
import { ApiError } from '../src/api_error.js';
import { FakeDatabase, testConfig } from './fakes.js';

const now = new Date('2026-10-26T12:00:00Z');
const session = (id: string): NewSession => ({ id: randomUUID(), playerId: id, tokenId: randomUUID(),
  digest: 'a'.repeat(64), createdAt: now, expiresAt: new Date(now.getTime() + 86400000) });

class RegistrationDatabase extends FakeDatabase {
  failPrefix: string | undefined;
  missingOpeningPlayer = false;
  conflict = false;
  override async query(sql: string, values?: unknown[]) {
    await super.query(sql, values);
    if (this.failPrefix && sql.startsWith(this.failPrefix)) {
      if (this.conflict) throw Object.assign(new Error('PRIVATE_DATABASE_ERROR'), {
        code: '23505', constraint: 'players_canonical_username_key',
      });
      throw new Error('PRIVATE_DATABASE_ERROR');
    }
    if (sql.startsWith('INSERT INTO stoppy_auth.players')) return { rows: [{
      id: values![0], username: values![1], created_at: now, game_points: 5, ads_removed: false,
      last_daily_gp_awarded_at: null, current_league_division: null, has_weekly_league_entry: false, reserved_league_slot: false,
    }] };
    if (sql.startsWith('INSERT INTO stoppy_economy.gp_ledger')) return { rows: this.missingOpeningPlayer ? [] : [{ id: randomUUID() }] };
    return { rows: [] };
  }
}

test('registration records the opening on one connection before session/token writes and returns the unchanged profile', async () => {
  const db = new RegistrationDatabase();
  const id = randomUUID();
  const result = await new PostgresAuthRepository(db).register(id, 'Player', '$argon2id$test', session(id));
  assert.deepEqual(result, { id, username: 'Player', createdAt: now.toISOString(), gamePoints: 5,
    adsRemoved: false, lastDailyGpAwardedAt: null, currentLeagueDivision: null, hasWeeklyLeagueEntry: false, reservedLeagueSlot: false });
  assert.equal(db.connections, 1);
  assert.deepEqual(db.released, [false]);
  assert.deepEqual(db.calls.map((c) => c.sql.split('\n')[0]), [
    'BEGIN', "SET LOCAL lock_timeout = '3s'", 'INSERT INTO stoppy_auth.players (id, username, password_hash, created_at)',
    'INSERT INTO stoppy_economy.gp_ledger', 'INSERT INTO stoppy_auth.auth_sessions (id, player_id, created_at, expires_at)',
    'INSERT INTO stoppy_auth.auth_refresh_tokens (id, session_id, token_digest, created_at, expires_at)', 'COMMIT',
  ]);
  const opening = db.calls.find((c) => c.sql.startsWith('INSERT INTO stoppy_economy.gp_ledger'))!;
  assert.deepEqual(opening.values, [id]);
  assert.match(opening.sql, /id::text, 0, game_points, game_points/);
  assert.doesNotMatch(opening.sql, /ON CONFLICT|mutation_id/);
  assert.ok(!db.calls.some((c) => c.sql.startsWith('UPDATE') || c.sql.includes('gp_mutations')));
});

for (const [stage, prefix] of [
  ['player', 'INSERT INTO stoppy_auth.players'], ['opening', 'INSERT INTO stoppy_economy.gp_ledger'],
  ['session', 'INSERT INTO stoppy_auth.auth_sessions'], ['refresh token', 'INSERT INTO stoppy_auth.auth_refresh_tokens'],
] as const) {
  test(`${stage} write failure rolls back the same connection without COMMIT or automatic retry`, async () => {
    const db = new RegistrationDatabase(); db.failPrefix = prefix;
    const id = randomUUID();
    await assert.rejects(new PostgresAuthRepository(db).register(id, 'Player', '$argon2id$test', session(id)), /PRIVATE_DATABASE_ERROR/);
    assert.equal(db.connections, 1);
    assert.deepEqual(db.released, [false]);
    assert.equal(db.calls.at(-1)!.sql, 'ROLLBACK');
    assert.ok(!db.calls.some((c) => c.sql === 'COMMIT'));
    assert.equal(db.calls.filter((c) => c.sql.startsWith(prefix)).length, 1);
  });
}

test('uncertain registration COMMIT discards once without rollback or retry', async () => {
  const db = new RegistrationDatabase(); db.failureSql = 'COMMIT';
  const id = randomUUID();
  await assert.rejects(new PostgresAuthRepository(db).register(id, 'Player', '$argon2id$test', session(id)));
  assert.equal(db.connections, 1);
  assert.deepEqual(db.released, [true]);
  assert.equal(db.calls.filter((c) => c.sql === 'COMMIT').length, 1);
  assert.ok(!db.calls.some((c) => c.sql === 'ROLLBACK'));
});

test('canonical username conflict preserves the safe auth error and never attempts a snapshot', async () => {
  const db = new RegistrationDatabase(); db.failPrefix = 'INSERT INTO stoppy_auth.players'; db.conflict = true;
  const id = randomUUID();
  await assert.rejects(new PostgresAuthRepository(db).register(id, 'Player', '$argon2id$test', session(id)),
    (error: unknown) => error instanceof ApiError && error.code === 'conflict' && error.statusCode === 409 && error.message === 'Username is already taken.');
  assert.ok(!db.calls.some((c) => c.sql.includes('gp_ledger')));
});

test('missing player cannot silently produce an empty opening insertion', async () => {
  const db = new RegistrationDatabase(); db.missingOpeningPlayer = true;
  await assert.rejects(new GpRepository(db).createOpeningSnapshot(randomUUID()), /requires an existing player/);
  assert.equal(db.connections, 0, 'The repository must not acquire a connection.');
  assert.equal(db.calls.length, 1);
});

test('password hashing failure does not create an account, baseline or session', async () => {
  const db = new RegistrationDatabase();
  const auth = new AuthService(testConfig.auth, new PostgresAuthRepository(db), {
    hash: async () => { throw new Error('Hashing unavailable.'); }, verify: async () => false,
  }, new TokenService(testConfig.auth), () => now);
  await assert.rejects(auth.register({ username: 'Player', password: 'pass' }), /Hashing unavailable/);
  assert.equal(db.connections, 0);
  assert.deepEqual(db.calls, []);
});
