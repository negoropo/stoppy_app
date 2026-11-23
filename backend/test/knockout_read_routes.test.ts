import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { buildApp } from '../src/app.js';
import { FakeDatabase, testConfig } from './fakes.js';

const prefix = '/api/v1/knockout';

test('Knockout reads reject missing, malformed, duplicate or spoofed scope before accessing PostgreSQL', async () => {
  const database = new FakeDatabase();
  const app = buildApp(testConfig, database);
  const target = randomUUID();
  try {
    for (const path of [
      '/entry', '/status', '/active-duel',
      '/tournament?tournamentId=2026-06',
      '/entry?tournamentId=' + target.toUpperCase(),
      `/status?tournamentId=${target}&tournamentId=${target}`,
      `/entry?tournamentId=${target}&playerId=${randomUUID()}`,
      '/records?playerId=' + target,
    ]) {
      const response = await app.inject(prefix + path);
      assert.equal(response.statusCode, 400, path);
      assert.equal(response.json().error.code, 'validationFailed');
    }
    for (const path of ['/tournament', `/tournament?tournamentId=${target}`,
      `/entry?tournamentId=${target}`, '/history', '/hall-of-fame']) {
      assert.equal((await app.inject(prefix + path)).statusCode, 401, path);
    }
    assert.equal((await app.inject({ method: 'POST', url: prefix + '/register' })).statusCode, 404);
    assert.equal(database.calls.length, 0);
    assert.equal(database.connections, 0);
  } finally { await app.close(); }
});
