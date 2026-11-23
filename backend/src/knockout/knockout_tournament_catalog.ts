import type { Database, QueryConnection } from '../database.js';
import { inTransaction } from '../transaction.js';
import { tournamentMonthAt, tournamentMonthLabel } from './knockout_tournament_calendar.js';

export interface TournamentProvisioning {
  readonly tournamentMonth: string;
  readonly name: string;
  readonly registrationOpensAt: Date;
  readonly registrationClosesAt: Date;
  readonly startsAt: Date;
}

type RegistrationStatus = 'registrationOpen' | 'registrationClosed';
type CatalogStatus = 'unavailable' | RegistrationStatus | 'inProgress' | 'completed';
type CatalogEntry = { readonly id: string; readonly status: CatalogStatus };

export class KnockoutCatalogError extends Error {
  constructor(readonly code: 'invalidInput' | 'provisioningConflict' | 'notFound' | 'invalidTransition'
    | 'outsideRegistrationWindow' | 'infrastructureFailure' | 'commitOutcomeUnknown', message: string) {
    super(message);
  }
}

function instant(value: Date): string {
  if (!(value instanceof Date) || !Number.isFinite(value.getTime())
    || value.getUTCFullYear() < 1 || value.getUTCFullYear() > 9999) {
    throw new RangeError('Expected an absolute timestamp within the supported range.');
  }
  return value.toISOString();
}

function schedule(input: TournamentProvisioning) {
  try {
    const month = tournamentMonthLabel(input.tournamentMonth);
    const name = input.name.trim();
    if (!name || [...name].length > 128 || /\p{Cc}|\p{Cs}/u.test(name)) throw new RangeError();
    const opensAt = instant(input.registrationOpensAt);
    const closesAt = instant(input.registrationClosesAt);
    const startsAt = instant(input.startsAt);
    if (!(opensAt < closesAt && closesAt < startsAt) || tournamentMonthAt(new Date(startsAt)) !== month) {
      throw new RangeError();
    }
    return [month, name, opensAt, closesAt, startsAt];
  } catch {
    throw new KnockoutCatalogError('invalidInput', 'Invalid tournament month, name or schedule.');
  }
}

function entry(row: Record<string, unknown>): CatalogEntry {
  return { id: row.id as string, status: row.status as CatalogStatus };
}

/** Operator-only catalog writes using a separately privileged database connection. */
export class KnockoutTournamentCatalog {
  constructor(private readonly database: Database) {}

  async provision(input: TournamentProvisioning): Promise<CatalogEntry> {
    const values = schedule(input);
    return this.write(async (connection) => {
      // Only the insert sets the initial status. Retrying after a transition must
      // return the existing UUID and status without rewriting historical metadata.
      const inserted = (await connection.query(`INSERT INTO stoppy_knockout.tournaments
        (tournament_month, name, registration_opens_at, registration_closes_at, starts_at, status)
        VALUES ($1::date, $2, $3::timestamptz, $4::timestamptz, $5::timestamptz, 'unavailable')
        ON CONFLICT (tournament_month) DO NOTHING RETURNING id, status`, values)).rows[0];
      if (inserted) return entry(inserted);

      // READ COMMITTED gives this statement a fresh snapshot after a competing
      // insert commits. Compare instants in SQL to preserve existing microseconds.
      const existing = (await connection.query(`SELECT id, status,
        name = $2 AND registration_opens_at = $3::timestamptz
          AND registration_closes_at = $4::timestamptz AND starts_at = $5::timestamptz AS identical
        FROM stoppy_knockout.tournaments WHERE tournament_month = $1::date`, values)).rows[0];
      if (!existing?.identical) {
        throw new KnockoutCatalogError('provisioningConflict', 'Tournament month already has different provisioning parameters.');
      }
      return entry(existing);
    });
  }

  async transition(tournamentId: string, target: RegistrationStatus): Promise<CatalogEntry> {
    if (typeof tournamentId !== 'string' || !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(tournamentId)
      || (target !== 'registrationOpen' && target !== 'registrationClosed')) {
      throw new KnockoutCatalogError('invalidInput', 'Invalid tournament ID or unsupported lifecycle target.');
    }
    return this.write(async (connection) => {
      // Same lock key as registration's shared lock. Read the state and sample
      // the clock only after the lock wait, before making a lifecycle decision.
      await connection.query(`SELECT pg_advisory_xact_lock(
        hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))`, [tournamentId]);
      const current = (await connection.query(`WITH transition_clock AS MATERIALIZED (SELECT clock_timestamp() AS checked_at)
        SELECT id, status, checked_at >= registration_opens_at AND checked_at < registration_closes_at AS within_window
        FROM stoppy_knockout.tournaments CROSS JOIN transition_clock WHERE id = $1`, [tournamentId])).rows[0];
      if (!current) throw new KnockoutCatalogError('notFound', 'Tournament does not exist.');
      if (current.status === target) return entry(current);
      const requiredStatus = target === 'registrationOpen' ? 'unavailable' : 'registrationOpen';
      if (current.status !== requiredStatus) {
        throw new KnockoutCatalogError('invalidTransition', 'Tournament cannot enter the requested state.');
      }
      if (target === 'registrationOpen' && current.within_window !== true) {
        throw new KnockoutCatalogError('outsideRegistrationWindow', 'Tournament is outside its registration window.');
      }
      const updated = (await connection.query(`UPDATE stoppy_knockout.tournaments
        SET status = $2 WHERE id = $1 AND status = $3 RETURNING id, status`, [tournamentId, target, requiredStatus])).rows[0];
      if (!updated) throw new KnockoutCatalogError('invalidTransition', 'Tournament state changed during the transition.');
      return entry(updated);
    });
  }

  private async write(operation: (connection: QueryConnection) => Promise<CatalogEntry>): Promise<CatalogEntry> {
    let readyToCommit = false;
    try {
      return await inTransaction(this.database, async (connection) => {
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const result = await operation(connection);
        readyToCommit = true;
        return result;
      });
    } catch (error) {
      if (error instanceof KnockoutCatalogError) throw error;
      if (readyToCommit) {
        throw new KnockoutCatalogError('commitOutcomeUnknown', 'Catalog commit is uncertain. Verify the catalog before retrying the same operation.');
      }
      throw new KnockoutCatalogError('infrastructureFailure', 'Tournament catalog operation failed.');
    }
  }
}
