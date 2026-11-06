import type { QueryConnection } from '../database.js';

export type RegistrationRejection = 'insufficientGp' | 'duplicateRegistration' | 'tournamentUnavailable'
  | 'registrationClosed' | 'tournamentAlreadyStarted';
export type RegistrationOutcome =
  | { readonly status: 'accepted'; readonly tournamentId: string; readonly registrationId: string;
      readonly registeredAt: string; readonly remainingGamePoints: number }
  | { readonly status: 'rejected'; readonly tournamentId: string | null; readonly reason: RegistrationRejection;
      readonly remainingGamePoints: number };

export interface RegistrationIntent {
  readonly playerId: string;
  readonly tournamentId: string;
  readonly idempotencyKey: string;
}

export const registrationOperation = 'knockout_register';
export const registrationVersion = 1;
export const registrationFingerprintVersion = 1;

/** Transaction-bound persistence only. Lifecycle writers must take the exclusive
 * form of this same advisory lock BEFORE changing/deleting catalog state.
 * Hash collisions only serialize unrelated tournaments; they cannot admit a player. */
export class KnockoutRegistrationRepository {
  constructor(private readonly connection: QueryConnection) {}

  async lockTournament(tournamentId: string) {
    await this.connection.query(`SELECT pg_advisory_xact_lock_shared(
      hashtextextended('stoppy.knockout.tournament:' || $1::text, 0))`, [tournamentId]);
    const row = (await this.connection.query(`SELECT id, status
      FROM stoppy_knockout.tournaments WHERE id = $1`, [tournamentId])).rows[0];
    return row ? { id: row.id as string, status: row.status as string } : null;
  }

  async findOperation(input: RegistrationIntent) {
    const row = (await this.connection.query(`SELECT fingerprint_version, request_fingerprint, semantic_outcome
      FROM stoppy_knockout.registration_operations WHERE player_id = $1 AND operation_name = $2
      AND operation_version = $3 AND idempotency_key = $4`,
    [input.playerId, registrationOperation, registrationVersion, input.idempotencyKey])).rows[0];
    return row ? { fingerprintVersion: row.fingerprint_version as number,
      fingerprint: row.request_fingerprint as string, outcome: row.semantic_outcome as RegistrationOutcome } : null;
  }

  async hasRegistration(input: RegistrationIntent): Promise<boolean> {
    return (await this.connection.query(`SELECT id FROM stoppy_knockout.registrations
      WHERE player_id = $1 AND tournament_id = $2`, [input.playerId, input.tournamentId])).rows.length !== 0;
  }

  async admissionState(tournamentId: string) {
    // CURRENT_TIMESTAMP is transaction-start time and becomes stale while waiting
    // on a player lock. Admission uses a fresh database instant after all waits.
    // Compare in PostgreSQL too: converting microsecond boundaries to JS Date
    // first would truncate them to milliseconds and could admit too early.
    const row = (await this.connection.query(`WITH admission_clock AS MATERIALIZED (SELECT clock_timestamp() AS admission_time)
      SELECT admission_time::text AS admitted_at, admission_time >= starts_at AS started,
        admission_time >= registration_opens_at AND admission_time < registration_closes_at AS within_window
      FROM admission_clock LEFT JOIN stoppy_knockout.tournaments ON id = $1`, [tournamentId])).rows[0]!;
    // Keep the database text representation: passing through JS Date would lose
    // microseconds before this same logical instant is persisted by both inserts.
    return { admittedAt: row.admitted_at as string, started: row.started === true, withinWindow: row.within_window === true };
  }

  async insertRegistration(input: RegistrationIntent, registrationId: string, ledgerId: string, mutationId: string, admittedAt: string): Promise<Date> {
    const row = (await this.connection.query(`INSERT INTO stoppy_knockout.registrations
      (id, player_id, tournament_id, gp_ledger_id, gp_mutation_id, registered_at)
      VALUES ($1, $2, $3, $4, $5, $6::timestamptz) RETURNING registered_at`,
    [registrationId, input.playerId, input.tournamentId, ledgerId, mutationId, admittedAt])).rows[0]!;
    return row.registered_at as Date;
  }

  async storeOutcome(input: RegistrationIntent, fingerprint: string, outcome: RegistrationOutcome, admittedAt: string) {
    // Creation is the admission decision, not BEGIN. Completion samples only
    // finalization, never eligibility; clamp it against a backward clock step.
    await this.connection.query(`INSERT INTO stoppy_knockout.registration_operations
      (player_id, operation_name, operation_version, idempotency_key, fingerprint_version, request_fingerprint,
       tournament_id, outcome_status, registration_id, rejection_reason, semantic_outcome, created_at, completed_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb,
        $12::timestamptz, GREATEST($12::timestamptz, clock_timestamp()))`,
    [input.playerId, registrationOperation, registrationVersion, input.idempotencyKey, registrationFingerprintVersion,
      fingerprint, outcome.tournamentId, outcome.status, outcome.status === 'accepted' ? outcome.registrationId : null,
      outcome.status === 'rejected' ? outcome.reason : null, JSON.stringify(outcome), admittedAt]);
  }
}
