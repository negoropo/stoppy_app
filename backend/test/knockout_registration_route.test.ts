import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { Server } from 'node:net';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { startApplication } from '../src/lifecycle.js';
import { FakeDatabase, testConfig } from './fakes.js';

const path = '/api/v1/knockout/register';
const enabled = loadConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent',
  DATABASE_URL: testConfig.databaseUrl, KNOCKOUT_REGISTRATION_HTTP: 'enabled' });
const headers = { authorization: 'Bearer x', 'idempotency-key': 'valid-key', 'content-type': 'application/json' };
const tournamentId = randomUUID();
const payload = { tournamentId };

test('Knockout POST is absent by default and enabled config cannot start a listener', async () => {
  const database = new FakeDatabase();
  const app = buildApp(testConfig, database);
  try {
    assert.equal((await app.inject({ method: 'POST', url: path, headers, payload })).statusCode, 404);
    assert.equal(database.calls.length, 0);
    assert.equal(database.connections, 0);
  } finally { await app.close(); }
  const isolated = new FakeDatabase();
  await assert.rejects(startApplication(enabled, isolated, async () => assert.fail('Unexpected listener')), /test injection/);
  assert.equal(isolated.calls.length, 0);
  assert.equal(isolated.closed, 1);
});

test('the paid-route instance refuses binding in both listen overloads and still supports injection', async (t) => {
  const database = new FakeDatabase();
  const app = buildApp(enabled, database);
  // Intercept the underlying Node binder to guarantee no socket opens even
  // if the instance guard regresses. An intercepted call still fails the test.
  const bind = t.mock.method(Server.prototype, 'listen', function (this: Server) {
    queueMicrotask(() => this.emit('error', new Error('Unexpected socket bind')));
    return this;
  });
  const injectRegistration = () => app.inject({ method: 'POST', url: path, headers, payload });
  const refused = /only through test injection/;
  try {
    assert.equal((await injectRegistration()).json().error.code, 'unauthenticated');
    const errorListeners = app.server.listenerCount('error');
    const listeningListeners = app.server.listenerCount('listening');

    await assert.rejects(app.listen(), refused);
    await Promise.all([
      assert.rejects(app.listen({ host: '0.0.0.0', port: 0 }), refused),
      assert.rejects(app.listen({ host: '127.0.0.1', port: 0, backlog: 1 }), refused),
      assert.rejects(new Promise((resolve, reject) => {
        app.listen({ path: '/tmp/stoppy-injection-only-probe.sock' }, (error, address) => {
          if (error) reject(error);
          else resolve(address);
        });
      }), refused),
    ]);

    assert.equal(bind.mock.callCount(), 0);
    assert.equal(app.server.listening, false);
    assert.equal(app.server.address(), null);
    assert.equal(app.server.listenerCount('error'), errorListeners);
    assert.equal(app.server.listenerCount('listening'), listeningListeners);
    const response = await injectRegistration();
    assert.equal(response.statusCode, 401);
    assert.equal(response.json().error.code, 'unauthenticated');
    assert.equal(database.connections, 0);
  } finally { await app.close(); }
  assert.equal(database.closed, 1);
});

