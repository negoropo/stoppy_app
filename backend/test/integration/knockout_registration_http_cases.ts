import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomUUID } from 'node:crypto';
import { setImmediate } from 'node:timers/promises';
import { buildApp } from '../../src/app.js';
import { PostgresAuthRepository } from '../../src/auth/auth_repository.js';
import { TokenService } from '../../src/auth/token_service.js';
import { loadConfig, type Config } from '../../src/config.js';
import type { Database, TransactionConnection } from '../../src/database.js';
import { GpService } from '../../src/economy/gp_service.js';

export async function testKnockoutRegistrationHttp(t: TestContext, database: Database, config: Config) {
  const enabled = loadConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent', DATABASE_URL: config.databaseUrl,
    KNOCKOUT_REGISTRATION_HTTP: 'enabled' });
  const path = '/api/v1/knockout/register';
  const tokenService = new TokenService(enabled.auth);
  const repository = new PostgresAuthRepository(database);
  const gp = new GpService(database);
  let sequence = 0;
  let month = 0;
  const intent = (playerId: string, amount: number) => ({
    playerId, amount, operationName: 'http_fixture_gp', operationVersion: 1, idempotencyKey: randomUUID(),
    reason: 'test_only', sourceType: 'http_fixture', sourceId: randomUUID(), context: {},
  });
  const player = async (balance = 50) => {
    const id = randomUUID();
    const sessionId = randomUUID();
    const now = Date.now();
    const expiry = new Date(now + 3600_000);
    await repository.register(id, 'Http' + id.replaceAll('-', '').slice(0, 20), '$argon2id$fixture-only',
      { id: sessionId, playerId: id, tokenId: randomUUID(), digest: randomUUID().replaceAll('-', '').repeat(2),
        createdAt: new Date(now - 60_000), expiresAt: expiry });
    if (balance > 5) await gp.credit(intent(id, balance - 5));
    const token = await tokenService.issue(id, sessionId, 'fixture', new Date(now), expiry);
    return { id, sessionId, bearer: 'Bearer ' + token.accessToken };
  };
  const fixture = async (status = 'registrationOpen') => {
    const label = new Date(Date.UTC(2150, month++, 1)).toISOString().slice(0, 10);
    return (await database.query(`INSERT INTO stoppy_knockout.tournaments
      (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
      VALUES ($1, 'HTTP fixture', '2080-02-01T00:00:00Z', '2080-02-28T23:59:00Z', '2080-03-01T00:00:00Z', $2)
      RETURNING id`, [label, status])).rows[0]!.id as string;
  };
  const state = async (id: string) => (await database.query(`SELECT game_points AS balance,
    (SELECT count(*)::int FROM stoppy_knockout.registrations WHERE player_id = $1) AS entries,
    (SELECT count(*)::int FROM stoppy_knockout.registration_operations WHERE player_id = $1) AS operations,
    (SELECT count(*)::int FROM stoppy_economy.gp_ledger WHERE player_id = $1
      AND source_type = 'knockout_registration' AND delta = -25) AS fees FROM stoppy_auth.players WHERE id = $1`, [id])).rows[0];
  const appFor = (selected = enabled, intercept?: (connection: TransactionConnection, sql: string,
    values?: unknown[]) => ReturnType<TransactionConnection['query']>, read = database.query) => buildApp(selected, {
    ...database, query: read, close: async () => {}, async connect() {
      const connection = await database.connect();
      return { release: (discard) => connection.release(discard), query: (sql, values) => {
        if (sql.startsWith('WITH admission_clock')) {
          return connection.query(sql.replace('clock_timestamp()', '$2::timestamptz'), [values![0], '2080-02-15T12:00:00.123456Z']);
        }
        return intercept ? intercept(connection, sql, values) : connection.query(sql, values);
      } };
    },
  });
  const app = appFor();
  const post = (bearer: string, tournamentId: string, key = randomUUID() as string, target = app) => target.inject({
    method: 'POST', url: path, remoteAddress: `127.0.0.${++sequence}`,
    headers: { authorization: bearer, 'idempotency-key': key, 'content-type': 'application/json' }, payload: { tournamentId },
  });
  try {
    await t.test('default HTTP gate cannot mutate and verified session must belong to the bearer', async () => {
      const first = await player();
      const second = await player();
      const tournamentId = await fixture();
      const disabled = appFor({ ...enabled, knockoutRegistrationHttp: false });
      try {
        assert.equal((await post(first.bearer, tournamentId, randomUUID(), disabled)).statusCode, 404);
      } finally { await disabled.close(); }

      const now = new Date();
      const historical = new Date(now.getTime() - 3600_000);
      const expiry = new Date(now.getTime() + 3600_000);
      const mismatched = await tokenService.issue(first.id, second.sessionId, 'fixture', now, expiry);
      const expired = await tokenService.issue(first.id, first.sessionId, 'fixture', historical,
        new Date(now.getTime() - 1000));
      for (const token of [mismatched.accessToken, expired.accessToken]) {
        assert.equal((await post('Bearer ' + token, tournamentId)).statusCode, 401);
      }
      await database.query('UPDATE stoppy_auth.auth_sessions SET expires_at = $2 WHERE id = $1',
        [first.sessionId, new Date(now.getTime() - 1000)]);
      assert.equal((await post(first.bearer, tournamentId)).statusCode, 401);
      await database.query('UPDATE stoppy_auth.auth_sessions SET revoked_at = clock_timestamp() WHERE id = $1', [second.sessionId]);
      assert.equal((await post(second.bearer, tournamentId)).statusCode, 401);
      for (const { id } of [first, second]) assert.deepEqual(await state(id), { balance: 50, entries: 0, operations: 0, fees: 0 });
    });

    await t.test('concurrent identical requests charge one fee and replay historical GP alongside a fresh wallet', async () => {
      const { id, bearer } = await player();
      const tournamentId = await fixture();
      const key = randomUUID();
      const responses = await Promise.all([post(bearer, tournamentId, key), post(bearer, tournamentId, key)]);
      assert.ok(responses.every((response) => response.statusCode === 200));
      const receipts = responses.map((response) => response.json().data);
      assert.deepEqual(receipts.map((receipt) => receipt.status).sort(), ['accepted', 'idempotentReplay']);
      assert.deepEqual(receipts[0].playerEntry, receipts[1].playerEntry);
      for (const receipt of receipts) {
        assert.equal(receipt.newlyPersisted, !receipt.replayed);
        assert.equal(receipt.playerId, id);
        assert.equal(receipt.tournamentId, tournamentId);
        assert.equal(receipt.playerProfile.gamePoints, 25);
        assert.equal(receipt.historicalRemainingGamePoints, 25);
        assert.equal(receipt.playerEntry.registeredAt, '2080-02-15T12:00:00.123456Z');
        assert.equal(receipt.playerEntry.entryCostGamePoints, 25);
        assert.equal(receipt.tournament.rounds, undefined);
      }
      await gp.credit(intent(id, 11));
      await gp.debit(intent(id, 2));
      await database.query("UPDATE stoppy_knockout.tournaments SET status = 'completed' WHERE id = $1", [tournamentId]);
      const replay = (await post(bearer, tournamentId, key)).json().data;
      assert.equal(replay.status, 'idempotentReplay');
      assert.equal(replay.historicalRemainingGamePoints, 25);
      assert.equal(replay.playerProfile.gamePoints, 34);
      assert.equal(replay.tournament.status, 'completed');
      assert.deepEqual(replay.playerEntry, receipts[0].playerEntry);
      assert.deepEqual(await state(id), { balance: 34, entries: 1, operations: 1, fees: 1 });
    });

    await t.test('business rejections are correlated and replay without exposing wallet or fabricated catalog data', async () => {
      const { id, bearer } = await player(5);
      for (const [target, code] of [
        [await fixture(), 'insufficientGp'], [await fixture('registrationClosed'), 'registrationClosed'],
        [await fixture('unavailable'), 'tournamentUnavailable'], [randomUUID(), 'tournamentUnavailable'],
        [await fixture('inProgress'), 'tournamentAlreadyStarted'],
      ] as const) {
        const key = randomUUID();
        for (const replayed of [false, true]) {
          const response = await post(bearer, target, key);
          assert.equal(response.statusCode, 200, response.body);
          assert.deepEqual(response.json(), { success: true, data: { playerId: id, tournamentId: target,
            status: 'rejected', newlyPersisted: false, replayed, rejectionCode: code } });
        }
      }
      assert.deepEqual(await state(id), { balance: 5, entries: 0, operations: 5, fees: 0 });
    });

    await t.test('a changed target conflicts while another player can use the same key', async () => {
      const [first, second] = [await player(), await player()];
      const [original, other] = [await fixture(), await fixture()];
      const key = randomUUID();
      assert.equal((await post(first.bearer, original, key)).json().data.status, 'accepted');
      const conflict = await post(first.bearer, other, key);
      assert.equal(conflict.statusCode, 409);
      assert.equal(conflict.json().error.details.reason, 'idempotencyConflict');
      assert.equal((await post(first.bearer, original)).json().data.rejectionCode, 'duplicateRegistration');
      assert.equal((await post(second.bearer, original, key)).json().data.status, 'accepted');
      assert.deepEqual(await state(first.id), { balance: 25, entries: 1, operations: 2, fees: 1 });
      assert.deepEqual(await state(second.id), { balance: 25, entries: 1, operations: 1, fees: 1 });
    });

    await t.test('registration and a competing GP debit cannot both spend the same balance', async () => {
      const { id, bearer } = await player(25);
      const tournamentId = await fixture();
      const [registration, debit] = await Promise.all([post(bearer, tournamentId), gp.debit(intent(id, 25))]);
      assert.equal(registration.statusCode, 200);
      assert.ok(debit.status === 'completed');
      const registered = registration.json().data.status === 'accepted';
      assert.notEqual(registered, debit.outcome.status === 'accepted');
      assert.deepEqual(await state(id), { balance: 0, entries: Number(registered), operations: 1, fees: Number(registered) });
    });

    await t.test('registration rate limit follows the persisted player across IPs', async () => {
      const { id, bearer } = await player(5);
      const target = await fixture();
      const key = randomUUID();
      for (let index = 0; index < 12; index++) {
        assert.equal((await post(bearer, target, key)).statusCode, 200);
      }
      const limited = await post(bearer, target, key);
      assert.equal(limited.statusCode, 429);
      assert.equal(limited.json().error.code, 'rateLimited');
      assert.deepEqual(await state(id), { balance: 5, entries: 0, operations: 1, fees: 0 });
    });

    await t.test('HTTP registration waits for an exclusive closure and sees the committed status', async () => {
      const { id, bearer } = await player();
      const target = await fixture();
      const closure = await database.connect();
      let registrationPid: number | undefined;
      const waiting = appFor(enabled, async (connection, sql, values) => {
        if (sql.includes('pg_advisory_xact_lock_shared')) {
          registrationPid = (await connection.query('SELECT pg_backend_pid() AS pid')).rows[0]!.pid as number;
        }
        return connection.query(sql, values);
      });
      let pending: ReturnType<typeof post> | undefined;
      try {
        await closure.query('BEGIN');
        await closure.query("SELECT pg_advisory_xact_lock(hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))", [target]);
        await closure.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationClosed' WHERE id = $1", [target]);
        pending = post(bearer, target, randomUUID(), waiting);
        const deadline = Date.now() + 1500;
        let blocked = false;
        while (Date.now() < deadline && !blocked) {
          blocked = registrationPid !== undefined &&
            (await database.query('SELECT cardinality(pg_blocking_pids($1)) > 0 AS blocked', [registrationPid])).rows[0]!.blocked === true;
          if (!blocked) await setImmediate();
        }
        assert.equal(blocked, true);
        await closure.query('COMMIT');
        const response = await pending;
        assert.equal(response.json().data.rejectionCode, 'registrationClosed');
        assert.deepEqual(await state(id), { balance: 50, entries: 0, operations: 1, fees: 0 });
      } finally {
        await closure.query('ROLLBACK').catch(() => {});
        closure.release();
        await waiting.close();
        await pending;
      }
    });

    for (const stage of ['beforeCommit', 'commitNotSent', 'commitPersisted'] as const) {
      await t.test(`HTTP ${stage} exposes only a safe retry error and requires explicit recovery`, async () => {
        const { id, bearer } = await player();
        const target = await fixture();
        const key = randomUUID();
        let failures = 0;
        const uncertain = appFor(enabled, async (connection, sql, values) => {
          if (stage === 'beforeCommit' && sql.startsWith('INSERT INTO stoppy_knockout.registrations')
            || stage !== 'beforeCommit' && sql === 'COMMIT') {
            if (stage === 'commitPersisted') await connection.query(sql);
            failures++;
            throw new Error('sensitive SQL and credentials');
          }
          return connection.query(sql, values);
        });
        try {
          const failed = await post(bearer, target, key, uncertain);
          assert.equal(failed.statusCode, 503);
          assert.equal(failed.json().error.code, 'serverError');
          assert.equal(failed.json().error.details.reason, stage === 'beforeCommit' ? 'infrastructureFailure' : 'commitOutcomeUnknown');
          assert.ok(!failed.body.includes('sensitive') && !failed.body.includes(key) && !failed.body.includes(bearer));
          assert.equal(failures, 1);
          const retry = await post(bearer, target, key);
          assert.equal(retry.statusCode, 200, retry.body);
          assert.equal(retry.json().data.status, stage === 'commitPersisted' ? 'idempotentReplay' : 'accepted');
          assert.deepEqual(await state(id), { balance: 25, entries: 1, operations: 1, fees: 1 });
        } finally { await uncertain.close(); }
      });
    }

    await t.test('failure to read a committed receipt preserves one charge for explicit replay', async () => {
      const { id, bearer } = await player();
      const target = await fixture();
      const key = randomUUID();
      const brokenReceipt = appFor(enabled, undefined, async (sql, values) => {
        if (sql.includes('FROM stoppy_knockout.registrations r JOIN')) throw new Error('Sensitive read failure');
        return database.query(sql, values);
      });
      try {
        const failed = await post(bearer, target, key, brokenReceipt);
        assert.equal(failed.statusCode, 503);
        assert.equal(failed.json().error.details.reason, 'infrastructureFailure');
        assert.deepEqual(await state(id), { balance: 25, entries: 1, operations: 1, fees: 1 });
        assert.equal((await post(bearer, target, key)).json().data.status, 'idempotentReplay');
        assert.deepEqual(await state(id), { balance: 25, entries: 1, operations: 1, fees: 1 });
      } finally { await brokenReceipt.close(); }
    });
  } finally { await app.close(); }
}
