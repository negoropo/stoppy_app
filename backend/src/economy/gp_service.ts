import type { Database } from '../database.js';
import { inTransaction } from '../transaction.js';
import { prepareGpIntent, type GpCommand } from './gp_intent.js';
import { GpExecutor, type GpExecutionResult } from './gp_executor.js';

export type { GpExecutionResult } from './gp_executor.js';

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
    // Snapshot and validate before acquisition; the executor also validates direct callers.
    const { command } = prepareGpIntent(input, direction);
    let readyToCommit = false;
    try {
      return await inTransaction(this.database, async (connection) => {
        // One player lock first, then mutation/source reads, then writes. READ
        // COMMITTED ensures a waiter sees its predecessor's durable final result.
        await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
        const result = await new GpExecutor(connection)[direction](command);
        readyToCommit = true;
        return result;
      });
    } catch {
      // No automatic replay, including when COMMIT may already have persisted.
      // Existing transaction utility discards an uncertain connection exactly once.
      throw new GpExecutionFailure(readyToCommit ? 'commitOutcomeUnknown' : 'infrastructureFailure');
    }
  }
}
