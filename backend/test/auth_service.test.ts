import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { AuthService } from '../src/auth/auth_service.js';
import type { AuthRepository, NewSession, PlayerProfile } from '../src/auth/auth_repository.js';
import type { PasswordHasher } from '../src/auth/password_hasher.js';
import { TokenService, newRefreshToken } from '../src/auth/token_service.js';
import { buildApp } from '../src/app.js';
import { ApiError } from '../src/api_error.js';
import { FakeDatabase, testConfig } from './fakes.js';

const now = new Date('2026-10-26T12:00:00Z');
const profile: PlayerProfile = { id: randomUUID(), username: 'Alice', createdAt: now.toISOString(), gamePoints: 5,
  adsRemoved: false, lastDailyGpAwardedAt: null, currentLeagueDivision: null, hasWeeklyLeagueEntry: false, reservedLeagueSlot: false };

function fixture() {
  const writes: NewSession[] = [];
  const verified: (string | null)[] = [];
  const passwords: PasswordHasher = { hash: async () => '$argon2id$test-only', verify: async (hash, password) => {
    verified.push(hash); return hash !== null && password === ' pass ';
  } };
  const repository: AuthRepository = {
    register: async (id, username, _hash, session) => { writes.push(session); return { ...profile, id, username }; },
    findCredentials: async (username) => username === 'alice' ? { profile, passwordHash: '$argon2id$test-only' } : null,
    createSession: async (session) => { writes.push(session); },
    rotate: async (_digest, _id, _replacement, issue) => issue(profile.id, randomUUID(), now, new Date(now.getTime() + 86400000)),
    authenticatedProfile: async (id) => id === profile.id ? profile : null,
  };
  const tokens = new TokenService(testConfig.auth);
  const service = new AuthService(testConfig.auth, repository, passwords, tokens, () => now);
  return { repository, service, writes, verified, tokens };
}

test('register hashes password, uses server UUIDs and commits persistence before returning credentials', async () => {
  const { service, repository, writes } = fixture();
  const result = await service.register({ username: ' NewPlayer ', password: ' pass ' });
  assert.equal(result.playerProfile.username, 'NewPlayer');
  assert.equal(result.playerProfile.gamePoints, 5);
  assert.equal(writes.length, 1);
  assert.notEqual(writes[0]!.digest, result.session.refreshToken);
  assert.equal(writes[0]!.playerId, result.playerProfile.id);
  repository.register = async () => { throw new Error('uncertain commit'); };
  await assert.rejects(service.register({ username: 'NewPlayer', password: 'pass' }));
});

test('unknown user and incorrect password use the same generic authentication failure', async () => {
  const { service, verified } = fixture();
  for (const body of [{ username: 'unknown', password: ' pass ' }, { username: 'Alice', password: 'wrong' }]) {
    await assert.rejects(service.login(body), (error: unknown) => error instanceof ApiError &&
      error.code === 'unauthenticated' && error.message === 'Invalid authentication credentials.');
  }
  assert.deepEqual(verified, [null, '$argon2id$test-only']);
});

test('short login passwords reach credential verification rather than registration-only validation', async () => {
  const { service, verified } = fixture();
  await assert.rejects(service.login({ username: 'Alice', password: 'abc' }),
    (error: unknown) => error instanceof ApiError && error.code === 'unauthenticated' && error.statusCode === 401);
  assert.deepEqual(verified, ['$argon2id$test-only']);
});

test('HTTP registration rejects blank passwords without writes and preserves surrounding spaces', async () => {
  const { service, writes } = fixture();
  const app = buildApp(testConfig, new FakeDatabase(), { auth: service });
  try {
    const blank = await app.inject({ method: 'POST', url: '/api/v1/auth/register', payload: { username: 'Alice', password: '    ' } });
    assert.equal(blank.statusCode, 400);
    assert.equal(blank.json().error.code, 'validationFailed');
    assert.equal(writes.length, 0);
    const valid = await app.inject({ method: 'POST', url: '/api/v1/auth/register', payload: { username: 'Alice', password: ' pass ' } });
    assert.equal(valid.statusCode, 200);
    const exact = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'Alice', password: ' pass ' } });
    assert.equal(exact.statusCode, 200);
    const trimmed = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'Alice', password: 'pass' } });
    assert.equal(trimmed.statusCode, 401);
  } finally { await app.close(); }
});

test('login canonicalizes username and never returns a session before storage succeeds', async () => {
  const { service, repository, writes } = fixture();
  const result = await service.login({ username: ' ALICE ', password: ' pass ' });
  assert.equal(result.playerProfile.id, profile.id);
  assert.equal(writes.length, 1);
  repository.createSession = async () => { throw new Error('commit failed'); };
  await assert.rejects(service.login({ username: 'Alice', password: ' pass ' }));
});

