import { ApiError } from '../api_error.js';
import type { PlayerProfile } from '../auth/auth_repository.js';
import { unauthenticated } from '../auth/auth_validation.js';
import type { QueryConnection } from '../database.js';
import type { RegistrationIntent } from './knockout_registration_repository.js';
import type { KnockoutRegistrationResult } from './knockout_registration_service.js';

export function registrationUnavailable(reason: 'infrastructureFailure' | 'commitOutcomeUnknown') {
  return new ApiError('serverError', reason === 'commitOutcomeUnknown'
    ? 'Registration outcome is unknown. Retry with the same tournament and key.'
    : 'Registration could not be verified. Retry with the same tournament and key.', 503, { reason });
}

export async function registrationResponse(database: QueryConnection, intent: RegistrationIntent,
  result: KnockoutRegistrationResult, readProfile: () => Promise<PlayerProfile>) {
  if (result.status === 'missingPlayer') throw unauthenticated();
  if (result.status === 'idempotencyConflict') {
    throw new ApiError('conflict', 'Idempotency key conflicts with the original registration attempt.', 409,
      { reason: 'idempotencyConflict' });
  }

  const { outcome, replayed } = result;
  // An absent catalog row has a null outcome FK. Echo the validated correlation
  // ID on a rejection without suggesting the row exists or inventing metadata.
  const correlation = { playerId: intent.playerId, tournamentId: intent.tournamentId };
  if (outcome.status === 'rejected') {
    return { ...correlation, status: 'rejected', newlyPersisted: false, replayed, rejectionCode: outcome.reason } as const;
  }

  const row = (await database.query(`SELECT t.id, t.name, t.status, to_char(t.tournament_month, 'YYYY-MM-DD') AS month,
    to_char(t.registration_opens_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS opens_at,
    to_char(t.registration_closes_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS closes_at,
    to_char(t.starts_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS starts_at,
    to_char(r.registered_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS registered_at,
    -r.fee_delta AS fee
    FROM stoppy_knockout.registrations r JOIN stoppy_knockout.tournaments t ON t.id = r.tournament_id
    WHERE r.id = $1 AND r.player_id = $2 AND r.tournament_id = $3`,
  [outcome.registrationId, intent.playerId, intent.tournamentId])).rows[0];
  if (!row) throw registrationUnavailable('infrastructureFailure');

  // The mutation has committed. A new authenticated read samples the wallet
  // independently of the immutable balance stored with the original debit.
  const playerProfile = await readProfile();
  if (playerProfile.id !== intent.playerId) throw unauthenticated();
  return {
    ...correlation,
    status: replayed ? 'idempotentReplay' : 'accepted',
    newlyPersisted: !replayed,
    replayed,
    tournament: {
      id: row.id, name: row.name, status: row.status, tournamentMonth: row.month, entryCostGamePoints: row.fee,
      registrationOpensAt: row.opens_at, registrationClosesAt: row.closes_at, startsAt: row.starts_at,
    },
    playerEntry: {
      ...correlation, username: playerProfile.username, accountCreatedAt: playerProfile.createdAt,
      registeredAt: row.registered_at, entryCostGamePoints: row.fee,
    },
    historicalRemainingGamePoints: outcome.remainingGamePoints,
    playerProfile,
  } as const;
}
