import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.js';
import { generateKeyPairSync } from 'node:crypto';

const valid = { DATABASE_URL: 'postgresql://user:secret@localhost/stoppy' };
const productionAuth = { AUTH_ISSUER: 'stoppy-test', AUTH_AUDIENCE: 'stoppy-test-app',
  AUTH_PRIVATE_KEY: generateKeyPairSync('ed25519').privateKey.export({ type: 'pkcs8', format: 'pem' }).toString() };

test('configuration applies explicit development defaults and is immutable', () => {
  const config = loadConfig(valid);
  assert.equal(config.host, '127.0.0.1');
  assert.equal(config.port, 3000);
  assert.equal(config.databaseSsl, 'disable');
  assert.ok(Object.isFrozen(config));
});

test('configuration rejects malformed inputs without echoing credentials', () => {
  for (const overrides of [
    { DATABASE_URL: undefined }, { DATABASE_URL: 'https://user:secret@host/db' },
    { DATABASE_URL: 'postgresql://host/' }, { DATABASE_URL: valid.DATABASE_URL + '?sslmode=no-verify' },
    { PORT: '0' }, { PORT: '65536' }, { PORT: '3.5' }, { PORT: '3e3' },
    { HOST: ' ' }, { NODE_ENV: 'staging' }, { DATABASE_SSL: 'no-verify' }, { LOG_LEVEL: 'invalid' },
    { NODE_ENV: 'production' },
  ]) {
    assert.throws(() => loadConfig({ ...valid, ...overrides }), (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.ok(!error.message.includes('secret'));
      return true;
    });
  }
});

test('production requires certificate-verified database TLS', () => {
  const config = loadConfig({ ...valid, ...productionAuth, NODE_ENV: 'production', DATABASE_SSL: 'verify-full' });
  assert.equal(config.databaseSsl, 'verify-full');
});

test('production rejects encoded and alternate URL TLS overrides without leaking credentials', () => {
  for (const query of ['sslmode=disable', 'ssl=no-verify', 'sslrootcert=/tmp/ca',
    'sslcert=/tmp/cert', 'sslkey=/tmp/key', '%73slmode=disable', 'SSLmode=disable',
    'sslnegotiation=direct']) {
    assert.throws(() => loadConfig({
      NODE_ENV: 'production', DATABASE_SSL: 'verify-full',
      DATABASE_URL: valid.DATABASE_URL + '?' + query,
    }), (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.ok(!error.message.includes('secret'));
      assert.ok(!error.message.includes(query));
      return true;
    });
  }
});