test('Knockout POST rejects ambiguous or malformed requests before database access', async () => {
  const database = new FakeDatabase();
  const app = buildApp(enabled, database);
  try {
    const invalid = [
      { payload: {} },
      { payload: { tournamentId: tournamentId.toUpperCase() } },
      { payload: { tournamentId: '2026-06' } },
      { payload: { tournamentId, playerId: randomUUID() } },
      { payload: `{"tournamentId":"${tournamentId}","tournamentId":"${randomUUID()}"}` },
      { payload: '{"tournamentId":' },
      { url: path + '?playerId=' + randomUUID() },
      { url: path + '?tournamentId=' + randomUUID() },
      { headers: { ...headers, 'idempotency-key': '' } },
      { headers: { ...headers, 'idempotency-key': 'a,b' } },
      { headers: { ...headers, 'idempotency-key': 'x'.repeat(129) } },
      { headers: { ...headers, 'idempotency-key': ['one', 'one'] } },
      { headers: { ...headers, 'idempotency-key': ['one', 'two'] } },
    ];
    for (const variation of invalid) {
      const response = await app.inject({ method: 'POST', url: path, headers, payload, ...variation });
      assert.equal(response.statusCode, 400, response.body);
      assert.equal(response.json().error.code, 'validationFailed');
    }
    for (const [type, body, status] of [
      ['text/plain', JSON.stringify(payload), 415],
      ['application/json; charset=latin1', JSON.stringify(payload), 415],
      ['application/json', JSON.stringify({ tournamentId: 'x'.repeat(17000) }), 413],
    ] as const) {
      const response = await app.inject({ method: 'POST', url: path, headers: { ...headers, 'content-type': type }, payload: body });
      assert.equal(response.statusCode, status);
    }
    for (const authorization of ['', 'Bearer invalid', ['Bearer one', 'Bearer two']]) {
      // Node exposes Authorization as a singleton, but injection can model
      // multiple raw fields to exercise the route's wire-level check.
      const response = await app.inject({ method: 'POST', url: path,
        headers: { ...headers, authorization: authorization as string }, payload });
      assert.equal(response.statusCode, 401);
      assert.equal(response.json().error.code, 'unauthenticated');
    }
    assert.equal(database.calls.length, 0);
    assert.equal(database.connections, 0);
  } finally { await app.close(); }
});

test('Knockout POST limits requests independently of auth and health', async () => {
  const app = buildApp(enabled, new FakeDatabase());
  try {
    for (let index = 0; index < 30; index++) {
      assert.equal((await app.inject({ method: 'POST', url: path, headers, payload })).statusCode, 401);
    }
    const limited = await app.inject({ method: 'POST', url: path, headers, payload });
    assert.equal(limited.statusCode, 429);
    assert.equal(limited.json().error.code, 'rateLimited');
    assert.equal((await app.inject('/api/v1/player/profile')).statusCode, 401);
    assert.equal((await app.inject('/api/v1/health')).statusCode, 200);
  } finally { await app.close(); }
});

test('Knockout POST logs no bearer, idempotency key, request target or raw failure', () => {
  const script = `
    import { buildApp } from './src/app.ts';
    import { loadConfig } from './src/config.ts';
    import { TokenService } from './src/auth/token_service.ts';
    import { FakeDatabase } from './test/fakes.ts';
    const config = loadConfig({ NODE_ENV:'test', DATABASE_URL:'postgresql://localhost/stoppy_test',
      KNOCKOUT_REGISTRATION_HTTP:'enabled' });
    const id = 'a0ef0fe0-a6e0-4d62-9909-6455aace413f';
    const target = 'dab4cf52-dac2-42f5-b0d0-6ed2191b919a';
    const token = await new TokenService(config.auth).issue(id, id, 'fixture', new Date(), new Date(Date.now()+60000));
    const database = new FakeDatabase();
    database.query = async () => { throw new Error('SECRET_SQL_CREDENTIAL'); };
    const app = buildApp(config, database);
    const response = await app.inject({ method:'POST', url:'/api/v1/knockout/register',
      headers:{'content-type':'application/json', authorization:'Bearer '+token.accessToken,
        'idempotency-key':'SECRET_IDEMPOTENCY_KEY'}, payload:{tournamentId:target} });
    if (response.statusCode !== 503) throw new Error('Expected a sanitized infrastructure failure');
    if (response.body.includes(token.accessToken) || response.body.includes('SECRET_')) throw new Error('Unsafe error');
    await app.close();
  `;
  const result = spawnSync(process.execPath, ['--import', 'tsx', '--input-type=module', '-e', script], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /knockout\/register/);
  assert.doesNotMatch(result.stdout + result.stderr, /SECRET_|eyJ|dab4cf52|a0ef0fe0/);
});
