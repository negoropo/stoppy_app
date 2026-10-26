import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, generateKeyPairSync } from 'node:crypto';
import { SignJWT, decodeJwt } from 'jose';
import { credentials, refreshCredential } from '../src/auth/auth_validation.js';
import { ArgonPasswordHasher } from '../src/auth/password_hasher.js';
import { TokenService, tokenDigest, newRefreshToken } from '../src/auth/token_service.js';
import { AuthRateLimiter } from '../src/auth/auth_rate_limiter.js';
import { loadAuthConfig } from '../src/auth/auth_config.js';
import { ApiError } from '../src/api_error.js';
import { testConfig } from './fakes.js';

const now = new Date('2026-10-26T12:00:00.000Z');
const expiry = new Date(now.getTime() + 30 * 86400000);
const auth = testConfig.auth;
const tokens = new TokenService(auth);
const playerId = randomUUID();
const sessionId = randomUUID();
const unauthorized = (error: unknown): boolean => error instanceof ApiError && error.code === 'unauthenticated' && error.statusCode === 401;

test('username policy trims and folds ASCII without changing display case or password', () => {
  assert.deepEqual(credentials({ username: '  Alice_One .-9  ', password: ' pass ' }), {
    username: 'Alice_One .-9', canonicalUsername: 'alice_one .-9', password: ' pass ',
  });
  assert.equal(credentials({ username: 'a'.repeat(32), password: 'a'.repeat(128) }).username.length, 32);
});

test('credential validation rejects malformed, excessive and unsupported input without echoing it', () => {
  for (const body of [null, [], 'secret', {}, { username: 12, password: 'pass' },
    { username: 'Alice', password: 'abc' }, { username: 'Alice', password: 'a'.repeat(129) },
    { username: ' ', password: 'pass' }, { username: 'a'.repeat(33), password: 'pass' },
    { username: 'Álice', password: 'pass' }, { username: 'a\nb', password: 'pass' },
    { username: 'Alice', password: 'pass', playerId }, { username: 'Alice', password: null }]) {
    assert.throws(() => credentials(body), (error: unknown) => error instanceof ApiError && error.code === 'validationFailed');
  }
});

test('registration rejects whitespace-only passwords while login has no registration minimum', () => {
  for (const password of ['    ', '\t\n  ', '\u00a0'.repeat(4)]) {
    for (const registration of [true, false]) {
      assert.throws(() => credentials({ username: 'Alice', password }, registration),
        (error: unknown) => error instanceof ApiError && error.code === 'validationFailed' && error.statusCode === 400);
    }
  }
  for (const password of ['a', 'ab', 'abc']) {
    assert.throws(() => credentials({ username: 'Alice', password }), ApiError);
    assert.equal(credentials({ username: 'Alice', password }, false).password, password);
  }
  for (const password of [' pass ', '  ab', 'ab  ']) {
    assert.equal(credentials({ username: 'Alice', password }).password, password);
    assert.equal(credentials({ username: 'Alice', password }, false).password, password);
  }
  assert.throws(() => credentials({ username: 'Alice', password: 'a'.repeat(129) }, false), ApiError);
});

test('Dart whitespace-only passwords including NEXT LINE are rejected with compatible errors', () => {
  // Mirror the installed Dart VM whitespace set, rather than JS trim semantics.
  const whitespace = [0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x20, 0x85, 0xa0, 0x1680,
    ...Array.from({ length: 11 }, (_, index) => 0x2000 + index),
    0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff].map((code) => String.fromCharCode(code));
  const passwords = ['\u0085'.repeat(4), ' \u0085\t\u00a0', whitespace.join(''), ...whitespace.map((value) => value.repeat(4))];
  for (const password of passwords) {
    for (const registration of [true, false]) {
      assert.throws(() => credentials({ username: 'Alice', password }, registration),
        (error: unknown) => error instanceof ApiError && error.code === 'validationFailed' && error.statusCode === 400);
    }
  }
});

