import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { TestContext } from 'node:test';
import { buildApp } from '../../src/app.js';
import { PostgresAuthRepository } from '../../src/auth/auth_repository.js';
import { TokenService } from '../../src/auth/token_service.js';
import type { Config } from '../../src/config.js';
import type { Database } from '../../src/database.js';
import { GpService } from '../../src/economy/gp_service.js';
import { KnockoutRegistrationService } from '../../src/knockout/knockout_registration_service.js';
import { KnockoutTournamentCatalog } from '../../src/knockout/knockout_tournament_catalog.js';

export async function testKnockoutReads(t: TestContext, database: Database, config: Config) {
  let now = '2024-06-30T22:59:59.999999Z';
  const app = buildApp(config, { ...database, close: async () => {}, query: (sql, values = []) => sql.startsWith('WITH read_clock')
    ? database.query(sql.replace('clock_timestamp()', `$${values.length + 1}::timestamptz`), [...values, now])
    : database.query(sql, values) });
  const tokens = new TokenService(config.auth);
  const auth = new PostgresAuthRepository(database);
  const player = async () => {
    const id = randomUUID();
    const sessionId = randomUUID();
    const createdAt = new Date();
    const expiresAt = new Date(createdAt.getTime() + 3600_000);
    const profile = await auth.register(id, 'Read' + id.replaceAll('-', '').slice(0, 20), '$argon2id$fixture-only',
      { id: sessionId, playerId: id, tokenId: randomUUID(), digest: randomUUID().replaceAll('-', '').repeat(2), createdAt, expiresAt });
    const token = await tokens.issue(id, sessionId, 'fixture', createdAt, expiresAt);
    return { profile, sessionId, authorization: 'Bearer ' + token.accessToken };
  };
  const get = (suffix: string, authorization: string) => app.inject({
    url: '/api/v1/knockout' + suffix, headers: { authorization },
  });
  const read = async (path: string, authorization: string) => {
    const response = await get(path, authorization);
    assert.equal(response.statusCode, 200, response.body);
    return response.json().data;
  };
  const tournament = async (month: string, status: string, opens: string, closes: string, starts: string) =>
    (await database.query(`INSERT INTO stoppy_knockout.tournaments
      (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
      VALUES ($1, 'Read fixture', $2, $3, $4, $5) RETURNING id`, [month, opens, closes, starts, status])).rows[0]!.id as string;
  const owner = await player();
  const other = await player();
  const discover = () => read('/tournament', owner.authorization);
  const scoped = (kind: string, id: string, authorization = owner.authorization) =>
    read(`/${kind}?tournamentId=${id}`, authorization);
  let upcoming: string;
  try {
    await t.test('empty catalog and future unavailable catalog metadata are distinct', async () => {
      assert.deepEqual(await discover(), { competition: null, registration: null });
      const future = await tournament('2024-09-01', 'unavailable', '2024-08-01T00:00:00Z', '2024-08-31T22:59:00Z', '2024-08-31T23:00:00Z');
      const { competition, registration } = await discover();
      assert.equal(competition, null);
      assert.equal(registration.id, future);
      assert.equal(registration.status, 'unavailable');
      assert.equal(registration.registrationWindowOpen, false);
      assert.equal(registration.tournamentMonth, '2024-09-01');
      assert.equal(registration.entries, undefined);
      assert.equal(registration.rounds, undefined);
      assert.equal(registration.gamePoints, undefined);
    });

    await t.test('Lisbon month rolls at summer midnight and current competition coexists with open registration', async () => {
      upcoming = await tournament('2024-08-01', 'registrationOpen', '2024-06-30T23:00:00Z', '2024-07-31T22:59:00Z', '2024-07-31T23:00:00Z');
      const beforeMidnight = now;
      now = '2024-06-30T23:00:00Z';
      const single = await discover();
      assert.equal(single.competition, null);
      assert.equal(single.registration.id, upcoming);
      assert.equal(single.registration.registrationWindowOpen, true);
      now = beforeMidnight;
      const june = await tournament('2024-06-01', 'completed', '2024-05-01T00:00:00Z', '2024-05-31T22:59:00Z', '2024-05-31T23:00:00Z');
      const july = await tournament('2024-07-01', 'completed', '2024-06-01T00:00:00Z', '2024-06-30T22:59:00Z', '2024-06-30T23:00:00Z');
      let selected = await discover();
      assert.equal(selected.competition.id, june);
      assert.equal(selected.registration.id, upcoming);
      assert.equal(selected.registration.status, 'registrationOpen');
      assert.equal(selected.registration.registrationWindowOpen, false);
      now = '2024-06-30T23:00:00Z';
      selected = await discover();
      assert.equal(selected.competition.id, july);
      assert.equal(selected.registration.id, upcoming);
      assert.equal(selected.registration.registrationWindowOpen, true);
      assert.equal((await scoped('tournament', june)).tournament.id, june);
      now = '2024-07-31T22:59:00Z';
      const atClose = (await scoped('tournament', upcoming)).tournament;
      assert.equal(atClose.status, 'registrationOpen');
      assert.equal(atClose.registrationWindowOpen, false);
      now = '2024-06-30T23:00:00Z';
    });

    await t.test('active competition has priority and tied open targets or active competitions fail closed', async () => {
      const active = await tournament('2024-05-01', 'inProgress', '2024-04-01T00:00:00Z', '2024-04-30T22:59:00Z', '2024-04-30T23:00:00Z');
      assert.equal((await discover()).competition.id, active);
      const overlapping = await tournament('2024-10-01', 'registrationOpen', '2024-06-30T23:00:00Z', '2024-08-15T00:00:00Z', '2024-09-30T23:00:00Z');
      const ambiguous = await get('/tournament', owner.authorization);
      assert.equal(ambiguous.statusCode, 409);
      assert.deepEqual(ambiguous.json().error.details, { reason: 'ambiguousTournamentSelection', slot: 'registration' });
      await database.query("UPDATE stoppy_knockout.tournaments SET status = 'unavailable' WHERE id = $1", [overlapping]);
      const second = await tournament('2024-04-01', 'inProgress', '2024-03-01T00:00:00Z', '2024-03-31T22:59:00Z', '2024-03-31T23:00:00Z');
      const ambiguousCompetition = await get('/tournament', owner.authorization);
      assert.equal(ambiguousCompetition.statusCode, 409);
      assert.equal(ambiguousCompetition.json().error.details.slot, 'competition');
      await database.query("UPDATE stoppy_knockout.tournaments SET status = 'completed' WHERE id = $1", [second]);
    });

    await t.test('scoped reads survive discovery rollover and reveal only confirmed self-registration', async () => {
      const id = owner.profile.id;
      await new GpService(database).credit({ playerId: id, amount: 25, operationName: 'read_fixture', operationVersion: 1,
        idempotencyKey: randomUUID(), reason: 'fixture', sourceType: 'read_fixture', sourceId: randomUUID(), context: {} });
      const registration = new KnockoutRegistrationService({ ...database, async connect() {
        const connection = await database.connect();
        return { release: (discard) => connection.release(discard), query: (sql, values) => sql.startsWith('WITH admission_clock')
          ? connection.query(sql.replace('clock_timestamp()', '$2::timestamptz'), [values![0], now])
          : connection.query(sql, values) };
      } });
      const result = await registration.register({ playerId: id, tournamentId: upcoming, idempotencyKey: randomUUID() });
      assert.ok(result.status === 'completed' && result.outcome.status === 'accepted');
      const balanceState = () => database.query(`SELECT p.game_points,
        (SELECT count(*) FROM stoppy_economy.gp_ledger WHERE player_id = p.id) AS movements,
        (SELECT count(*) FROM stoppy_knockout.registration_operations WHERE player_id = p.id) AS operations
        FROM stoppy_auth.players p WHERE id = $1`, [id]);
      const before = await balanceState();
      const own = await scoped('entry', upcoming);
      assert.equal(own.playerId, id);
      assert.equal(own.tournamentId, upcoming);
      assert.equal(own.playerEntry.registeredAt, '2024-06-30T23:00:00.000000Z');
      assert.equal(own.playerEntry.entryCostGamePoints, 25);
      assert.equal((await scoped('entry', upcoming, other.authorization)).playerEntry, null);
      assert.equal((await scoped('status', upcoming, other.authorization)).state, 'notRegistered');
      assert.equal((await scoped('status', upcoming)).state, 'registeredWaitingStart');

      const next = await tournament('2024-11-01', 'registrationOpen', '2024-07-15T00:00:00Z', '2024-10-31T23:59:00Z', '2024-11-01T00:00:00Z');
      await new KnockoutTournamentCatalog(database).transition(upcoming, 'registrationClosed');
      const closed = await scoped('status', upcoming);
      assert.equal(closed.tournamentStatus, 'registrationClosed');
      assert.equal(closed.registrationWindowOpen, false);
      assert.equal((await discover()).registration.id, upcoming);
      now = '2024-07-31T23:00:00Z';
      assert.equal((await discover()).registration.id, next);
      assert.deepEqual(await scoped('entry', upcoming), own);
      const historical = await scoped('status', upcoming);
      assert.equal(historical.tournamentId, upcoming);
      assert.equal(historical.state, 'registeredCompetitionUnavailable');
      assert.equal(historical.duelSnapshot, undefined);
      assert.deepEqual(await balanceState(), before);
    });

    await t.test('unknown targets, unsupported projections and revoked sessions are explicit', async () => {
      for (const kind of ['tournament', 'entry', 'status', 'active-duel']) {
        const missing = await get(`/${kind}?tournamentId=${randomUUID()}`, owner.authorization);
        assert.equal(missing.statusCode, 404);
      }
      for (const path of [`/active-duel?tournamentId=${upcoming}`, '/records', '/history', '/hall-of-fame']) {
        const response = await get(path, owner.authorization);
        assert.equal(response.statusCode, 501);
        assert.equal(response.json().error.code, 'notImplemented');
        assert.equal(response.json().error.details.reason, 'competitiveProjectionUnavailable');
      }
      await database.query('UPDATE stoppy_auth.auth_sessions SET revoked_at = clock_timestamp() WHERE id = $1', [other.sessionId]);
      assert.equal((await get(`/entry?tournamentId=${upcoming}`, other.authorization)).statusCode, 401);
      assert.equal((await get('/tournament', other.authorization)).statusCode, 401);
      assert.equal((await get(`/status?tournamentId=${upcoming}&playerId=${owner.profile.id}`, owner.authorization)).statusCode, 400);
    });
  } finally { await app.close(); }
}
