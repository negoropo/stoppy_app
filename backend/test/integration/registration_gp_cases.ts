import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import { setImmediate } from 'node:timers/promises';
import type { Database, TransactionConnection } from '../../src/database.js';
import type { Config } from '../../src/config.js';
import { buildApp } from '../../src/app.js';
import { PostgresAuthRepository } from '../../src/auth/auth_repository.js';
import { AuthService } from '../../src/auth/auth_service.js';
import { ArgonPasswordHasher } from '../../src/auth/password_hasher.js';
import { TokenService } from '../../src/auth/token_service.js';
import { GpRepository } from '../../src/economy/gp_repository.js';
import { GpService } from '../../src/economy/gp_service.js';
import { inTransaction } from '../../src/transaction.js';
import { readAuthState } from './gp_schema_cases.js';

export async function testRegistrationGp(t: TestContext, database: Database, config: Config, now: () => Date) {
  const passwords = new ArgonPasswordHasher();
  const tokens = new TokenService(config.auth);
  const makeAuth = (db: Database) => new AuthService(config.auth, new PostgresAuthRepository(db, now), passwords, tokens, now);
  const auth = makeAuth(database);
  // Child HTTP apps must not close the shared integration pool.
  const borrowed = (connect = () => database.connect()): Database => ({
    query: (sql, values) => database.query(sql, values), connect, close: async () => {},
  });
  const openings = async (id: string) => (await database.query(`SELECT * FROM stoppy_economy.gp_ledger
    WHERE player_id = $1 ORDER BY id`, [id])).rows;
  const initial = await readAuthState(database);
  const originalPlayerIds = initial.players.map((row) => row.id);
  const originalLedger = (await database.query(`SELECT * FROM stoppy_economy.gp_ledger
    WHERE player_id = ANY($1::uuid[]) ORDER BY id`, [originalPlayerIds])).rows;

  await t.test('HTTP registration/profile/login/refresh retain 5 GP and exactly one zero-delta opening', async () => {
    const app = buildApp(config, borrowed(), { auth });
    try {
      const registration = await app.inject({ method: 'POST', url: '/api/v1/auth/register',
        payload: { username: 'OpeningHttpPlayer', password: ' pass ' } });
      assert.equal(registration.statusCode, 200);
      const result = registration.json();
      assert.equal(result.success, true);
      assert.deepEqual(Object.keys(result.data).sort(), ['playerProfile', 'session']);
      const profile = result.data.playerProfile;
      assert.equal(profile.gamePoints, 5);
      const rows = await openings(profile.id);
      assert.equal(rows.length, 1);
      const row = rows[0]!;
      assert.equal(row.movement_type, 'opening_snapshot');
      assert.equal(row.reason, 'opening_snapshot');
      assert.equal(row.source_type, 'opening_snapshot');
      assert.equal(row.source_id, profile.id);
      assert.equal(row.mutation_id, null);
      assert.equal(row.delta, 0);
      assert.equal(row.balance_before, 5);
      assert.equal(row.balance_after, 5);
      assert.equal((await database.query('SELECT count(*)::int AS count FROM stoppy_economy.gp_mutations WHERE player_id = $1', [profile.id])).rows[0]!.count, 0);
      const readProfile = await app.inject({ url: '/api/v1/player/profile',
        headers: { authorization: 'Bearer ' + result.data.session.accessToken } });
      assert.deepEqual(readProfile.json(), { success: true, data: profile });
      const login = await app.inject({ method: 'POST', url: '/api/v1/auth/login',
        payload: { username: 'openinghttpplayer', password: ' pass ' } });
      assert.equal(login.statusCode, 200);
      assert.deepEqual(login.json().data.playerProfile, profile);
      const refresh = await app.inject({ method: 'POST', url: '/api/v1/auth/refresh',
        payload: { refreshToken: login.json().data.session.refreshToken } });
      assert.equal(refresh.statusCode, 200);
      assert.deepEqual(Object.keys(refresh.json().data), ['session']);
      const afterRefresh = await app.inject({ url: '/api/v1/player/profile',
        headers: { authorization: 'Bearer ' + refresh.json().data.session.accessToken } });
      assert.deepEqual(afterRefresh.json(), { success: true, data: profile });
      assert.deepEqual(await openings(profile.id), rows);
      for (const url of ['/api/v1/gp/credit', '/api/v1/gp/debit']) {
        assert.equal((await app.inject({ method: 'POST', url, headers: { authorization: 'Bearer ' + refresh.json().data.session.accessToken },
          payload: { playerId: profile.id, amount: 1000 } })).statusCode, 404);
      }
      assert.equal((await auth.profile('Bearer ' + refresh.json().data.session.accessToken)).gamePoints, 5);
    } finally { await app.close(); }
  });

  await t.test('new registered account is immediately usable by the internal GP service without another baseline', async () => {
    const registered = await auth.register({ username: 'OpeningInternalPlayer', password: 'pass' });
    const playerId = registered.playerProfile.id;
    const gp = new GpService(database);
    const input = { playerId, operationName: 'registration_test_only', operationVersion: 1, idempotencyKey: randomUUID(),
      amount: 2, reason: 'test_only', sourceType: 'test_fixture', sourceId: randomUUID(), context: { test: 'internal' } };
    const credit = await gp.credit(input);
    assert.equal(credit.status, 'completed');
    if (credit.status === 'completed') { assert.equal(credit.outcome.status, 'accepted'); assert.equal(credit.currentBalance, 7); }
    const debit = await gp.debit({ ...input, idempotencyKey: randomUUID(), sourceId: randomUUID() });
    assert.equal(debit.status, 'completed');
    if (debit.status === 'completed') { assert.equal(debit.outcome.status, 'accepted'); assert.equal(debit.currentBalance, 5); }
    const rows = await openings(playerId);
    assert.equal(rows.length, 3);
    assert.equal(rows.filter((row) => row.movement_type === 'opening_snapshot').length, 1);
    assert.equal(5 + rows.reduce((sum, row) => sum + (row.delta as number), 0), 5);
  });

  await t.test('duplicate registration and duplicate opening attempts leave the original player and baseline unchanged', async () => {
    const original = await auth.register({ username: 'OpeningDuplicatePlayer', password: 'pass' });
    const id = original.playerProfile.id;
    const before = await openings(id);
    await assert.rejects(auth.register({ username: 'OPENINGDUPLICATEPLAYER', password: 'pass' }),
      (error: unknown) => error instanceof Error && 'code' in error && error.code === 'conflict');
    await assert.rejects(inTransaction(database, (connection) => new GpRepository(connection).createOpeningSnapshot(id)),
      (error: unknown) => error instanceof Error && 'code' in error && error.code === '23505');
    assert.deepEqual(await openings(id), before);
    assert.deepEqual(await auth.profile('Bearer ' + original.session.accessToken), original.playerProfile);
    assert.equal((await database.query('SELECT count(*)::int AS count FROM stoppy_auth.auth_sessions WHERE player_id = $1', [id])).rows[0]!.count, 1);
  });

  for (const [stage, prefix] of [
    ['opening', 'INSERT INTO stoppy_economy.gp_ledger'], ['session', 'INSERT INTO stoppy_auth.auth_sessions'],
    ['refresh token', 'INSERT INTO stoppy_auth.auth_refresh_tokens'],
  ] as const) {
    await t.test(`real ${stage} persistence failure rolls back account, opening and credentials and returns a safe HTTP error`, async () => {
      const calls: string[] = [];
      let id = '';
      let tokenId = '';
      let connects = 0;
      const releases: boolean[] = [];
      const db = borrowed(async () => {
        connects++;
        const connection = await database.connect();
        return { release: (discard = false) => { releases.push(discard); connection.release(discard); },
          query: async (sql, values) => {
            calls.push(sql);
            if (sql.startsWith('INSERT INTO stoppy_auth.players')) id = values![0] as string;
            if (sql.startsWith('INSERT INTO stoppy_auth.auth_refresh_tokens')) tokenId = values![0] as string;
            const result = await connection.query(sql, values);
            if (sql.startsWith(prefix)) await connection.query('SELECT 1 / 0');
            return result;
          } };
      });
      const app = buildApp(config, db, { auth: makeAuth(db) });
      try {
        const response = await app.inject({ method: 'POST', url: '/api/v1/auth/register',
          payload: { username: 'FailedOpening' + stage.replaceAll(' ', ''), password: 'SECRET_PASSWORD' } });
        assert.equal(response.statusCode, 500);
        assert.deepEqual(response.json(), { success: false, error: { code: 'serverError', message: 'Internal server error.' } });
        assert.doesNotMatch(response.body, /SECRET|division by zero|postgres|accessToken|refreshToken|password_hash/);
        assert.equal(connects, 1);
        assert.deepEqual(releases, [false]);
        assert.equal(calls.at(-1), 'ROLLBACK');
        assert.ok(!calls.includes('COMMIT'));
        assert.ok(id);
        assert.equal((await database.query('SELECT id FROM stoppy_auth.players WHERE id = $1', [id])).rows.length, 0);
        assert.deepEqual(await openings(id), []);
        assert.equal((await database.query('SELECT id FROM stoppy_auth.auth_sessions WHERE player_id = $1', [id])).rows.length, 0);
        if (tokenId) assert.equal((await database.query('SELECT id FROM stoppy_auth.auth_refresh_tokens WHERE id = $1', [tokenId])).rows.length, 0);
      } finally { await app.close(); }
    });
  }

  await t.test('invalid password-hash persistence cannot leave an account or opening snapshot', async () => {
    const id = randomUUID();
    await assert.rejects(new PostgresAuthRepository(database).register(id, 'InvalidHashOpening', 'not-an-argon-hash', {
      id: randomUUID(), playerId: id, tokenId: randomUUID(), digest: 'a'.repeat(64), createdAt: now(), expiresAt: new Date(now().getTime() + 86400000),
    }), (error: unknown) => error instanceof Error && 'code' in error && error.code === '23514');
    assert.equal((await database.query('SELECT id FROM stoppy_auth.players WHERE id = $1', [id])).rows.length, 0);
    assert.deepEqual(await openings(id), []);
  });

  for (const committed of [false, true]) {
    await t.test(`registration uncertain COMMIT (${committed ? 'persisted' : 'not sent'}) never retries and keeps all registration rows atomic`, async () => {
      let id = '';
      let commits = 0;
      let connects = 0;
      let backendPid = 0;
      const releases: boolean[] = [];
      const db = borrowed(async () => {
        connects++;
        const connection: TransactionConnection = await database.connect();
        backendPid = (await connection.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number;
        return { release: (discard = false) => { releases.push(discard); connection.release(discard); },
          query: async (sql, values) => {
            if (sql.startsWith('INSERT INTO stoppy_auth.players')) id = values![0] as string;
            if (sql === 'COMMIT') {
              commits++;
              if (committed) await connection.query(sql, values);
              throw new Error('PRIVATE lost commit acknowledgement');
            }
            return connection.query(sql, values);
          } };
      });
      await assert.rejects(makeAuth(db).register({ username: 'CommitOpening' + committed, password: 'pass' }));
      assert.equal(connects, 1);
      assert.equal(commits, 1);
      assert.deepEqual(releases, [true]);
      // A new uncommitted player is invisible to SELECT FOR UPDATE. Observe
      // backend exit instead, so assertions cannot race disconnect rollback.
      const deadline = Date.now() + 2000;
      let connected = true;
      do {
        connected = (await database.query('SELECT pid FROM pg_stat_activity WHERE pid = $1', [backendPid])).rows.length !== 0;
        if (connected) await setImmediate();
      } while (connected && Date.now() < deadline);
      assert.equal(connected, false, 'Discarded registration connection must finish disconnect cleanup.');
      const players = (await database.query('SELECT * FROM stoppy_auth.players WHERE id = $1', [id])).rows;
      const ledger = await openings(id);
      const sessions = (await database.query('SELECT * FROM stoppy_auth.auth_sessions WHERE player_id = $1', [id])).rows;
      assert.equal(players.length, committed ? 1 : 0);
      assert.equal(ledger.length, committed ? 1 : 0);
      assert.equal(sessions.length, committed ? 1 : 0);
      if (committed) {
        assert.equal(players[0]!.game_points, 5);
        assert.equal(ledger[0]!.delta, 0);
        const credentials = (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE session_id = $1', [sessions[0]!.id])).rows;
        assert.equal(credentials.length, 1);
        const login = await auth.login({ username: 'CommitOpeningtrue', password: 'pass' });
        assert.equal(login.playerProfile.id, id);
        assert.equal((await openings(id)).length, 1);
      }
    });
  }

  await t.test('Step 3 registration never changes existing players, sessions, refresh credentials or opening snapshots', async () => {
    const all = await readAuthState(database);
    const players = all.players.filter((row) => originalPlayerIds.includes(row.id));
    const sessions = all.sessions.filter((row) => originalPlayerIds.includes(row.player_id));
    const sessionIds = sessions.map((row) => row.id);
    const credentials = all.tokens.filter((row) => sessionIds.includes(row.session_id));
    assert.deepEqual({ players, sessions, tokens: credentials }, initial);
    assert.deepEqual((await database.query(`SELECT * FROM stoppy_economy.gp_ledger
      WHERE player_id = ANY($1::uuid[]) ORDER BY id`, [originalPlayerIds])).rows, originalLedger);
  });
}
