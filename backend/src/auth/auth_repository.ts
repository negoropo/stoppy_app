import type { Database, QueryConnection } from '../database.js';
import { inTransaction } from '../transaction.js';
import { ApiError } from '../api_error.js';
import type { SessionPayload } from './token_service.js';

export interface PlayerProfile {
  id: string; username: string; createdAt: string; gamePoints: number; adsRemoved: boolean;
  lastDailyGpAwardedAt: string | null; currentLeagueDivision: number | null;
  hasWeeklyLeagueEntry: boolean; reservedLeagueSlot: boolean;
}
export interface NewSession {
  id: string; playerId: string; tokenId: string; digest: string; createdAt: Date; expiresAt: Date;
}
export interface AccountCredentials { profile: PlayerProfile; passwordHash: string }
export interface AuthRepository {
  register(id: string, username: string, passwordHash: string, session: NewSession): Promise<PlayerProfile>;
  findCredentials(canonicalUsername: string): Promise<AccountCredentials | null>;
  createSession(session: NewSession): Promise<void>;
  rotate(digest: string, replacementId: string, replacementDigest: string,
    issue: (playerId: string, sessionId: string, now: Date, expiresAt: Date) => Promise<SessionPayload>): Promise<SessionPayload | null>;
  authenticatedProfile(playerId: string, sessionId: string): Promise<PlayerProfile | null>;
}

function profile(row: Record<string, unknown>): PlayerProfile {
  return {
    id: row.id as string, username: row.username as string, createdAt: (row.created_at as Date).toISOString(),
    gamePoints: row.game_points as number, adsRemoved: row.ads_removed as boolean,
    lastDailyGpAwardedAt: row.last_daily_gp_awarded_at ? (row.last_daily_gp_awarded_at as Date).toISOString() : null,
    currentLeagueDivision: row.current_league_division as number | null,
    hasWeeklyLeagueEntry: row.has_weekly_league_entry as boolean, reservedLeagueSlot: row.reserved_league_slot as boolean,
  };
}

async function insertSession(connection: QueryConnection, session: NewSession): Promise<void> {
  await connection.query(`INSERT INTO stoppy_auth.auth_sessions (id, player_id, created_at, expires_at)
    VALUES ($1, $2, $3, $4)`, [session.id, session.playerId, session.createdAt, session.expiresAt]);
  await connection.query(`INSERT INTO stoppy_auth.auth_refresh_tokens (id, session_id, token_digest, created_at, expires_at)
    VALUES ($1, $2, $3, $4, $5)`, [session.tokenId, session.id, session.digest, session.createdAt, session.expiresAt]);
}

export class PostgresAuthRepository implements AuthRepository {
  constructor(private readonly database: Database, private readonly now: () => Date = () => new Date()) {}

  async register(id: string, username: string, passwordHash: string, session: NewSession): Promise<PlayerProfile> {
    try {
      return await inTransaction(this.database, async (connection) => {
        const result = await connection.query(`INSERT INTO stoppy_auth.players (id, username, password_hash, created_at)
          VALUES ($1, $2, $3, $4) RETURNING *`, [id, username, passwordHash, session.createdAt]);
        await insertSession(connection, session);
        return profile(result.rows[0]!);
      });
    } catch (error) {
      if (error && typeof error === 'object' && 'code' in error && error.code === '23505' &&
          'constraint' in error && error.constraint === 'players_canonical_username_key') {
        throw new ApiError('conflict', 'Username is already taken.', 409);
      }
      throw error;
    }
  }

  async findCredentials(canonicalUsername: string): Promise<AccountCredentials | null> {
    const result = await this.database.query('SELECT * FROM stoppy_auth.players WHERE canonical_username = $1', [canonicalUsername]);
    const row = result.rows[0];
    return row ? { profile: profile(row), passwordHash: row.password_hash as string } : null;
  }

  async createSession(session: NewSession): Promise<void> {
    await inTransaction(this.database, (connection) => insertSession(connection, session));
  }

  async rotate(digest: string, replacementId: string, replacementDigest: string,
    issue: (playerId: string, sessionId: string, now: Date, expiresAt: Date) => Promise<SessionPayload>): Promise<SessionPayload | null> {
    return inTransaction(this.database, async (connection) => {
      // Serialize every rotation/replay in the same family, not just a single token.
      const sessions = await connection.query(`SELECT s.* FROM stoppy_auth.auth_sessions s
        JOIN stoppy_auth.auth_refresh_tokens t ON t.session_id = s.id WHERE t.token_digest = $1 FOR UPDATE OF s`, [digest]);
      const session = sessions.rows[0];
      const now = this.now();
      if (!session || session.revoked_at || (session.expires_at as Date) <= now) return null;
      // Re-read after acquiring the family lock: a concurrent request may have consumed it.
      const tokens = await connection.query('SELECT * FROM stoppy_auth.auth_refresh_tokens WHERE token_digest = $1', [digest]);
      const token = tokens.rows[0]!;
      // Persisted state is a lower bound for lifecycle writes when host clocks
      // move backwards. Keep wall-clock JWT issuance separate: advancing its iat
      // into the future would make the issuing host reject its own access token.
      const changedAt = new Date(Math.max(now.getTime(), (session.created_at as Date).getTime(),
        (token.created_at as Date).getTime(), (token.consumed_at as Date | null)?.getTime() ?? 0));
      if (token.consumed_at) {
        // Return rejection AFTER commit, otherwise throwing here would undo revocation.
        await connection.query('UPDATE stoppy_auth.auth_sessions SET revoked_at = $1 WHERE id = $2', [changedAt, session.id]);
        return null;
      }
      // Never create a replacement at/after expiry, even if persisted time is
      // ahead of this host. The family's original expiration is not extended.
      if ((token.expires_at as Date) <= changedAt || (session.expires_at as Date) <= changedAt) return null;
      const response = await issue(session.player_id as string, session.id as string, now, session.expires_at as Date);
      await connection.query('UPDATE stoppy_auth.auth_refresh_tokens SET consumed_at = $1 WHERE id = $2', [changedAt, token.id]);
      await connection.query(`INSERT INTO stoppy_auth.auth_refresh_tokens (id, session_id, token_digest, created_at, expires_at)
        VALUES ($1, $2, $3, $4, $5)`, [replacementId, session.id, replacementDigest, changedAt, session.expires_at]);
      await connection.query('UPDATE stoppy_auth.auth_refresh_tokens SET replaced_by = $1 WHERE id = $2', [replacementId, token.id]);
      return response;
    });
  }

  async authenticatedProfile(playerId: string, sessionId: string): Promise<PlayerProfile | null> {
    const result = await this.database.query(`SELECT p.* FROM stoppy_auth.players p
      JOIN stoppy_auth.auth_sessions s ON s.player_id = p.id
      WHERE p.id = $1 AND s.id = $2 AND s.revoked_at IS NULL AND s.expires_at > $3`, [playerId, sessionId, this.now()]);
    return result.rows[0] ? profile(result.rows[0]) : null;
  }
}
