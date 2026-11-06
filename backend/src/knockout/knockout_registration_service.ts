import { createHash } from 'node:crypto';
import type { Database } from '../database.js';
import { inTransaction } from '../transaction.js';
import { canonicalIntent } from '../economy/gp_intent.js';
import { GpExecutor } from '../economy/gp_executor.js';
import { GpRepository } from '../economy/gp_repository.js';
import { KnockoutRegistrationRepository, registrationFingerprintVersion, registrationOperation, registrationVersion,
  type RegistrationIntent, type RegistrationOutcome, type RegistrationRejection } from './knockout_registration_repository.js';

// Monthly entry is a fixed server rule, never a caller-supplied amount/balance.
const registrationFee = 25;

export type KnockoutRegistrationResult =
  | { readonly status: 'completed'; readonly replayed: boolean; readonly outcome: RegistrationOutcome }
  | { readonly status: 'idempotencyConflict' }
  | { readonly status: 'missingPlayer' };

export class InvalidKnockoutRegistrationIntent extends Error {
  constructor() { super('Invalid internal Knockout registration intent.'); }
}

export class KnockoutRegistrationFailure extends Error {
  constructor(readonly code: 'infrastructureFailure' | 'commitOutcomeUnknown') {
    super(code === 'commitOutcomeUnknown'
      ? 'Knockout registration commit outcome is unknown. Retry explicitly with the same intent and key.'
      : 'Knockout registration is unavailable.');
  }
}

function prepare(input: RegistrationIntent) {
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  if (!input || typeof input.playerId !== 'string' || !uuid.test(input.playerId)
    || typeof input.tournamentId !== 'string' || !uuid.test(input.tournamentId)
    || typeof input.idempotencyKey !== 'string' || input.idempotencyKey.length < 1 || input.idempotencyKey.length > 128
    || /[^A-Za-z0-9._:-]/.test(input.idempotencyKey)) throw new InvalidKnockoutRegistrationIntent();
  const command = { playerId: input.playerId, tournamentId: input.tournamentId, idempotencyKey: input.idempotencyKey };
  const fingerprint = createHash('sha256').update(canonicalIntent({ format: 'stoppy.knockout.registration',
    version: registrationFingerprintVersion, operation: registrationOperation, operationVersion: registrationVersion,
    playerId: command.playerId, tournamentId: command.tournamentId })).digest('hex');
  // A domain-separated UUIDv8 is a business identifier, NOT an authentication
  // credential. Determinism keeps the complete financial intent unchanged even
  // if a COMMIT acknowledgement is lost and the original transaction rolled back.
  const bytes = createHash('sha256').update(canonicalIntent({ format: 'stoppy.knockout.registration.id',
    version: 1, fingerprint, key: command.idempotencyKey })).digest().subarray(0, 16);
  bytes[6] = (bytes[6]! & 0x0f) | 0x80;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  const registrationId = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  return { command, fingerprint, registrationId };
}

/** Internal only: playerId comes from verified server authentication, tournamentId
 * from trusted resolution. This is not a public request body or tournament resolver. */
export class KnockoutRegistrationService {
  constructor(private readonly database: Database) {}

  async register(input: RegistrationIntent): Promise<KnockoutRegistrationResult> {
    const { command, fingerprint, registrationId } = prepare(input);
    let readyToCommit = false;
    try {
      return await inTransaction(this.database, async (connection) => {
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const repository = new KnockoutRegistrationRepository(connection);
        // Catalog advisory lock -> player row -> operation/registration -> writes.
        // Rejection/replay paths also need the player lock; the executor reuses
        // that same row lock on this connection, without a second transaction.
        const tournament = await repository.lockTournament(command.tournamentId);
        const balance = await new GpRepository(connection).lockBalance(command.playerId);
        let result: KnockoutRegistrationResult;
        if (balance === null) result = { status: 'missingPlayer' };
        else {
          const previous = await repository.findOperation(command);
          if (previous) {
            result = previous.fingerprintVersion === registrationFingerprintVersion && previous.fingerprint === fingerprint
              ? { status: 'completed', replayed: true, outcome: previous.outcome }
              : { status: 'idempotencyConflict' };
          } else {
            const admission = await repository.admissionState(command.tournamentId);
            let rejection: RegistrationRejection | undefined;
            if (!tournament || tournament.status === 'unavailable') rejection = 'tournamentUnavailable';
            else if (admission.started || ['inProgress', 'completed'].includes(tournament.status)) rejection = 'tournamentAlreadyStarted';
            else if (tournament.status !== 'registrationOpen' || !admission.withinWindow) rejection = 'registrationClosed';
            else if (await repository.hasRegistration(command)) rejection = 'duplicateRegistration';
            let outcome: RegistrationOutcome;
            if (rejection) {
              outcome = { status: 'rejected', tournamentId: tournament?.id ?? null, reason: rejection, remainingGamePoints: balance };
            } else {
              const financial = await new GpExecutor(connection).debit({ playerId: command.playerId,
                operationName: 'knockout_registration_fee', operationVersion: registrationVersion,
                idempotencyKey: command.idempotencyKey, amount: registrationFee, reason: 'knockout_registration',
                sourceType: 'knockout_registration', sourceId: `${command.tournamentId}:${registrationId}`,
                context: { businessOperation: registrationOperation, businessVersion: registrationVersion,
                  tournamentId: command.tournamentId, registrationId } });
              if (financial.status !== 'completed') throw new Error('Unexpected financial operation state.');
              if (financial.outcome.status === 'rejected') {
                if (financial.outcome.reason !== 'insufficientFunds') throw new Error('Unexpected financial rejection.');
                outcome = { status: 'rejected', tournamentId: command.tournamentId, reason: 'insufficientGp', remainingGamePoints: financial.outcome.balance };
              } else {
                const registeredAt = await repository.insertRegistration(command, registrationId, financial.outcome.ledgerId, financial.outcome.mutationId, admission.admittedAt);
                outcome = { status: 'accepted', tournamentId: command.tournamentId, registrationId,
                  registeredAt: registeredAt.toISOString(), remainingGamePoints: financial.outcome.balanceAfter };
              }
            }
            await repository.storeOutcome(command, fingerprint, outcome, admission.admittedAt);
            result = { status: 'completed', replayed: false, outcome };
          }
        }
        readyToCommit = true;
        return result;
      });
    } catch {
      // Never retry, never leak driver details, and never call an uncertain
      // commit a definitive failure. Recovery is an explicit same-intent/key call.
      throw new KnockoutRegistrationFailure(readyToCommit ? 'commitOutcomeUnknown' : 'infrastructureFailure');
    }
  }
}
