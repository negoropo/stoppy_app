import type { QueryConnection } from '../database.js';
import { gpFingerprintVersion, type GpCommand } from './gp_intent.js';

export type GpOutcome =
  | { readonly status: 'accepted'; readonly mutationId: string; readonly ledgerId: string;
      readonly delta: number; readonly balanceBefore: number; readonly balanceAfter: number }
  | { readonly status: 'rejected'; readonly mutationId: string;
      readonly reason: 'insufficientFunds' | 'balanceOverflow' | 'duplicateSource'; readonly balance: number };

export interface StoredGpMutation { readonly fingerprintVersion: number; readonly fingerprint: string; readonly outcome: GpOutcome }

/** Transaction-bound only: no pool, transaction ownership, retry or profile writes. */
export class GpRepository {
  constructor(private readonly connection: QueryConnection) {}

  /** Called only inside account creation: observe the DB default, never earn it.
   * Do not suppress duplicates; a conflicting baseline must abort registration. */
  async createOpeningSnapshot(playerId: string): Promise<void> {
    const result = await this.connection.query(`INSERT INTO stoppy_economy.gp_ledger
      (player_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      SELECT id, 'opening_snapshot', 'opening_snapshot', 'opening_snapshot', id::text, 0, game_points, game_points
      FROM stoppy_auth.players WHERE id = $1 RETURNING id`, [playerId]);
    if (!result.rows[0]) throw new Error('GP opening snapshot requires an existing player.');
  }

  async lockBalance(playerId: string): Promise<number | null> {
    const result = await this.connection.query('SELECT game_points FROM stoppy_auth.players WHERE id = $1 FOR UPDATE', [playerId]);
    return result.rows[0] ? result.rows[0].game_points as number : null;
  }

  async findMutation(command: GpCommand): Promise<StoredGpMutation | null> {
    const result = await this.connection.query(`SELECT fingerprint_version, request_fingerprint, semantic_outcome
      FROM stoppy_economy.gp_mutations WHERE player_id = $1 AND operation_name = $2
      AND operation_version = $3 AND idempotency_key = $4`,
    [command.playerId, command.operationName, command.operationVersion, command.idempotencyKey]);
    const row = result.rows[0];
    return row ? { fingerprintVersion: row.fingerprint_version as number,
      fingerprint: row.request_fingerprint as string, outcome: row.semantic_outcome as GpOutcome } : null;
  }

  async hasOpeningSnapshot(playerId: string): Promise<boolean> {
    const result = await this.connection.query(`SELECT id FROM stoppy_economy.gp_ledger
      WHERE player_id = $1 AND movement_type = 'opening_snapshot'`, [playerId]);
    return result.rows.length !== 0;
  }

  async findSource(command: GpCommand): Promise<string | null> {
    const result = await this.connection.query(`SELECT id FROM stoppy_economy.gp_ledger
      WHERE player_id = $1 AND source_type = $2 AND source_id = $3`, [command.playerId, command.sourceType, command.sourceId]);
    return result.rows[0] ? result.rows[0].id as string : null;
  }

  async applyDelta(playerId: string, before: number, delta: number): Promise<number> {
    // Widen before addition so PostgreSQL never evaluates overflowing int4 math.
    // The before guard is defensive; the service must already hold the player lock.
    const result = await this.connection.query(`UPDATE stoppy_auth.players
      SET game_points = (game_points::bigint + $3::bigint)::integer
      WHERE id = $1 AND game_points = $2 AND game_points::bigint + $3::bigint BETWEEN 0 AND 2147483647
      RETURNING game_points`, [playerId, before, delta]);
    if (!result.rows[0]) throw new Error('GP balance update invariant failed.');
    return result.rows[0].game_points as number;
  }

  async storeMutation(command: GpCommand, fingerprint: string, outcome: GpOutcome): Promise<void> {
    await this.connection.query(`INSERT INTO stoppy_economy.gp_mutations
      (id, player_id, operation_name, operation_version, idempotency_key, fingerprint_version,
       request_fingerprint, outcome_status, semantic_outcome, resolved_context)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10::jsonb)`,
    [outcome.mutationId, command.playerId, command.operationName, command.operationVersion, command.idempotencyKey,
      gpFingerprintVersion, fingerprint, outcome.status, JSON.stringify(outcome), JSON.stringify(command.context)]);
  }

  async storeMovement(command: GpCommand, outcome: Extract<GpOutcome, { status: 'accepted' }>): Promise<void> {
    await this.connection.query(`INSERT INTO stoppy_economy.gp_ledger
      (id, player_id, mutation_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [outcome.ledgerId, command.playerId, outcome.mutationId, outcome.delta > 0 ? 'credit' : 'debit',
      command.reason, command.sourceType, command.sourceId, outcome.delta, outcome.balanceBefore, outcome.balanceAfter]);
  }
}