test('refresh returns only the session DTO and does not disclose rejected token reasons', async () => {
  const { service, repository } = fixture();
  assert.deepEqual(Object.keys(await service.refresh({ refreshToken: newRefreshToken() })), ['session']);
  repository.rotate = async () => null;
  await assert.rejects(service.refresh({ refreshToken: newRefreshToken() }), (e: unknown) => e instanceof ApiError && e.code === 'unauthenticated');
});

test('profile requires the persisted non-revoked session as well as a valid JWT', async () => {
  const { service, repository, tokens } = fixture();
  const session = await tokens.issue(profile.id, randomUUID(), newRefreshToken(), now, new Date(now.getTime() + 86400000));
  assert.deepEqual(await service.profile('Bearer ' + session.accessToken), profile);
  repository.authenticatedProfile = async () => null;
  await assert.rejects(service.profile('Bearer ' + session.accessToken), ApiError);
});

test('HTTP authentication uses the exact Flutter envelopes and leaves logout/competitive paths disconnected', async () => {
  const { service } = fixture();
  const app = buildApp(testConfig, new FakeDatabase(), { auth: service });
  try {
    const register = await app.inject({ method: 'POST', url: '/api/v1/auth/register', payload: { username: 'Alice', password: ' pass ' } });
    assert.equal(register.statusCode, 200);
    assert.equal(register.json().success, true);
    assert.deepEqual(Object.keys(register.json().data).sort(), ['playerProfile', 'session']);
    const login = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'Alice', password: ' pass ' } });
    const response = await app.inject({ url: '/api/v1/player/profile?playerId=forged', headers: { authorization: 'Bearer ' + login.json().data.session.accessToken } });
    assert.deepEqual(response.json(), { success: true, data: profile });
    const refresh = await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refreshToken: newRefreshToken() } });
    assert.equal(refresh.statusCode, 200);
    assert.deepEqual(Object.keys(refresh.json().data), ['session']);
    for (const url of ['/api/v1/auth/logout', '/api/v1/league/enter', '/api/v1/knockout/register', '/api/v1/runs/league']) {
      assert.equal((await app.inject({ method: 'POST', url })).statusCode, 404);
    }
  } finally { await app.close(); }
});

test('HTTP validates malformed input and rate limits excessive attempts', async () => {
  const { service } = fixture();
  const app = buildApp(testConfig, new FakeDatabase(), { auth: service });
  try {
    const wrong = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'Alice', password: 'wrong' } });
    assert.equal(wrong.statusCode, 401);
    for (const payload of [{ username: 'Alice', password: 1234 }, { username: 'Alice', password: 'pass', id: 'forged' }, ['Alice', 'pass']]) {
      const response = await app.inject({ method: 'POST', url: '/api/v1/auth/register', payload });
      assert.equal(response.statusCode, 400);
      assert.equal(response.json().error.code, 'validationFailed');
    }
    for (let i = 0; i < 40; i++) {
      await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: 'Alice', password: 'wrong' } });
    }
    const limited = await app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refreshToken: newRefreshToken() } });
    assert.equal(limited.statusCode, 429);
    assert.equal(limited.json().error.code, 'rateLimited');
    assert.equal((await app.inject('/api/v1/health')).statusCode, 200);
  } finally { await app.close(); }
});

test('authentication database failures return safe errors without issuing credentials', async () => {
  const { service, repository } = fixture();
  repository.register = async () => { throw new Error('SQL password=SECRET_DATABASE refreshToken=SECRET_REFRESH'); };
  const app = buildApp(testConfig, new FakeDatabase(), { auth: service });
  try {
    const response = await app.inject({ method: 'POST', url: '/api/v1/auth/register',
      payload: { username: 'Alice', password: 'SECRET_PASSWORD' } });
    assert.equal(response.statusCode, 500);
    assert.deepEqual(response.json(), { success: false, error: { code: 'serverError', message: 'Internal server error.' } });
    assert.doesNotMatch(response.body, /SECRET|accessToken|refreshToken|password_hash/);
  } finally { await app.close(); }
});

test('logs never include authentication material, query credentials or raw internal errors', () => {
  // A child process captures real Pino output without mutating shared stdout in concurrent tests.
  const script = `
    import { buildApp } from './src/app.ts';
    import { testConfig, FakeDatabase } from './test/fakes.ts';
    const app = buildApp({...testConfig, logLevel: 'info'}, new FakeDatabase());
    app.post('/probe', async () => { throw new Error('SECRET_SQL_PASSWORD'); });
    await app.inject({method:'POST',url:'/probe?token=SECRET_QUERY',headers:{authorization:'Bearer SECRET_BEARER'},payload:{password:'SECRET_BODY',refreshToken:'SECRET_REFRESH'}});
    await app.close();
  `;
  const result = spawnSync(process.execPath, ['--import', 'tsx', '--input-type=module', '-e', script], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Request failed/);
  assert.doesNotMatch(result.stdout + result.stderr, /SECRET_/);
});