test('meaningful passwords surrounded by NEXT LINE or other whitespace remain exact', () => {
  for (const password of ['\u0085pass\u0085', ' \u0085pass\t ', '\u0085a\u0085a', '\u200b'.repeat(4)]) {
    for (const registration of [true, false]) {
      const result = credentials({ username: 'Alice', password }, registration);
      assert.equal(result.password, password);
      assert.deepEqual(Buffer.from(result.password), Buffer.from(password));
    }
  }
});

test('NEXT LINE compatibility preserves registration and login UTF-16 length bounds', () => {
  assert.throws(() => credentials({ username: 'Alice', password: '\u0085a\u0085' }), ApiError);
  assert.equal(credentials({ username: 'Alice', password: '\u0085a\u0085' }, false).password, '\u0085a\u0085');
  for (const password of ['\u0085ab\u0085', '\u0085' + 'a'.repeat(126) + '\u0085']) {
    assert.equal(credentials({ username: 'Alice', password }).password, password);
  }
  for (const registration of [true, false]) {
    assert.throws(() => credentials({ username: 'Alice', password: '\u0085' + 'a'.repeat(127) + '\u0085' }, registration),
      (error: unknown) => error instanceof ApiError && error.code === 'validationFailed');
  }
});

test('Argon2id hashes are salted and verify exact untrimmed passwords', async () => {
  const passwords = new ArgonPasswordHasher();
  const first = await passwords.hash(' pass ');
  const second = await passwords.hash(' pass ');
  assert.match(first, /^\$argon2id\$v=19\$/);
  assert.deepEqual(new Set(first.split('$')[3]!.split(',')), new Set(['m=19456', 't=2', 'p=1']));
  assert.notEqual(first, second);
  assert.equal(await passwords.verify(first, ' pass '), true);
  assert.equal(await passwords.verify(first, 'pass'), false);
  assert.equal(await passwords.verify(null, 'pass'), false);
});

test('hashing overload is rejected without an unbounded queue', async () => {
  const passwords = new ArgonPasswordHasher();
  const active = [passwords.hash('pass'), passwords.hash('pass')];
  await assert.rejects(passwords.hash('pass'), (error: unknown) => error instanceof ApiError && error.code === 'rateLimited');
  await Promise.all(active);
});

test('JWT issuance matches Flutter session contract and authenticates server identifiers', async () => {
  const token = newRefreshToken();
  const session = await tokens.issue(playerId, sessionId, token, now, expiry);
  assert.deepEqual(Object.keys(session).sort(), ['accessToken', 'expiresAt', 'refreshToken']);
  assert.equal(session.expiresAt, '2026-10-27T12:00:00.000Z');
  assert.deepEqual(await tokens.verify('Bearer ' + session.accessToken, now), { playerId, sessionId });
  assert.equal(decodeJwt(session.accessToken).exp, new Date(session.expiresAt).getTime() / 1000);
});

test('JWT lifetime cannot exceed the persisted session family lifetime', async () => {
  const session = await tokens.issue(playerId, sessionId, newRefreshToken(), now, new Date(now.getTime() + 10000));
  assert.equal(session.expiresAt, '2026-10-26T12:00:10.000Z');
  await assert.rejects(tokens.verify('Bearer ' + session.accessToken, new Date(session.expiresAt)), unauthorized);
});

test('JWT rejects missing, malformed and tampered bearer credentials', async () => {
  const session = await tokens.issue(playerId, sessionId, newRefreshToken(), now, expiry);
  const parts = session.accessToken.split('.');
  parts[1] = Buffer.from(JSON.stringify({ sub: randomUUID() })).toString('base64url');
  for (const header of [undefined, '', 'Basic abc', 'Bearer a b', 'Bearer ' + parts.join('.'), 'Bearer ' + 'a'.repeat(5000)]) {
    await assert.rejects(tokens.verify(header, now), unauthorized);
  }
});

