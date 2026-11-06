import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { buildApp } from '../../src/app.js';
import { loadConfig } from '../../src/config.js';
import { checkDatabase, createDatabase } from '../../src/database.js';
import { readMigrations, runMigrations } from '../../src/migrations.js';
import { PostgresAuthRepository } from '../../src/auth/auth_repository.js';
import { AuthService } from '../../src/auth/auth_service.js';
import { ArgonPasswordHasher } from '../../src/auth/password_hasher.js';
import { TokenService, tokenDigest, newRefreshToken } from '../../src/auth/token_service.js';
import { randomUUID } from 'node:crypto';
import type { ApiError } from '../../src/api_error.js';
import { spawnSync } from 'node:child_process';
import { prepareGpBackfill, readAuthState, testGpSchema } from './gp_schema_cases.js';
import { testGpService } from './gp_service_cases.js';
import { testRegistrationGp } from './registration_gp_cases.js';
import { testGpRuntimeRole } from './gp_runtime_role_cases.js';
import { testKnockoutSchema } from './knockout_schema_cases.js';
import { testKnockoutRegistration } from './knockout_registration_cases.js';

test('real PostgreSQL connectivity, migrations and account/session persistence', async (t) => {
  const url = process.env.TEST_DATABASE_URL;
  if (!url || process.env.NODE_ENV !== 'test' || !new URL(url).pathname.endsWith('_test')) {
    throw new Error('Use NODE_ENV=test and TEST_DATABASE_URL pointing to a disposable *_test database.');
  }
  const config = loadConfig({ ...process.env, NODE_ENV: 'test', LOG_LEVEL: 'silent', DATABASE_URL: url });
  const database = createDatabase(config, () => {}, 'migration');
  const app = buildApp(config, database);
  let ownsFixtures = false;
  try {
    await checkDatabase(database);
    const migrationTimeout = await database.query('SHOW statement_timeout');
    assert.equal(migrationTimeout.rows[0]!.statement_timeout, '2min');
    const apiDatabase = createDatabase(config, () => {});
    try {
      const apiTimeout = await apiDatabase.query('SHOW statement_timeout');
      assert.equal(apiTimeout.rows[0]!.statement_timeout, '5s');
    } finally { await apiDatabase.close(); }
    const existing = await database.query(`SELECT
      to_regclass('public.stoppy_schema_migrations') AS ledger,
      to_regnamespace('stoppy_runtime') AS runtime,
      to_regnamespace('stoppy_auth') AS auth,
      to_regnamespace('stoppy_economy') AS economy,
      to_regnamespace('stoppy_knockout') AS knockout`);
    assert.equal(existing.rows[0]!.ledger, null, 'Test database already has migration state; refusing to alter it.');
    assert.equal(existing.rows[0]!.runtime, null, 'Test database already has runtime schema; refusing to alter it.');
    assert.equal(existing.rows[0]!.auth, null, 'Test database already has auth schema; refusing to alter it.');
    assert.equal(existing.rows[0]!.economy, null, 'Test database already has economy schema; refusing to alter it.');
    assert.equal(existing.rows[0]!.knockout, null, 'Test database already has knockout schema; refusing to alter it.');
    ownsFixtures = true;
    const migrations = await readMigrations();
    await t.test('fresh install applies 001 through 004 without provisioning tournaments or financial movements', async () => {
      assert.equal(await runMigrations(database, migrations), 4);
      assert.equal((await database.query('SELECT id FROM stoppy_knockout.tournaments')).rows.length, 0);
      assert.equal((await database.query('SELECT id FROM stoppy_economy.gp_ledger')).rows.length, 0);
      await database.query('DROP SCHEMA stoppy_knockout CASCADE');
      await database.query('DROP SCHEMA stoppy_economy CASCADE');
      await database.query('DROP SCHEMA stoppy_auth CASCADE');
      await database.query('DROP SCHEMA stoppy_runtime CASCADE');
      await database.query('DROP TABLE public.stoppy_schema_migrations');
    });
    const authenticationMigrations = migrations.slice(0, 2);
    const initialResults = await Promise.all([
      runMigrations(database, authenticationMigrations), runMigrations(database, authenticationMigrations),
    ]);
    assert.deepEqual(initialResults.sort((a, b) => a - b), [0, authenticationMigrations.length]);
    const gpFixtures = await prepareGpBackfill(database);
    await t.test('failed migration batch rolls back 003 schema, opening snapshots and ledger version atomically', async () => {
      const failureSql = 'SELECT 1 / 0;';
      await assert.rejects(runMigrations(database, [...migrations, {
        version: `${String(migrations.length + 1).padStart(3, '0')}_gp_failure_probe.sql`,
        checksum: createHash('sha256').update(failureSql).digest('hex'), sql: failureSql,
      }]), (error: unknown) => error instanceof Error && 'code' in error && error.code === '22012');
      assert.equal((await database.query("SELECT to_regnamespace('stoppy_economy') AS economy")).rows[0]!.economy, null);
      assert.equal((await database.query('SELECT version FROM public.stoppy_schema_migrations')).rows.length, 2);
      assert.deepEqual(await readAuthState(database), gpFixtures.before);
    });
    assert.equal(await runMigrations(database, migrations.slice(0, 3)), 1);
    await t.test('failed 004 upgrade rolls back its schema and additive ledger reference key', async () => {
      const sql = 'SELECT 1 / 0;';
      await assert.rejects(runMigrations(database, [...migrations, {
        version: '005_upgrade_failure.sql', sql, checksum: createHash('sha256').update(sql).digest('hex'),
      }]), (error: unknown) => error instanceof Error && 'code' in error && error.code === '22012');
      assert.equal((await database.query("SELECT to_regnamespace('stoppy_knockout') AS schema")).rows[0]!.schema, null);
      assert.equal((await database.query("SELECT conname FROM pg_constraint WHERE conname = 'gp_ledger_registration_reference'")).rows.length, 0);
      assert.equal((await database.query('SELECT version FROM public.stoppy_schema_migrations')).rows.length, 3);
      assert.deepEqual(await readAuthState(database), gpFixtures.before);
    });
    const results = await Promise.all([runMigrations(database, migrations), runMigrations(database, migrations)]);
    assert.deepEqual(results.sort((a, b) => a - b), [0, 1]);
    assert.equal(await runMigrations(database, migrations), 0);
    assert.equal((await app.inject('/api/v1/ready')).statusCode, 200);
    const failingSql = 'CREATE TABLE stoppy_runtime.rollback_probe (id integer); SELECT 1 / 0;';
    await assert.rejects(runMigrations(database, [...migrations, {
      version: `${String(migrations.length + 1).padStart(3, '0')}_rollback_probe.sql`,
      checksum: createHash('sha256').update(failingSql).digest('hex'),
      sql: failingSql,
    }]), (error: unknown) => {
      assert.ok(error instanceof Error && 'code' in error);
      assert.equal(error.code, '22012'); // Prove SQL executed and failed, not just list validation.
      return true;
    });
    const probe = await database.query("SELECT to_regclass('stoppy_runtime.rollback_probe') AS table_name");
    assert.equal(probe.rows[0]!.table_name, null);
    const ledger = await database.query('SELECT version FROM public.stoppy_schema_migrations');
    assert.equal(ledger.rows.length, migrations.length);
    await testGpSchema(t, database, gpFixtures);
    await testKnockoutSchema(t, database);
    await testKnockoutRegistration(t, database);
    await testGpService(t, database);

    let time = new Date('2026-10-26T12:00:00.000Z');
    const now = () => time;
    const repository = new PostgresAuthRepository(database, now);
    const passwords = new ArgonPasswordHasher();
    const tokens = new TokenService(config.auth);
    const auth = new AuthService(config.auth, repository, passwords, tokens, now);
    const alice = await auth.register({ username: ' Alice ', password: ' pass ' });

    await t.test('registration persists hashed credentials, default GP and only token digests', async () => {
      assert.equal(alice.playerProfile.username, 'Alice');
      assert.equal(alice.playerProfile.gamePoints, 5);
      assert.equal(alice.playerProfile.adsRemoved, false);
      assert.equal(alice.playerProfile.hasWeeklyLeagueEntry, false);
      assert.equal(alice.playerProfile.currentLeagueDivision, null);
      const player = (await database.query('SELECT * FROM stoppy_auth.players WHERE id = $1', [alice.playerProfile.id])).rows[0]!;
      assert.equal(player.canonical_username, 'alice');
      assert.match(player.password_hash as string, /^\$argon2id\$/);
      assert.notEqual(player.password_hash, ' pass ');
      const token = (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [tokenDigest(alice.session.refreshToken)])).rows[0]!;
      assert.equal(token.token_digest, tokenDigest(alice.session.refreshToken));
      assert.ok(!JSON.stringify(token).includes(alice.session.refreshToken));
      assert.deepEqual(await auth.profile('Bearer ' + alice.session.accessToken), alice.playerProfile);
    });

    await testRegistrationGp(t, database, config, now);
    await testGpRuntimeRole(t, database, config, now);

    await t.test('new application instance logs in using persisted accounts and serves Flutter profile', async () => {
      const restartedDatabase = createDatabase(config, () => {});
      const restartedAuth = new AuthService(config.auth, new PostgresAuthRepository(restartedDatabase, now),
        new ArgonPasswordHasher(), new TokenService(config.auth), now);
      const restartedApp = buildApp(config, restartedDatabase, { auth: restartedAuth });
      try {
        const login = await restartedApp.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: ' ALICE ', password: ' pass ' } });
        assert.equal(login.statusCode, 200);
        assert.equal(login.json().data.playerProfile.id, alice.playerProfile.id);
        const result = await restartedApp.inject({ url: '/api/v1/player/profile?playerId=' + randomUUID(),
          headers: { authorization: 'Bearer ' + login.json().data.session.accessToken } });
        assert.deepEqual(result.json(), { success: true, data: alice.playerProfile });
        for (const username of ['Alice', 'not-an-account']) {
          const wrong = await restartedApp.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password: 'wrong' } });
          assert.equal(wrong.statusCode, 401);
          assert.deepEqual(wrong.json(), { success: false, error: { code: 'unauthenticated', message: 'Invalid authentication credentials.' } });
        }
      } finally { await restartedApp.close(); }
    });

    await t.test('a separate Node process can log in and restore persisted identity with a stable signing key', async () => {
      const script = `
        import { loadConfig } from './src/config.ts';
        import { createDatabase } from './src/database.ts';
        import { PostgresAuthRepository } from './src/auth/auth_repository.ts';
        import { AuthService } from './src/auth/auth_service.ts';
        import { ArgonPasswordHasher } from './src/auth/password_hasher.ts';
        import { TokenService } from './src/auth/token_service.ts';
        const config = loadConfig(process.env);
        const db = createDatabase(config, () => {});
        const now = () => new Date('2026-10-26T12:00:00.000Z');
        const auth = new AuthService(config.auth, new PostgresAuthRepository(db, now), new ArgonPasswordHasher(), new TokenService(config.auth), now);
        try { console.log(JSON.stringify(await auth.login({username:'ALICE', password:' pass '}))); }
        finally { await db.close(); }
      `;
      const result = spawnSync(process.execPath, ['--import', 'tsx', '--input-type=module', '-e', script], {
        encoding: 'utf8', timeout: 15000,
        env: { ...process.env, NODE_ENV: 'test', DATABASE_URL: url, LOG_LEVEL: 'silent',
          AUTH_PRIVATE_KEY: config.auth.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
          AUTH_ISSUER: config.auth.issuer, AUTH_AUDIENCE: config.auth.audience },
      });
      assert.equal(result.status, 0, result.stderr);
      const login = JSON.parse(result.stdout);
      assert.deepEqual(login.playerProfile, alice.playerProfile);
      assert.equal((await auth.profile('Bearer ' + login.session.accessToken)).id, alice.playerProfile.id);
    });

    await t.test('database enforces canonical uniqueness under concurrent registration', async () => {
      const results = await Promise.allSettled([
        auth.register({ username: 'Concurrent', password: 'pass' }),
        auth.register({ username: 'CONCURRENT', password: 'pass' }),
      ]);
      assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
      const failure = results.find((result) => result.status === 'rejected') as PromiseRejectedResult;
      assert.equal((failure.reason as ApiError).code, 'conflict');
      const count = await database.query("SELECT count(*)::int AS count FROM stoppy_auth.players WHERE canonical_username = 'concurrent'");
      assert.equal(count.rows[0]!.count, 1);
      const opening = await database.query(`SELECT l.* FROM stoppy_economy.gp_ledger l
        JOIN stoppy_auth.players p ON p.id = l.player_id WHERE p.canonical_username = 'concurrent'`);
      assert.equal(opening.rows.length, 1);
      assert.equal(opening.rows[0]!.movement_type, 'opening_snapshot');
      assert.equal(opening.rows[0]!.delta, 0);
      assert.equal(opening.rows[0]!.balance_after, 5);
      await assert.rejects(auth.register({ username: 'alice', password: 'pass' }), (e: unknown) => (e as ApiError).code === 'conflict');
    });

    await t.test('registration rolls account insertion back if initial session persistence fails', async () => {
      const id = randomUUID();
      const existingDigest = tokenDigest(alice.session.refreshToken);
      await assert.rejects(repository.register(id, 'RollbackAccount', await passwords.hash('pass'), {
        id: randomUUID(), playerId: id, tokenId: randomUUID(), digest: existingDigest,
        createdAt: time, expiresAt: new Date(time.getTime() + 86400000),
      }));
      assert.equal(await repository.findCredentials('rollbackaccount'), null);
      assert.equal((await database.query('SELECT id FROM stoppy_economy.gp_ledger WHERE player_id = $1', [id])).rows.length, 0);
      assert.equal((await database.query('SELECT id FROM stoppy_auth.auth_sessions WHERE player_id = $1', [id])).rows.length, 0);
    });

    await t.test('refresh rotates atomically and replay commits family revocation', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const rotated = await auth.refresh({ refreshToken: initial.session.refreshToken });
      assert.notEqual(rotated.session.refreshToken, initial.session.refreshToken);
      assert.equal((await auth.profile('Bearer ' + rotated.session.accessToken)).id, alice.playerProfile.id);
      const old = (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [tokenDigest(initial.session.refreshToken)])).rows[0]!;
      assert.ok(old.consumed_at);
      assert.ok(old.replaced_by);
      await assert.rejects(auth.refresh({ refreshToken: initial.session.refreshToken }), (e: unknown) => (e as ApiError).code === 'unauthenticated');
      await assert.rejects(auth.refresh({ refreshToken: rotated.session.refreshToken }));
      await assert.rejects(auth.profile('Bearer ' + rotated.session.accessToken));
      // Reuse of one device's family never revokes an independent login family.
      assert.equal((await auth.profile('Bearer ' + alice.session.accessToken)).id, alice.playerProfile.id);
    });

    await t.test('concurrent refresh succeeds at most once and replay revokes that family', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const results = await Promise.allSettled([
        auth.refresh({ refreshToken: initial.session.refreshToken }), auth.refresh({ refreshToken: initial.session.refreshToken }),
      ]);
      assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
      assert.equal(results.filter((r) => r.status === 'rejected').length, 1);
      const success = results.find((r) => r.status === 'fulfilled') as PromiseFulfilledResult<{ session: typeof initial.session }>;
      await assert.rejects(auth.profile('Bearer ' + success.value.session.accessToken));
      const count = (await database.query(`SELECT count(*)::int AS count FROM stoppy_auth.auth_refresh_tokens
        WHERE session_id = (SELECT session_id FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1)`,
      [tokenDigest(initial.session.refreshToken)])).rows[0]!.count;
      assert.equal(count, 2);
    });

    await t.test('backward host clock preserves consumption and revokes reused credentials before family creation time', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const skewedNow = () => new Date(time.getTime() - 10000);
      const skewedRepository = new PostgresAuthRepository(database, skewedNow);
      const skewedAuth = new AuthService(config.auth, skewedRepository, passwords, tokens, skewedNow);
      const rotated = await skewedAuth.refresh({ refreshToken: initial.session.refreshToken });
      const old = (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1',
        [tokenDigest(initial.session.refreshToken)])).rows[0]!;
      const replacement = (await database.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1',
        [tokenDigest(rotated.session.refreshToken)])).rows[0]!;
      assert.ok((old.consumed_at as Date) >= (old.created_at as Date));
      assert.equal((replacement.created_at as Date).getTime(), (old.consumed_at as Date).getTime());
      assert.equal((replacement.expires_at as Date).getTime(), (old.expires_at as Date).getTime());
      // Both guards accept the rotated JWT before revocation; the denial below
      // must come from stored revocation, not an accidentally future-dated iat.
      assert.equal((await skewedAuth.profile('Bearer ' + rotated.session.accessToken)).id, alice.playerProfile.id);
      assert.equal((await auth.profile('Bearer ' + rotated.session.accessToken)).id, alice.playerProfile.id);
      await assert.rejects(skewedAuth.refresh({ refreshToken: initial.session.refreshToken }),
        (error: unknown) => (error as ApiError).code === 'unauthenticated' && (error as ApiError).statusCode === 401);
      const family = (await database.query('SELECT * FROM stoppy_auth.auth_sessions WHERE id = $1', [old.session_id])).rows[0]!;
      assert.ok((family.revoked_at as Date) >= (family.created_at as Date));
      assert.ok((family.revoked_at as Date) >= (old.consumed_at as Date));
      assert.ok(skewedNow() < (family.created_at as Date));
      await assert.rejects(auth.profile('Bearer ' + rotated.session.accessToken),
        (error: unknown) => (error as ApiError).code === 'unauthenticated');
      await assert.rejects(skewedAuth.profile('Bearer ' + rotated.session.accessToken));
    });

    await t.test('independent skewed repository instances serialize concurrent refresh and commit reuse revocation', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const services = [10000, 20000].map((skew) => {
        const clock = () => new Date(time.getTime() - skew);
        return new AuthService(config.auth, new PostgresAuthRepository(database, clock), passwords, tokens, clock);
      });
      const results = await Promise.allSettled(services.map((service) => service.refresh({ refreshToken: initial.session.refreshToken })));
      const accepted = results.filter((result) => result.status === 'fulfilled');
      const rejected = results.filter((result) => result.status === 'rejected');
      assert.equal(accepted.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal((rejected[0]!.reason as ApiError).code, 'unauthenticated');
      const session = accepted[0]!.value.session;
      assert.ok((await tokens.verify('Bearer ' + session.accessToken, time)).playerId);
      const family = (await database.query(`SELECT s.* FROM stoppy_auth.auth_sessions s
        JOIN stoppy_auth.auth_refresh_tokens t ON t.session_id = s.id WHERE t.token_digest = $1`,
      [tokenDigest(session.refreshToken)])).rows[0]!;
      assert.ok((family.revoked_at as Date) >= (family.created_at as Date));
      await assert.rejects(auth.profile('Bearer ' + session.accessToken));
    });

    await t.test('failed revocation rolls back and reports failure without pretending the family was revoked', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const rotated = await auth.refresh({ refreshToken: initial.session.refreshToken });
      let revocationAttempts = 0;
      const failingDatabase = {
        query: database.query, close: async () => {},
        connect: async () => {
          const client = await database.connect();
          return {
            query: async (sql: string, values?: unknown[]) => {
              if (sql.startsWith('UPDATE stoppy_auth.auth_sessions SET revoked_at')) {
                revocationAttempts++;
                // A real SQL error aborts the transaction; the helper must roll it back.
                return client.query('SELECT 1 / 0');
              }
              return client.query(sql, values);
            },
            release: (discard?: boolean) => client.release(discard),
          };
        },
      };
      const skewedNow = () => new Date(time.getTime() - 10000);
      const failingAuth = new AuthService(config.auth, new PostgresAuthRepository(failingDatabase, skewedNow), passwords, tokens, skewedNow);
      await assert.rejects(failingAuth.refresh({ refreshToken: initial.session.refreshToken }),
        (error: unknown) => (error as { code: string }).code === '22012');
      assert.equal(revocationAttempts, 1);
      const family = (await database.query(`SELECT s.revoked_at FROM stoppy_auth.auth_sessions s
        JOIN stoppy_auth.auth_refresh_tokens t ON t.session_id = s.id WHERE t.token_digest = $1`,
      [tokenDigest(rotated.session.refreshToken)])).rows[0]!;
      assert.equal(family.revoked_at, null);
      assert.equal((await auth.profile('Bearer ' + rotated.session.accessToken)).id, alice.playerProfile.id);
      // Only an explicit subsequent attempt performs revocation; there is no replay.
      await assert.rejects(auth.refresh({ refreshToken: initial.session.refreshToken }),
        (error: unknown) => (error as ApiError).code === 'unauthenticated');
      await assert.rejects(auth.profile('Bearer ' + rotated.session.accessToken));
    });

    await t.test('registration and login after local logout preserve exact surrounding password spaces', async () => {
      const password = ' valid password ';
      const registered = await auth.register({ username: 'PasswordLifecycle', password });
      const savedProfile = registered.playerProfile;
      // Flutter logout is local-only: discard credentials, then authenticate a
      // new client using only username/password, without a remote logout mutation.
      const returningClient = new AuthService(config.auth, repository, new ArgonPasswordHasher(), new TokenService(config.auth), now);
      const loggedIn = await returningClient.login({ username: 'passwordlifecycle', password });
      assert.deepEqual(loggedIn.playerProfile, savedProfile);
      assert.notEqual(loggedIn.session.refreshToken, registered.session.refreshToken);
      await assert.rejects(returningClient.login({ username: 'PasswordLifecycle', password: password.trim() }),
        (error: unknown) => (error as ApiError).code === 'unauthenticated');
      await assert.rejects(auth.register({ username: 'BlankPassword', password: '    ' }),
        (error: unknown) => (error as ApiError).code === 'validationFailed');
      assert.equal(await repository.findCredentials('blankpassword'), null);
    });

    await t.test('NEXT LINE passwords persist and verify exactly without whitespace transformation', async () => {
      const password = '\u0085 valid password \u0085';
      const registered = await auth.register({ username: 'NextLinePassword', password });
      const loggedIn = await auth.login({ username: 'NextLinePassword', password });
      assert.equal(loggedIn.playerProfile.id, registered.playerProfile.id);
      const stored = await repository.findCredentials('nextlinepassword');
      assert.ok(stored);
      assert.equal(await passwords.verify(stored.passwordHash, password), true);
      const withoutNextLine = password.replaceAll('\u0085', '');
      assert.equal(await passwords.verify(stored.passwordHash, withoutNextLine), false);
      await assert.rejects(auth.login({ username: 'NextLinePassword', password: withoutNextLine }),
        (error: unknown) => (error as ApiError).code === 'unauthenticated');
      await assert.rejects(auth.register({ username: 'BlankNextLine', password: '\u0085'.repeat(4) }),
        (error: unknown) => (error as ApiError).code === 'validationFailed' && (error as ApiError).statusCode === 400);
      assert.equal(await repository.findCredentials('blanknextline'), null);
    });

    await t.test('existing short-password accounts can log in without the registration minimum', async () => {
      const id = randomUUID();
      // Model an existing account, not a new HTTP registration bypass.
      await repository.register(id, 'LegacyShortPassword', await passwords.hash('abc'), {
        id: randomUUID(), playerId: id, tokenId: randomUUID(), digest: tokenDigest(newRefreshToken()),
        createdAt: time, expiresAt: new Date(time.getTime() + config.auth.refreshSeconds * 1000),
      });
      const login = await auth.login({ username: 'LegacyShortPassword', password: 'abc' });
      assert.equal(login.playerProfile.id, id);
      assert.equal((await auth.profile('Bearer ' + login.session.accessToken)).id, id);
    });

    await t.test('failed replacement insertion rolls consumption back and leaves the old credential usable', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      const digest = tokenDigest(initial.session.refreshToken);
      const row = (await database.query('SELECT id FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [digest])).rows[0]!;
      const replacement = newRefreshToken();
      await assert.rejects(repository.rotate(digest, row.id as string, tokenDigest(replacement),
        (playerId, sessionId, now, expiry) => tokens.issue(playerId, sessionId, replacement, now, expiry)));
      const rolledBack = (await database.query('SELECT consumed_at, replaced_by FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [digest])).rows[0]!;
      assert.equal(rolledBack.consumed_at, null);
      assert.equal(rolledBack.replaced_by, null);
      assert.ok((await auth.refresh({ refreshToken: initial.session.refreshToken })).session.accessToken);
    });

    await t.test('expired refresh credential is rejected even while its session family is still valid', async () => {
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      await database.query('UPDATE stoppy_auth.auth_refresh_tokens SET expires_at = $1 WHERE token_digest = $2',
        [new Date(time.getTime() + 1000), tokenDigest(initial.session.refreshToken)]);
      time = new Date(time.getTime() + 2000);
      await assert.rejects(auth.refresh({ refreshToken: initial.session.refreshToken }));
      assert.equal((await auth.profile('Bearer ' + initial.session.accessToken)).id, alice.playerProfile.id);
    });

    await t.test('unknown, malformed and expired refresh credentials and sessions are rejected', async () => {
      await assert.rejects(auth.refresh({ refreshToken: newRefreshToken() }));
      await assert.rejects(auth.refresh({ refreshToken: 'malformed' }));
      const initial = await auth.login({ username: 'Alice', password: ' pass ' });
      time = new Date(time.getTime() + config.auth.refreshSeconds * 1000);
      await assert.rejects(auth.refresh({ refreshToken: initial.session.refreshToken }));
      // Even a newly signed JWT cannot resurrect an expired database session.
      const token = (await database.query('SELECT session_id FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [tokenDigest(initial.session.refreshToken)])).rows[0]!;
      const forgedLifetime = await tokens.issue(alice.playerProfile.id, token.session_id as string, newRefreshToken(), time, new Date(time.getTime() + 86400000));
      await assert.rejects(auth.profile('Bearer ' + forgedLifetime.accessToken));
    });

    await t.test('database constraints reject unsupported usernames, negative GP and foreign session replacement', async () => {
      await assert.rejects(database.query('UPDATE stoppy_auth.players SET game_points = -1 WHERE id = $1', [alice.playerProfile.id]));
      await assert.rejects(database.query('UPDATE stoppy_auth.players SET username = $1 WHERE id = $2', ['Álice', alice.playerProfile.id]));
      const rows = (await database.query('SELECT id FROM stoppy_auth.auth_refresh_tokens WHERE consumed_at IS NULL LIMIT 2')).rows;
      await assert.rejects(database.query('UPDATE stoppy_auth.auth_refresh_tokens SET consumed_at = expires_at, replaced_by = $1 WHERE id = $2', [rows[0]!.id, rows[1]!.id]));
    });
  } finally {
    try {
      // Only these fixtures are owned by this test, in an explicit disposable DB.
      if (ownsFixtures) {
        await database.query('DROP SCHEMA IF EXISTS stoppy_knockout CASCADE');
        await database.query('DROP SCHEMA IF EXISTS stoppy_economy CASCADE');
        await database.query('DROP SCHEMA IF EXISTS stoppy_auth CASCADE');
        await database.query('DROP SCHEMA IF EXISTS stoppy_runtime CASCADE');
        await database.query('DROP TABLE IF EXISTS public.stoppy_schema_migrations');
      }
    } finally { await app.close(); }
  }
});
