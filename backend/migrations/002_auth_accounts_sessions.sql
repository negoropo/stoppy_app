CREATE SCHEMA stoppy_auth;

CREATE TABLE stoppy_auth.players (
  id uuid PRIMARY KEY,
  username text NOT NULL CHECK (char_length(username) BETWEEN 1 AND 32 AND username = btrim(username)
    AND username COLLATE "C" ~ '^[A-Za-z0-9_. -]+$'),
  canonical_username text GENERATED ALWAYS AS (lower(username COLLATE "C")) STORED UNIQUE,
  password_hash text NOT NULL CHECK (password_hash LIKE '$argon2id$%'),
  created_at timestamptz NOT NULL,
  game_points integer NOT NULL DEFAULT 5 CHECK (game_points >= 0),
  ads_removed boolean NOT NULL DEFAULT false,
  last_daily_gp_awarded_at timestamptz,
  current_league_division integer CHECK (current_league_division > 0),
  has_weekly_league_entry boolean NOT NULL DEFAULT false,
  reserved_league_slot boolean NOT NULL DEFAULT false
);

CREATE TABLE stoppy_auth.auth_sessions (
  id uuid PRIMARY KEY,
  player_id uuid NOT NULL REFERENCES stoppy_auth.players(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL CHECK (expires_at > created_at),
  revoked_at timestamptz CHECK (revoked_at >= created_at)
);
CREATE INDEX auth_sessions_player_id ON stoppy_auth.auth_sessions(player_id);

CREATE TABLE stoppy_auth.auth_refresh_tokens (
  id uuid PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES stoppy_auth.auth_sessions(id) ON DELETE CASCADE,
  token_digest text NOT NULL UNIQUE CHECK (token_digest ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL CHECK (expires_at > created_at),
  consumed_at timestamptz CHECK (consumed_at >= created_at),
  replaced_by uuid,
  UNIQUE (session_id, id),
  FOREIGN KEY (session_id, replaced_by) REFERENCES stoppy_auth.auth_refresh_tokens(session_id, id),
  CHECK (replaced_by IS NULL OR (consumed_at IS NOT NULL AND replaced_by <> id))
);
-- A family has at most one usable credential; consumed rows remain for replay detection.
CREATE UNIQUE INDEX auth_refresh_one_unconsumed ON stoppy_auth.auth_refresh_tokens(session_id) WHERE consumed_at IS NULL;
CREATE INDEX auth_refresh_expiration ON stoppy_auth.auth_refresh_tokens(expires_at);
