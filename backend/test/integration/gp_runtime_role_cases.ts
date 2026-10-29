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
      'USAGE ON SCHEMA stoppy_auth, stoppy_economy',
      'SELECT ON stoppy_auth.players, stoppy_auth.auth_sessions, stoppy_auth.auth_refresh_tokens, stoppy_economy.gp_mutations, stoppy_economy.gp_ledger',
      'INSERT (id, username, password_hash, created_at) ON stoppy_auth.players',
      'UPDATE (game_points) ON stoppy_auth.players',
      'INSERT (id, player_id, created_at, expires_at) ON stoppy_auth.auth_sessions',
      'UPDATE (revoked_at) ON stoppy_auth.auth_sessions',
      'INSERT (id, session_id, token_digest, created_at, expires_at) ON stoppy_auth.auth_refresh_tokens',
      'UPDATE (consumed_at, replaced_by) ON stoppy_auth.auth_refresh_tokens',
      'INSERT (id, player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint, outcome_status, semantic_outcome, resolved_context) ON stoppy_economy.gp_mutations',
      'INSERT (id, player_id, mutation_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after) ON stoppy_economy.gp_ledger',
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
