import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import type { TestContext } from 'node:test';
import type { Database, TransactionConnection } from '../../src/database.js';
import { inTransaction } from '../../src/transaction.js';
import { KnockoutTournamentCatalog } from '../../src/knockout/knockout_tournament_catalog.js';

function catalogUsing(database: Database, query: (connection: TransactionConnection,
  sql: string, values?: unknown[]) => ReturnType<TransactionConnection['query']>) {
  return new KnockoutTournamentCatalog({
    ...database,
    async connect() {
      const connection = await database.connect();
      return { release: (discard) => connection.release(discard), query: (sql, values) => query(connection, sql, values) };
    },
  });
}

const fixture = (month: string) => ({
  tournamentMonth: `2070-${month}-01`,
  name: 'Catalog fixture',
  registrationOpensAt: new Date(`2070-${month}-01T08:00:00Z`),
  registrationClosesAt: new Date(`2070-${month}-02T08:00:00Z`),
  startsAt: new Date(`2070-${month}-03T08:00:00Z`),
});

export async function testKnockoutTournamentCatalog(t: TestContext, database: Database) {
  const catalog = new KnockoutTournamentCatalog(database);

  await t.test('provisioning reuses an identical month and rejects changed metadata', async () => {
    const input = fixture('01');
    const first = await catalog.provision(input);
    assert.equal(first.status, 'unavailable');
    assert.deepEqual(await catalog.provision(input), first);
    await assert.rejects(catalog.provision({ ...input, name: 'Conflicting catalog fixture' }), { code: 'provisioningConflict' });
    await assert.rejects(catalog.provision({ ...input, startsAt: new Date('2070-01-04T08:00:00Z') }), { code: 'provisioningConflict' });
    const rows = (await database.query(`SELECT id, name, tournament_month::text
      FROM stoppy_knockout.tournaments WHERE tournament_month = $1`, [input.tournamentMonth])).rows;
    assert.deepEqual(rows, [{ id: first.id, name: input.name, tournament_month: input.tournamentMonth }]);
  });

  await t.test('concurrent identical provisions share an ID and concurrent conflicting provisions have one winner', async () => {
    const identical = await Promise.all(Array.from({ length: 4 }, () => catalog.provision(fixture('02'))));
    assert.equal(new Set(identical.map(({ id }) => id)).size, 1);
    const input = fixture('03');
    const attempts = await Promise.allSettled([catalog.provision(input), catalog.provision({ ...input, name: 'Another fixture' })]);
    assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1);
    const rejected = attempts.find((result) => result.status === 'rejected');
    assert.equal(rejected?.reason.code, 'provisioningConflict');
    assert.equal((await database.query(`SELECT id FROM stoppy_knockout.tournaments
      WHERE tournament_month = $1`, [input.tournamentMonth])).rows.length, 1);
  });

  await t.test('lifecycle permits only in-window opening and explicit closing, with idempotent repeats', async () => {
    const input = fixture('04');
    const { id } = await catalog.provision(input);
    let now = '2070-04-01T07:59:59.999999Z';
    // Pass an exact fixture time into PostgreSQL without altering the deployed
    // catalog interface or truncating the clock to JavaScript milliseconds.
    const clocked = catalogUsing(database, (connection, sql, values) => sql.startsWith('WITH transition_clock')
      ? connection.query(sql.replace('clock_timestamp()', '$2::timestamptz'), [values![0], now])
      : connection.query(sql, values));
    await assert.rejects(clocked.transition(id, 'registrationClosed'), { code: 'invalidTransition' });
    await assert.rejects(clocked.transition(id, 'registrationOpen'), { code: 'outsideRegistrationWindow' });
    now = '2070-04-02T08:00:00.000000Z';
    await assert.rejects(clocked.transition(id, 'registrationOpen'), { code: 'outsideRegistrationWindow' });
    now = '2070-04-01T08:00:00.000000Z';
    const opened = { id, status: 'registrationOpen' };
    assert.deepEqual(await clocked.transition(id, 'registrationOpen'), opened);
    assert.deepEqual(await clocked.transition(id, 'registrationOpen'), opened);
    assert.deepEqual(await catalog.provision(input), opened);
    const closed = { id, status: 'registrationClosed' };
    assert.deepEqual(await clocked.transition(id, 'registrationClosed'), closed);
    assert.deepEqual(await clocked.transition(id, 'registrationClosed'), closed);
    await assert.rejects(clocked.transition(id, 'registrationOpen'), { code: 'invalidTransition' });
    await assert.rejects(clocked.transition(randomUUID(), 'registrationOpen'), { code: 'notFound' });
  });

  await t.test('failed catalog writes roll back before a later explicit attempt', async () => {
    const input = fixture('05');
    const failing = catalogUsing(database, async (connection, sql, values) => {
      const result = await connection.query(sql, values);
      if (/^(INSERT INTO|UPDATE) stoppy_knockout.tournaments/.test(sql)) await connection.query('SELECT 1 / 0');
      return result;
    });
    await assert.rejects(failing.provision(input), { code: 'infrastructureFailure' });
    assert.equal((await database.query('SELECT id FROM stoppy_knockout.tournaments WHERE tournament_month = $1',
      [input.tournamentMonth])).rows.length, 0);
    const { id } = await catalog.provision(input);
    await database.query("UPDATE stoppy_knockout.tournaments SET status = 'registrationOpen' WHERE id = $1", [id]);
    await assert.rejects(failing.transition(id, 'registrationClosed'), { code: 'infrastructureFailure' });
    assert.deepEqual(await catalog.provision(input), { id, status: 'registrationOpen' });
    assert.deepEqual(await catalog.transition(id, 'registrationClosed'), { id, status: 'registrationClosed' });
  });

  for (const committed of [false, true]) {
    await t.test(`uncertain provision COMMIT (${committed ? 'persisted' : 'not sent'}) supports explicit recovery`, async () => {
      const input = fixture(committed ? '06' : '07');
      let commitAttempts = 0;
      const uncertain = catalogUsing(database, async (connection, sql, values) => {
        if (sql === 'COMMIT') {
          commitAttempts++;
          if (committed) await connection.query(sql, values);
          throw new Error('Lost acknowledgement with sensitive details.');
        }
        return connection.query(sql, values);
      });
      await assert.rejects(uncertain.provision(input), {
        code: 'commitOutcomeUnknown',
        message: 'Catalog commit is uncertain. Verify the catalog before retrying the same operation.',
      });
      assert.equal(commitAttempts, 1);
      const read = () => database.query(`SELECT id FROM stoppy_knockout.tournaments
        WHERE tournament_month = $1`, [input.tournamentMonth]);
      const { rows: before } = await read();
      assert.equal(before.length, committed ? 1 : 0);
      const { id } = await catalog.provision(input);
      if (committed) assert.equal(id, before[0]!.id);
      assert.deepEqual((await read()).rows, [{ id }]);
    });
  }

  await t.test('operator column grants permit catalog operations and deny other writes', async () => {
    const role = 'stoppy_catalog_test_' + randomUUID().replaceAll('-', '');
    const setRole = `SET LOCAL ROLE ${role}`;
    await database.query(`CREATE ROLE ${role}`);
    try {
      for (const grant of [
        'USAGE ON SCHEMA stoppy_knockout',
        'SELECT (id, tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status) ON stoppy_knockout.tournaments',
        'INSERT (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status) ON stoppy_knockout.tournaments',
        'UPDATE (status) ON stoppy_knockout.tournaments',
      ]) await database.query(`GRANT ${grant} TO ${role}`);

      const operator = catalogUsing(database, async (connection, sql, values) => {
        if (sql.startsWith('SET TRANSACTION')) {
          const result = await connection.query(sql);
          await connection.query(setRole);
          return result;
        }
        if (sql.startsWith('WITH transition_clock')) {
          return connection.query(sql.replace('clock_timestamp()', '$2::timestamptz'), [values![0], '2070-08-01T12:00:00Z']);
        }
        return connection.query(sql, values);
      });
      const input = fixture('08');
      const entry = await operator.provision(input);
      assert.deepEqual(await operator.provision(input), entry);
      assert.equal((await operator.transition(entry.id, 'registrationOpen')).status, 'registrationOpen');
      assert.equal((await operator.transition(entry.id, 'registrationClosed')).status, 'registrationClosed');
      for (const sql of [
        "UPDATE stoppy_knockout.tournaments SET name = 'Unauthorized'",
        'DELETE FROM stoppy_knockout.tournaments',
        'UPDATE stoppy_auth.players SET game_points = 0',
        'DELETE FROM stoppy_economy.gp_ledger',
        'DELETE FROM stoppy_knockout.registrations',
      ]) {
        await assert.rejects(inTransaction(database, async (connection) => {
          await connection.query(setRole);
          await connection.query(sql);
        }), { code: '42501' });
      }
    } finally {
      await database.query(`DROP OWNED BY ${role}`);
      await database.query(`DROP ROLE ${role}`);
    }
  });
}
