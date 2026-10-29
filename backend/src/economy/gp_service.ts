import { randomUUID } from 'node:crypto';
import type { Database } from '../database.js';
import { inTransaction } from '../transaction.js';
import { gpFingerprintVersion, gpIntegerMax, prepareGpIntent, type GpCommand } from './gp_intent.js';
import { GpRepository, type GpOutcome } from './gp_repository.js';

export type GpExecutionResult =
  | { readonly status: 'completed'; readonly replayed: boolean; readonly outcome: GpOutcome; readonly currentBalance: number }
  | { readonly status: 'idempotencyConflict'; readonly currentBalance: number }
  | { readonly status: 'missingPlayer' };

export class GpExecutionFailure extends Error {
  constructor(readonly code: 'infrastructureFailure' | 'commitOutcomeUnknown') {
    // Never surface SQL, credentials or driver diagnostics to a future route.
    super(code === 'commitOutcomeUnknown' ? 'GP commit outcome is unknown. Retry explicitly with the same intent and key.' : 'GP execution is unavailable.');
  }
}

/** Trusted server-only primitive. Authentication/eligibility and reward amounts
 * must be established by a business service, never asserted by a client. */
export class GpService {
  constructor(private readonly database: Database) {}

  credit(command: GpCommand): Promise<GpExecutionResult> { return this.execute(command, 'credit'); }
  debit(command: GpCommand): Promise<GpExecutionResult> { return this.execute(command, 'debit'); }

  private async execute(input: GpCommand, direction: 'credit' | 'debit'): Promise<GpExecutionResult> {
    const { command, fingerprint } = prepareGpIntent(input, direction);
    let readyToCommit = false;
    try {
      return await inTransaction(this.database, async (connection) => {
        // One player lock first, then mutation/source reads, then writes. READ
        // COMMITTED ensures a waiter sees its predecessor's durable final result.
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const repository = new GpRepository(connection);
        const balance = await repository.lockBalance(command.playerId);
        const finish = (result: GpExecutionResult) => { readyToCommit = true; return result; };
        if (balance === null) return finish({ status: 'missingPlayer' });
        const previous = await repository.findMutation(command);
        if (previous) {
          if (previous.fingerprintVersion !== gpFingerprintVersion || previous.fingerprint !== fingerprint) {
            return finish({ status: 'idempotencyConflict', currentBalance: balance });
          }
          // Historical outcome is immutable; currentBalance is a separate read.
          return finish({ status: 'completed', replayed: true, outcome: previous.outcome, currentBalance: balance });
        }
        // Never invent an earned credit or silently repair a missing audit
        // baseline: registration now creates it atomically with the account.
        if (!await repository.hasOpeningSnapshot(command.playerId)) throw new Error('GP opening snapshot is missing.');
        let rejection: Extract<GpOutcome, { status: 'rejected' }>['reason'] | undefined;
        if (await repository.findSource(command)) rejection = 'duplicateSource';
        else if (direction === 'debit' && command.amount > balance) rejection = 'insufficientFunds';
        else if (direction === 'credit' && command.amount > gpIntegerMax - balance) rejection = 'balanceOverflow';
        const mutationId = randomUUID();
        let outcome: GpOutcome;
        let currentBalance = balance;
        if (rejection) {
          outcome = { status: 'rejected', mutationId, reason: rejection, balance };
          await repository.storeMutation(command, fingerprint, outcome);
        } else {
          const delta = direction === 'credit' ? command.amount : -command.amount;
          currentBalance = await repository.applyDelta(command.playerId, balance, delta);
          outcome = { status: 'accepted', mutationId, ledgerId: randomUUID(), delta,
            balanceBefore: balance, balanceAfter: currentBalance };
          // Migration 003's immediate FK requires the final accepted record
          // before its ledger row. Neither is visible until this commit succeeds.
          await repository.storeMutation(command, fingerprint, outcome);
          await repository.storeMovement(command, outcome);
        }
        return finish({ status: 'completed', replayed: false, outcome, currentBalance });
      });
    } catch {
      // No automatic replay, including when COMMIT may already have persisted.
      // Existing transaction utility discards an uncertain connection exactly once.
      throw new GpExecutionFailure(readyToCommit ? 'commitOutcomeUnknown' : 'infrastructureFailure');
    }
  }
}
