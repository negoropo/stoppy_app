import { randomUUID } from 'node:crypto';
import type { QueryConnection } from '../database.js';
import { gpFingerprintVersion, gpIntegerMax, prepareGpIntent, type GpCommand } from './gp_intent.js';
import { GpRepository, type GpOutcome } from './gp_repository.js';

export type GpExecutionResult =
  | { readonly status: 'completed'; readonly replayed: boolean; readonly outcome: GpOutcome; readonly currentBalance: number }
  | { readonly status: 'idempotencyConflict'; readonly currentBalance: number }
  | { readonly status: 'missingPlayer' };

/** Caller owns an active READ COMMITTED transaction, isolation setup and cleanup.
 * Acquire any catalog locks before calling; this executor then locks the player.
 * Await calls sequentially; propagate errors to the outer rollback, never catch
 * an execution failure and commit remaining writes. Results are provisional
 * until the caller commits. No transaction control, connection acquisition or retry. */
export class GpExecutor {
  constructor(private readonly connection: QueryConnection) {}

  credit(command: GpCommand): Promise<GpExecutionResult> { return this.execute(command, 'credit'); }
  debit(command: GpCommand): Promise<GpExecutionResult> { return this.execute(command, 'debit'); }

  private async execute(input: GpCommand, direction: 'credit' | 'debit'): Promise<GpExecutionResult> {
    const { command, fingerprint } = prepareGpIntent(input, direction);
    const connection = this.connection;
    const repository = new GpRepository(connection);
    const balance = await repository.lockBalance(command.playerId);
    if (balance === null) return { status: 'missingPlayer' };
    const previous = await repository.findMutation(command);
    if (previous) {
      if (previous.fingerprintVersion !== gpFingerprintVersion || previous.fingerprint !== fingerprint) {
        return { status: 'idempotencyConflict', currentBalance: balance };
      }
      // Historical outcome is immutable; currentBalance is a separate read.
      return { status: 'completed', replayed: true, outcome: previous.outcome, currentBalance: balance };
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
    return { status: 'completed', replayed: false, outcome, currentBalance };
  }
}
