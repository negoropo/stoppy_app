import assert from 'node:assert/strict';
import type { TestContext } from 'node:test';
import { randomBytes, randomUUID } from 'node:crypto';
import type { Config } from '../../src/config.js';
import { createDatabase, type Database } from '../../src/database.js';
import { AuthService } from '../../src/auth/auth_service.js';
import { PostgresAuthRepository } from '../../src/auth/auth_repository.js';
import { ArgonPasswordHasher } from '../../src/auth/password_hasher.js';
import { TokenService } from '../../src/auth/token_service.js';
import { GpService, type GpExecutionResult } from '../../src/economy/gp_service.js';
import { GpExecutor } from '../../src/economy/gp_executor.js';
import { inTransaction } from '../../src/transaction.js';
import { insertOperationFixture, insertRegistrationFixture } from './knockout_schema_cases.js';
import { KnockoutRegistrationService } from '../../src/knockout/knockout_registration_service.js';

const permissionDenied = (error: unknown) => error instanceof Error && 'code' in error && error.code === '42501';

/** The provisioner owns the disposable schemas; the tested application opens a
 * separate authenticated connection, not SET ROLE on a superuser session. */
export async function testGpRuntimeRole(t: TestContext, provisioner: Database, config: Config, now: () => Date) {
  const role = 'stoppy_runtime_test_' + randomUUID().replaceAll('-', '');
  const password = randomBytes(32).toString('hex');
  let created = false;
  let runtime: Database | undefined;
  try {
    // Identifiers/password here are generated ASCII hex, never supplied externally.
    await provisioner.query(`CREATE ROLE ${role} LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '${password}'`);
    created = true;
    const connectGrant = await provisioner.query(`SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), $1::text) AS sql`, [role]);
    await provisioner.query(connectGrant.rows[0]!.sql as string);
    for (const grant of [
      'USAGE ON SCHEMA stoppy_auth, stoppy_economy, stoppy_knockout',
      'SELECT ON stoppy_auth.players, stoppy_auth.auth_sessions, stoppy_auth.auth_refresh_tokens, stoppy_economy.gp_mutations, stoppy_economy.gp_ledger',
      'INSERT (id, username, password_hash, created_at) ON stoppy_auth.players',
      'UPDATE (game_points) ON stoppy_auth.players',
      'INSERT (id, player_id, created_at, expires_at) ON stoppy_auth.auth_sessions',
      'UPDATE (revoked_at) ON stoppy_auth.auth_sessions',
      'INSERT (id, session_id, token_digest, created_at, expires_at) ON stoppy_auth.auth_refresh_tokens',
      'UPDATE (consumed_at, replaced_by) ON stoppy_auth.auth_refresh_tokens',
      'INSERT (id, player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint, outcome_status, semantic_outcome, resolved_context) ON stoppy_economy.gp_mutations',
      'INSERT (id, player_id, mutation_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after) ON stoppy_economy.gp_ledger',
      'SELECT ON stoppy_knockout.tournaments, stoppy_knockout.registrations, stoppy_knockout.registration_operations',
      'INSERT (id, player_id, tournament_id, gp_ledger_id, gp_mutation_id, registered_at) ON stoppy_knockout.registrations',
      'INSERT (player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint, tournament_id, outcome_status, registration_id, rejection_reason, semantic_outcome, created_at, completed_at) ON stoppy_knockout.registration_operations',
    ]) await provisioner.query(`GRANT ${grant} TO ${role}`);

    const url = new URL(config.databaseUrl);
    url.username = role;
    url.password = password;
    const db = createDatabase({ ...config, databaseUrl: url.toString() }, () => {});
    runtime = db;
    const auth = new AuthService(config.auth, new PostgresAuthRepository(db, now), new ArgonPasswordHasher(), new TokenService(config.auth), now);
    const gp = new GpService(db);

    await t.test('restricted runtime connects as its own non-owner identity without privilege escalation', async () => {
      const identity = (await db.query(`SELECT current_user, session_user, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls
        FROM pg_roles WHERE rolname = current_user`)).rows[0]!;
      assert.deepEqual(identity, { current_user: role, session_user: role, rolsuper: false, rolcreaterole: false,
        rolcreatedb: false, rolreplication: false, rolbypassrls: false });
      const owners = (await db.query(`SELECT relowner::regrole::text AS owner FROM pg_class
        WHERE oid IN ('stoppy_auth.players'::regclass, 'stoppy_economy.gp_ledger'::regclass, 'stoppy_economy.gp_mutations'::regclass)`)).rows;
      assert.equal(owners.length, 3);
      assert.ok(owners.every((row) => row.owner !== role));
      const escalation = (await provisioner.query("SELECT format('SET ROLE %I', current_user) AS sql")).rows[0]!.sql as string;
      await assert.rejects(db.query(escalation), permissionDenied);
      await assert.rejects(db.query('SET session_replication_role = replica'), permissionDenied);
      assert.equal((await db.query('SELECT current_user')).rows[0]!.current_user, role);
    });

    await t.test('least-privilege runtime registers with one opening, logs in, rotates and revokes replayed refresh credentials', async () => {
      const registered = await auth.register({ username: 'RestrictedRoleAuth', password: ' pass ' });
      assert.equal(registered.playerProfile.gamePoints, 5);
      const id = registered.playerProfile.id;
      const ledger = (await db.query('SELECT * FROM stoppy_economy.gp_ledger WHERE player_id = $1', [id])).rows;
      assert.equal(ledger.length, 1);
      assert.equal(ledger[0]!.movement_type, 'opening_snapshot');
      assert.equal(ledger[0]!.delta, 0);
      assert.equal(ledger[0]!.balance_before, 5);
      assert.equal(ledger[0]!.balance_after, 5);
      const login = await auth.login({ username: 'restrictedroleauth', password: ' pass ' });
      assert.deepEqual(login.playerProfile, registered.playerProfile);
      const refreshed = await auth.refresh({ refreshToken: login.session.refreshToken });
      assert.deepEqual(await auth.profile('Bearer ' + refreshed.session.accessToken), registered.playerProfile);
      await assert.rejects(auth.refresh({ refreshToken: login.session.refreshToken }),
        (error: unknown) => error instanceof Error && 'code' in error && error.code === 'unauthenticated');
      await assert.rejects(auth.profile('Bearer ' + refreshed.session.accessToken));
      assert.deepEqual(await auth.profile('Bearer ' + registered.session.accessToken), registered.playerProfile);
    });

    await t.test('least-privilege runtime performs atomic GP credit/debit and durable replay', async () => {
      const registered = await auth.register({ username: 'RestrictedRoleEconomy', password: 'pass' });
      const playerId = registered.playerProfile.id;
      const input = { playerId, operationName: 'role_test', operationVersion: 1, idempotencyKey: randomUUID(), amount: 3,
        reason: 'test_only', sourceType: 'test_fixture', sourceId: randomUUID(), context: { test: 'restricted-role' } };
      const complete = (result: GpExecutionResult) => {
        assert.ok(result.status === 'completed');
        return result;
      };
      const first = complete(await gp.credit(input));
      assert.equal(first.outcome.status, 'accepted');
      assert.equal(first.currentBalance, 8);
      const replay = complete(await new GpService(db).credit(input));
      assert.equal(replay.replayed, true);
      assert.deepEqual(replay.outcome, first.outcome);
      const debit = complete(await gp.debit({ ...input, idempotencyKey: randomUUID(), sourceId: randomUUID(), amount: 2 }));
      assert.equal(debit.currentBalance, 6);
      const rejected = complete(await gp.debit({ ...input, idempotencyKey: randomUUID(), sourceId: randomUUID(), amount: 7 }));
      assert.equal(rejected.outcome.status, 'rejected');
      assert.equal((await auth.profile('Bearer ' + registered.session.accessToken)).gamePoints, 6);
      const rows = (await db.query('SELECT delta, balance_before, balance_after FROM stoppy_economy.gp_ledger WHERE player_id = $1', [playerId])).rows;
      assert.equal(rows.length, 3);
      assert.equal(5 + rows.reduce((sum, row) => sum + (row.delta as number), 0), 6);
    });

    await t.test('restricted runtime composes executor operations and rolls back outer business failure without new grants', async () => {
      const registered = await auth.register({ username: 'RestrictedExecutor', password: 'pass' });
      const playerId = registered.playerProfile.id;
      await assert.rejects(inTransaction(db, async (connection) => {
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const executor = new GpExecutor(connection);
        const input = { playerId, operationName: 'executor_test', operationVersion: 1, idempotencyKey: randomUUID(), amount: 3,
          reason: 'test_only', sourceType: 'test_fixture', sourceId: randomUUID(), context: {} };
        await executor.credit(input);
        await executor.debit({ ...input, idempotencyKey: randomUUID(), sourceId: randomUUID() });
        throw new Error('Outer persistence failed.');
      }));
      assert.equal((await auth.profile('Bearer ' + registered.session.accessToken)).gamePoints, 5);
      assert.equal((await db.query('SELECT id FROM stoppy_economy.gp_ledger WHERE player_id = $1', [playerId])).rows.length, 1);
      assert.equal((await db.query('SELECT id FROM stoppy_economy.gp_mutations WHERE player_id = $1', [playerId])).rows.length, 0);
    });

    await t.test('restricted runtime cannot rewrite/truncate audit tables, disable triggers or modify protected functions/schemas', async () => {
      const before = (await db.query('SELECT * FROM stoppy_economy.gp_ledger ORDER BY id')).rows;
      for (const table of ['gp_ledger', 'gp_mutations']) {
        for (const sql of [
          `UPDATE stoppy_economy.${table} SET created_at = created_at`,
          `DELETE FROM stoppy_economy.${table}`, `TRUNCATE stoppy_economy.${table} CASCADE`,
          `ALTER TABLE stoppy_economy.${table} DISABLE TRIGGER USER`,
        ]) await assert.rejects(db.query(sql), permissionDenied);
      }
      await assert.rejects(db.query('ALTER FUNCTION stoppy_economy.reject_audit_rewrite() RENAME TO bypassed_audit'), permissionDenied);
      await assert.rejects(db.query('CREATE TABLE stoppy_economy.unauthorized_probe (id integer)'), permissionDenied);
      await assert.rejects(db.query('CREATE TABLE stoppy_auth.unauthorized_probe (id integer)'), permissionDenied);
      assert.deepEqual((await db.query('SELECT * FROM stoppy_economy.gp_ledger ORDER BY id')).rows, before);
    });

    await t.test('restricted runtime cannot overwrite profile attributes or choose a registration GP balance', async () => {
      await assert.rejects(db.query('UPDATE stoppy_auth.players SET ads_removed = true'), permissionDenied);
      await assert.rejects(db.query(`INSERT INTO stoppy_auth.players (id, username, password_hash, created_at, game_points)
        VALUES ($1, 'UnauthorizedBalance', '$argon2id$test-only', CURRENT_TIMESTAMP, 1000)`, [randomUUID()]), permissionDenied);
    });

    await t.test('restricted runtime writes linked Knockout persistence fixtures but cannot provision tournaments or rewrite evidence', async () => {
      // Only the schema-owner fixture provisions this catalog row; no runtime provisioning service exists.
      const tournamentId = (await provisioner.query(`INSERT INTO stoppy_knockout.tournaments
        (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
        VALUES ('2040-01-01', 'Restricted fixture', '2039-12-01T00:00:00Z', '2039-12-31T23:59:00Z',
          '2040-01-01T00:00:00Z', 'registrationOpen') RETURNING id`)).rows[0]!.id as string;
      const registered = await auth.register({ username: 'RestrictedKnockout', password: 'pass' });
      const playerId = registered.playerProfile.id;
      await gp.credit({ playerId, operationName: 'fixture_funding', operationVersion: 1,
        idempotencyKey: randomUUID(), amount: 25, reason: 'test_only', sourceType: 'fixture', sourceId: randomUUID(), context: {} });
      const registration = await inTransaction(db, async (connection) => {
        const row = await insertRegistrationFixture(connection, playerId, tournamentId);
        await insertOperationFixture(connection, playerId, tournamentId, row.id as string);
        return row;
      });
      assert.equal(registration.player_id, playerId);
      assert.equal((await auth.profile('Bearer ' + registered.session.accessToken)).gamePoints, 5);
      const rejected = await insertOperationFixture(db, playerId, tournamentId);
      assert.equal(rejected.rejection_reason, 'insufficientGp');
      assert.equal((await db.query('SELECT id FROM stoppy_economy.gp_ledger WHERE player_id = $1', [playerId])).rows.length, 3);
      const owners = (await db.query(`SELECT relowner::regrole::text AS owner FROM pg_class WHERE oid IN
        ('stoppy_knockout.tournaments'::regclass, 'stoppy_knockout.registrations'::regclass,
         'stoppy_knockout.registration_operations'::regclass)`)).rows;
      assert.equal(owners.length, 3);
      assert.ok(owners.every((row) => row.owner !== role));
      for (const table of ['tournaments', 'registrations', 'registration_operations']) {
        for (const sql of [`UPDATE stoppy_knockout.${table} SET id = id`,
          `DELETE FROM stoppy_knockout.${table}`, `TRUNCATE stoppy_knockout.${table} CASCADE`,
          `ALTER TABLE stoppy_knockout.${table} DISABLE TRIGGER USER`]) {
          await assert.rejects(db.query(sql), permissionDenied);
        }
      }
      await assert.rejects(db.query(`INSERT INTO stoppy_knockout.tournaments
        (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
        VALUES ('2040-02-01', 'Not trusted', '2040-01-01T00:00:00Z', '2040-01-31T23:59:00Z',
          '2040-02-01T00:00:00Z', 'registrationOpen')`), permissionDenied);
      await assert.rejects(db.query('CREATE TABLE stoppy_knockout.unauthorized_probe (id integer)'), permissionDenied);
    });

    await t.test('restricted runtime executes the actual Knockout service with existing grants and durable replay', async () => {
      const tournamentId = (await provisioner.query(`INSERT INTO stoppy_knockout.tournaments
        (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
        VALUES ('2041-01-01', 'Service role fixture', clock_timestamp() - interval '1 day',
          clock_timestamp() + interval '1 day', clock_timestamp() + interval '2 days', 'registrationOpen') RETURNING id`)).rows[0]!.id as string;
      const account = await auth.register({ username: 'RestrictedActualKnockout', password: 'pass' });
      const playerId = account.playerProfile.id;
      await gp.credit({ playerId, operationName: 'fixture_funding', operationVersion: 1, idempotencyKey: randomUUID(),
        amount: 25, reason: 'test_only', sourceType: 'fixture', sourceId: randomUUID(), context: {} });
      const input = { playerId, tournamentId, idempotencyKey: randomUUID() };
      const first = await new KnockoutRegistrationService(db).register(input);
      assert.ok(first.status === 'completed' && first.outcome.status === 'accepted');
      assert.equal(first.outcome.remainingGamePoints, 5);
      const replay = await new KnockoutRegistrationService(db).register(input);
      assert.ok(replay.status === 'completed');
      assert.equal(replay.replayed, true);
      assert.deepEqual(replay.outcome, first.outcome);
      assert.equal((await db.query('SELECT id FROM stoppy_knockout.registrations WHERE player_id = $1', [playerId])).rows.length, 1);
      assert.equal((await auth.profile('Bearer ' + account.session.accessToken)).gamePoints, 5);
    });
  } finally {
    try { await runtime?.close(); }
    finally {
      if (created) {
        // This unique test role owns no schema objects; remove only its fixture grants.
        await provisioner.query(`DROP OWNED BY ${role}`);
        await provisioner.query(`DROP ROLE ${role}`);
      }
    }
  }
}
