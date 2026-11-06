CREATE SCHEMA stoppy_knockout;

-- Month is a trusted Portugal-calendar label, not an instant interpreted in a
-- device/session timezone. Windows are absolute instants: opens <= now < closes.
CREATE TABLE stoppy_knockout.tournaments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_month date NOT NULL UNIQUE CHECK (EXTRACT(DAY FROM tournament_month) = 1),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 128),
  registration_opens_at timestamptz NOT NULL,
  registration_closes_at timestamptz NOT NULL,
  starts_at timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('unavailable', 'registrationOpen', 'registrationClosed', 'inProgress', 'completed')),
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (registration_opens_at < registration_closes_at AND registration_closes_at < starts_at)
);

-- The existing ledger PK alone cannot prove player, accepted mutation, debit
-- direction, amount AND exact business source. This key changes no existing rows or
-- financial semantics, and leaves migration 003/checksums untouched.
ALTER TABLE stoppy_economy.gp_ledger ADD CONSTRAINT gp_ledger_registration_reference
  UNIQUE (id, player_id, mutation_id, movement_type, delta, source_type, source_id);

CREATE TABLE stoppy_knockout.registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id uuid NOT NULL REFERENCES stoppy_knockout.tournaments(id) ON DELETE RESTRICT,
  player_id uuid NOT NULL REFERENCES stoppy_auth.players(id) ON DELETE RESTRICT,
  registered_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  gp_ledger_id uuid NOT NULL UNIQUE,
  gp_mutation_id uuid NOT NULL,
  fee_movement_type text GENERATED ALWAYS AS ('debit'::text) STORED,
  fee_delta integer GENERATED ALWAYS AS (-25) STORED,
  -- Preallocate the registration UUID before its debit. Encoding both UUIDs
  -- binds the fee to this exact registration/tournament without a circular FK.
  fee_source_type text COLLATE "C" GENERATED ALWAYS AS ('knockout_registration'::text) STORED,
  fee_source_id text COLLATE "C" GENERATED ALWAYS AS (tournament_id::text || ':' || id::text) STORED,
  FOREIGN KEY (gp_ledger_id, player_id, gp_mutation_id, fee_movement_type, fee_delta, fee_source_type, fee_source_id)
    REFERENCES stoppy_economy.gp_ledger(id, player_id, mutation_id, movement_type, delta, source_type, source_id) ON DELETE RESTRICT,
  UNIQUE (tournament_id, player_id),
  UNIQUE (id, player_id, tournament_id)
);

-- Only final business outcomes, distinct from GP execution outcomes. A future
-- owner commits these rows, registration and GP writes in the same transaction.
CREATE TABLE stoppy_knockout.registration_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES stoppy_auth.players(id) ON DELETE RESTRICT,
  operation_name text COLLATE "C" NOT NULL
    CHECK (char_length(operation_name) BETWEEN 1 AND 128 AND operation_name ~ '^[A-Za-z0-9._:-]+$'),
  operation_version integer NOT NULL CHECK (operation_version > 0),
  idempotency_key text COLLATE "C" NOT NULL
    CHECK (char_length(idempotency_key) BETWEEN 1 AND 128 AND idempotency_key ~ '^[A-Za-z0-9._:-]+$'),
  fingerprint_version integer NOT NULL CHECK (fingerprint_version > 0),
  request_fingerprint text COLLATE "C" NOT NULL CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
  tournament_id uuid REFERENCES stoppy_knockout.tournaments(id) ON DELETE RESTRICT,
  outcome_status text NOT NULL CHECK (outcome_status IN ('accepted', 'rejected')),
  registration_id uuid UNIQUE,
  rejection_reason text CHECK (rejection_reason IN ('duplicateRegistration', 'insufficientGp', 'registrationClosed',
    'tournamentAlreadyStarted', 'tournamentUnavailable', 'settlementInProgress', 'stalePlayerState')),
  semantic_outcome jsonb NOT NULL CHECK (jsonb_typeof(semantic_outcome) = 'object'),
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP CHECK (completed_at >= created_at),
  FOREIGN KEY (registration_id, player_id, tournament_id)
    REFERENCES stoppy_knockout.registrations(id, player_id, tournament_id) ON DELETE RESTRICT,
  CHECK ((outcome_status = 'accepted' AND registration_id IS NOT NULL AND tournament_id IS NOT NULL AND rejection_reason IS NULL)
    OR (outcome_status = 'rejected' AND registration_id IS NULL AND rejection_reason IS NOT NULL)),
  CHECK (tournament_id IS NOT NULL OR (outcome_status = 'rejected' AND rejection_reason = 'tournamentUnavailable')),
  UNIQUE (player_id, operation_name, operation_version, idempotency_key)
);

CREATE TRIGGER knockout_registrations_append_only BEFORE UPDATE OR DELETE OR TRUNCATE
  ON stoppy_knockout.registrations FOR EACH STATEMENT EXECUTE FUNCTION stoppy_economy.reject_audit_rewrite();
CREATE TRIGGER knockout_operations_append_only BEFORE UPDATE OR DELETE OR TRUNCATE
  ON stoppy_knockout.registration_operations FOR EACH STATEMENT EXECUTE FUNCTION stoppy_economy.reject_audit_rewrite();
REVOKE ALL ON SCHEMA stoppy_knockout FROM PUBLIC;
REVOKE ALL ON stoppy_knockout.tournaments, stoppy_knockout.registrations, stoppy_knockout.registration_operations FROM PUBLIC;
-- No catalog seed, calendar inference, role provisioning, charge or HTTP activation.
