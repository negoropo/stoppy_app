import { ApiError } from '../api_error.js';
import type { QueryConnection } from '../database.js';
import { knockoutRegistrationFee } from './knockout_registration_service.js';

const clock = 'read_clock AS MATERIALIZED (SELECT clock_timestamp() AS sampled_at)';
const windowOpen = `(t.status = 'registrationOpen'
  AND c.sampled_at >= t.registration_opens_at AND c.sampled_at < t.registration_closes_at)`;
const utcFormat = 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"';
const metadataColumns = `t.id, t.name, t.status, to_char(t.tournament_month, 'YYYY-MM-DD') AS month,
  to_char(t.registration_opens_at AT TIME ZONE 'UTC', '${utcFormat}') AS opens_at,
  to_char(t.registration_closes_at AT TIME ZONE 'UTC', '${utcFormat}') AS closes_at,
  to_char(t.starts_at AT TIME ZONE 'UTC', '${utcFormat}') AS starts_at`;

function metadata(row: Record<string, unknown>) {
  return {
    id: row.id, name: row.name, status: row.status, tournamentMonth: row.month,
    registrationOpensAt: row.opens_at, registrationClosesAt: row.closes_at, startsAt: row.starts_at,
    entryCostGamePoints: knockoutRegistrationFee, registrationWindowOpen: row.window_open,
  };
}

function missingTournament(): never {
  throw new ApiError('notFound', 'Knockout tournament was not found.', 404);
}

/** Registration-facing reads over the catalog and paid-entry evidence only. */
export class KnockoutReadRepository {
  constructor(private readonly database: QueryConnection) {}

  async discover() {
    // Sample once for both slots. The first-of-month DATE is a Lisbon label,
    // while eligibility and upcoming order compare absolute instants.
    const { rows } = await this.database.query(`WITH ${clock},
      catalog AS MATERIALIZED (
        SELECT t.*, ${windowOpen} AS window_open,
          CASE WHEN t.status = 'inProgress' AND t.starts_at <= c.sampled_at THEN 0
            WHEN t.status = 'completed' AND t.starts_at <= c.sampled_at
              AND t.tournament_month = date_trunc('month', c.sampled_at AT TIME ZONE 'Europe/Lisbon')::date THEN 1 END
            AS competition_priority,
          CASE WHEN ${windowOpen} THEN 0
            WHEN t.starts_at > c.sampled_at AND t.status IN ('registrationOpen', 'registrationClosed') THEN 1
            WHEN t.starts_at > c.sampled_at AND t.status = 'unavailable' THEN 2 END AS registration_priority
        FROM stoppy_knockout.tournaments t CROSS JOIN read_clock c
      ), candidates AS (
        SELECT catalog.*, 'competition' AS slot, competition_priority AS priority, NULL::timestamptz AS next_start
          FROM catalog WHERE competition_priority IS NOT NULL
        UNION ALL
        SELECT catalog.*, 'registration', registration_priority, CASE WHEN registration_priority > 0 THEN starts_at END
          FROM catalog WHERE registration_priority IS NOT NULL
      ), ranked AS (
        SELECT *, dense_rank() OVER selection AS priority_rank, row_number() OVER selection AS position
        FROM candidates WINDOW selection AS (PARTITION BY slot ORDER BY priority, next_start)
      )
      SELECT ${metadataColumns}, t.slot, t.window_open
      FROM ranked t WHERE t.priority_rank = 1 AND t.position <= 2`);

    const select = (slot: 'competition' | 'registration') => {
      const candidates = rows.filter((row) => row.slot === slot);
      if (candidates.length > 1) {
        throw new ApiError('conflict', 'Knockout tournament selection is ambiguous.', 409,
          { reason: 'ambiguousTournamentSelection', slot });
      }
      return candidates[0] ? metadata(candidates[0]) : null;
    };
    return { competition: select('competition'), registration: select('registration') };
  }

  async tournament(tournamentId: string) {
    const row = (await this.database.query(`WITH ${clock}
      SELECT ${metadataColumns}, ${windowOpen} AS window_open
      FROM stoppy_knockout.tournaments t CROSS JOIN read_clock c WHERE t.id = $1`, [tournamentId])).rows[0];
    return row ? metadata(row) : missingTournament();
  }

  async playerRegistration(tournamentId: string, playerId: string) {
    const row = (await this.database.query(`WITH ${clock}
      SELECT t.status, ${windowOpen} AS window_open,
        t.starts_at > c.sampled_at AND t.status IN ('registrationOpen', 'registrationClosed') AS awaiting_start,
        to_char(r.registered_at AT TIME ZONE 'UTC', '${utcFormat}') AS registered_at, -r.fee_delta AS fee
      FROM stoppy_knockout.tournaments t CROSS JOIN read_clock c
      LEFT JOIN stoppy_knockout.registrations r ON r.tournament_id = t.id AND r.player_id = $2
      WHERE t.id = $1`, [tournamentId, playerId])).rows[0];
    if (!row) return missingTournament();
    return {
      registeredAt: row.registered_at as string | null,
      entryCostGamePoints: row.fee as number | null,
      awaitingStart: row.awaiting_start === true,
      tournamentStatus: row.status,
      registrationWindowOpen: row.window_open,
    };
  }
}
