CREATE SCHEMA stoppy_economy;

-- Only final semantic outcomes are stored. A future executor must commit the
-- outcome, ledger and balance in one transaction; this table never changes GP.
CREATE TABLE stoppy_economy.gp_mutations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES stoppy_auth.players(id) ON DELETE RESTRICT,
  operation_name text COLLATE "C" NOT NULL
    CHECK (char_length(operation_name) BETWEEN 1 AND 128 AND operation_name ~ '^[A-Za-z0-9._:-]+$'),
  operation_version integer NOT NULL CHECK (operation_version > 0),
  idempotency_key text COLLATE "C" NOT NULL
    CHECK (char_length(idempotency_key) BETWEEN 1 AND 128 AND idempotency_key ~ '^[A-Za-z0-9._:-]+$'),
  fingerprint_version integer NOT NULL CHECK (fingerprint_version > 0),
  request_fingerprint text COLLATE "C" NOT NULL CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
  outcome_status text NOT NULL CHECK (outcome_status IN ('accepted', 'rejected')),
  semantic_outcome jsonb NOT NULL CHECK (jsonb_typeof(semantic_outcome) = 'object'),
  resolved_context jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(resolved_context) = 'object'),
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP CHECK (completed_at >= created_at),
  UNIQUE (player_id, operation_name, operation_version, idempotency_key),
  UNIQUE (player_id, id, outcome_status)
);
CREATE INDEX gp_mutations_player_created ON stoppy_economy.gp_mutations(player_id, created_at, id);

CREATE TABLE stoppy_economy.gp_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES stoppy_auth.players(id) ON DELETE RESTRICT,
  mutation_id uuid,
  -- The composite FK rejects cross-player or rejected mutation associations.
  mutation_status text GENERATED ALWAYS AS ('accepted'::text) STORED,
  movement_type text NOT NULL CHECK (movement_type IN ('opening_snapshot', 'credit', 'debit')),
  reason text COLLATE "C" NOT NULL
    CHECK (char_length(reason) BETWEEN 1 AND 128 AND reason ~ '^[A-Za-z0-9._:-]+$'),
  source_type text COLLATE "C" NOT NULL
    CHECK (char_length(source_type) BETWEEN 1 AND 128 AND source_type ~ '^[A-Za-z0-9._:-]+$'),
  source_id text COLLATE "C" NOT NULL
    CHECK (char_length(source_id) BETWEEN 1 AND 256 AND source_id = btrim(source_id)
      AND source_id !~ '[[:cntrl:]]'),
  delta integer NOT NULL,
  balance_before integer NOT NULL CHECK (balance_before >= 0),
  balance_after integer NOT NULL CHECK (balance_after >= 0),
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (player_id, mutation_id, mutation_status)
    REFERENCES stoppy_economy.gp_mutations(player_id, id, outcome_status) ON DELETE RESTRICT,
  -- Widen only the check expression, not the persisted integer balance domain.
  CHECK (balance_after::bigint = balance_before::bigint + delta::bigint),
  CHECK (
    (movement_type = 'opening_snapshot' AND delta = 0 AND mutation_id IS NULL
      AND reason = 'opening_snapshot' AND source_type = 'opening_snapshot' AND source_id = player_id::text)
    OR (movement_type = 'credit' AND delta > 0 AND reason <> 'opening_snapshot' AND source_type <> 'opening_snapshot')
    OR (movement_type = 'debit' AND delta < 0 AND reason <> 'opening_snapshot' AND source_type <> 'opening_snapshot')
  ),
  UNIQUE (player_id, source_type, source_id)
);
-- Canonical opening source_type/source_id plus source uniqueness permit only
-- one opening per player without a second redundant unique index.
CREATE INDEX gp_ledger_player_created ON stoppy_economy.gp_ledger(player_id, created_at, id);
CREATE INDEX gp_ledger_mutation ON stoppy_economy.gp_ledger(mutation_id) WHERE mutation_id IS NOT NULL;

-- Statement-level guards also reject TRUNCATE, which row-level guards miss.
-- Runtime roles must not own these tables or have schema/trigger DDL powers.
-- Reviewed future migrations can deliberately alter guards; ordinary DML cannot.
CREATE FUNCTION stoppy_economy.reject_audit_rewrite() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'Economy audit records are append-only.';
END;
$$;
CREATE TRIGGER gp_ledger_append_only BEFORE UPDATE OR DELETE OR TRUNCATE
  ON stoppy_economy.gp_ledger FOR EACH STATEMENT EXECUTE FUNCTION stoppy_economy.reject_audit_rewrite();
CREATE TRIGGER gp_mutations_append_only BEFORE UPDATE OR DELETE OR TRUNCATE
  ON stoppy_economy.gp_mutations FOR EACH STATEMENT EXECUTE FUNCTION stoppy_economy.reject_audit_rewrite();
REVOKE ALL ON SCHEMA stoppy_economy FROM PUBLIC;
REVOKE ALL ON FUNCTION stoppy_economy.reject_audit_rewrite() FROM PUBLIC;
REVOKE UPDATE, DELETE, TRUNCATE ON stoppy_economy.gp_ledger, stoppy_economy.gp_mutations FROM PUBLIC;

-- Freeze pre-existing balances through commit so a concurrent writer cannot
-- race this observation. The runner supplies the transaction and bounded lock.
LOCK TABLE stoppy_auth.players IN SHARE ROW EXCLUSIVE MODE;
INSERT INTO stoppy_economy.gp_ledger
  (player_id, movement_type, reason, source_type, source_id, delta, balance_before, balance_after)
SELECT id, 'opening_snapshot', 'opening_snapshot', 'opening_snapshot', id::text, 0, game_points, game_points
FROM stoppy_auth.players;
-- A positive snapshot is not a credit; zero-GP players also get one explicit
-- zero-delta snapshot. No player balance, profile or authentication row is updated.