test('JWT rejects incorrect algorithm, signing key, issuer, audience, dates and identifiers', async () => {
  const claims = { sub: playerId, sid: sessionId, jti: randomUUID(), iss: auth.issuer, aud: auth.audience,
    iat: now.getTime() / 1000, exp: now.getTime() / 1000 + 100 };
  const differentKey = generateKeyPairSync('ed25519').privateKey;
  for (const overrides of [{ iss: 'other' }, { aud: 'other' }, { sub: 'not-uuid' }, { sid: 'not-uuid' },
    { jti: 'not-uuid' }, { exp: claims.iat }, { exp: claims.iat - 1 }, { iat: claims.iat + 10 },
    { exp: claims.iat + auth.accessSeconds + 1 }, { sid: undefined }, { exp: undefined }, { iat: 1.5 }]) {
    const payload = JSON.parse(JSON.stringify({ ...claims, ...overrides }));
    const jwt = await new SignJWT(payload).setProtectedHeader({ alg: 'EdDSA', typ: 'JWT' }).sign(auth.privateKey);
    await assert.rejects(tokens.verify('Bearer ' + jwt, now), unauthorized);
  }
  const wrongKey = await new SignJWT(claims).setProtectedHeader({ alg: 'EdDSA', typ: 'JWT' }).sign(differentKey);
  await assert.rejects(tokens.verify('Bearer ' + wrongKey, now), unauthorized);
  const wrongAlgorithm = await new SignJWT(claims).setProtectedHeader({ alg: 'HS256', typ: 'JWT' }).sign(new Uint8Array(32));
  await assert.rejects(tokens.verify('Bearer ' + wrongAlgorithm, now), unauthorized);
});

test('refresh credentials have high entropy and only their digest is persisted', () => {
  const first = newRefreshToken();
  assert.notEqual(first, newRefreshToken());
  assert.equal(refreshCredential({ refreshToken: first }), first);
  assert.match(tokenDigest(first), /^[0-9a-f]{64}$/);
  for (const value of ['', 'x', first + ' ', ' '+first, null, 1, 'x'.repeat(10000)]) {
    assert.throws(() => refreshCredential({ refreshToken: value }), unauthorized);
  }
});

test('rate limiter has a deterministic window and bounded capacity without live-bucket eviction', () => {
  let time = 1000;
  const limiter = new AuthRateLimiter(() => time, 2);
  limiter.checkIp('first');
  limiter.checkIp('second');
  assert.throws(() => limiter.checkIp('third'), (e: unknown) => e instanceof ApiError && e.code === 'rateLimited');
  for (let i = 1; i < 30; i++) limiter.checkIp('first');
  assert.throws(() => limiter.checkIp('first'), ApiError);
  time += 60000;
  assert.doesNotThrow(() => limiter.checkIp('third'));
});

test('account rate limiting folds display case across IPs', () => {
  const limiter = new AuthRateLimiter(() => 0);
  for (let i = 0; i < 10; i++) limiter.checkAccount({ username: i % 2 ? 'Alice' : ' ALICE ' });
  assert.throws(() => limiter.checkAccount({ username: 'alice' }), ApiError);
  assert.throws(() => limiter.checkAccount({ username: ' '.repeat(300) + 'ALICE ' }), ApiError);
});

test('auth configuration has approved defaults and safe production requirements', () => {
  assert.equal(auth.accessSeconds, 86400);
  assert.equal(auth.refreshSeconds, 30 * 86400);
  const key = auth.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const wrongType = generateKeyPairSync('rsa', { modulusLength: 1024 }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  assert.equal(loadAuthConfig({ AUTH_PRIVATE_KEY: key, AUTH_ISSUER: 'stoppy', AUTH_AUDIENCE: 'app' }, true).issuer, 'stoppy');
  for (const env of [{}, { AUTH_PRIVATE_KEY: 'secret' }, { AUTH_PRIVATE_KEY: wrongType }, { AUTH_PRIVATE_KEY: key },
    { AUTH_PRIVATE_KEY: key, AUTH_ISSUER: 'stoppy', AUTH_AUDIENCE: 'app', AUTH_ACCESS_SECONDS: '0' },
    { AUTH_PRIVATE_KEY: key, AUTH_ISSUER: 'stoppy', AUTH_AUDIENCE: 'app', AUTH_REFRESH_SECONDS: '86400' },
    { AUTH_PRIVATE_KEY: key, AUTH_ISSUER: 'stoppy', AUTH_AUDIENCE: 'app', AUTH_ACCESS_SECONDS: '1e4' }]) {
    assert.throws(() => loadAuthConfig(env, true), (error: unknown) => error instanceof Error && !error.message.includes(key));
  }
});
