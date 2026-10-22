import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import type { Database } from './database.js';

export interface Migration {
  readonly version: string;
  readonly sql: string;
  readonly checksum: string;
}

function validateVersion(version: string, index: number): void {
  if (!/^\d{3}_[a-z0-9_]+\.sql$/.test(version) || Number(version.slice(0, 3)) !== index + 1) {
    throw new Error('Migration filenames must use consecutive three-digit versions.');
  }
}

function validateMigrations(migrations: readonly Migration[]): Migration[] {
  if (migrations.length === 0) throw new Error('No migrations found.');
  return migrations.map((migration, index) => {
    validateVersion(migration.version, index);
    if (!migration.sql.trim() || migration.checksum !== createHash('sha256').update(migration.sql).digest('hex')) {
      throw new Error('Migration SQL/checksum is invalid.');
    }
    // Keep the validated values stable while awaiting a connection or lock.
    return { ...migration };
  });
}

export async function readMigrations(directory = new URL('../migrations/', import.meta.url)): Promise<Migration[]> {
  const names = (await readdir(directory)).filter((name) => name.endsWith('.sql')).sort();
  const migrations = await Promise.all(names.map(async (name, index) => {
    // Ordered, append-only files prevent two versions sharing a sequence number.
    validateVersion(name, index);
    const sql = await readFile(new URL(name, directory), 'utf8');
    return { version: name, sql, checksum: createHash('sha256').update(sql).digest('hex') };
  }));
  return validateMigrations(migrations);
}

export async function runMigrations(database: Database, migrations: readonly Migration[]): Promise<number> {
  const validated = validateMigrations(migrations);
  const client = await database.connect();
  let discard = false;
  let began = false;
  let committing = false;
  try {
    await client.query('BEGIN');
    began = true;
    await client.query("SET LOCAL lock_timeout = '3s'");
    // Serialize deploy-time migrators on one transaction/connection, including
    // initial ledger creation. This is infrastructure locking, not run idempotency.
    await client.query('SELECT pg_advisory_xact_lock($1)', [440001]);
    await client.query(`CREATE TABLE IF NOT EXISTS public.stoppy_schema_migrations (
      version text PRIMARY KEY,
      checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`);
    const applied = await client.query('SELECT version, checksum FROM public.stoppy_schema_migrations ORDER BY version');
    for (let index = 0; index < applied.rows.length; index++) {
      const row = applied.rows[index]!;
      const migration = validated[index];
      if (!migration || row.version !== migration.version || row.checksum !== migration.checksum) {
        throw new Error('Applied migration history differs from local files.');
      }
    }
    const pending = validated.slice(applied.rows.length);
    for (const migration of pending) {
      // SQL files are trusted, reviewed deployment assets. Ledger values are
      // parameters; no HTTP input is used for identifiers or migration content.
      await client.query(migration.sql);
      await client.query('INSERT INTO public.stoppy_schema_migrations (version, checksum) VALUES ($1, $2)',
        [migration.version, migration.checksum]);
    }
    committing = true;
    await client.query('COMMIT');
    return pending.length;
  } catch (error) {
    // BEGIN/COMMIT failures may have lost their acknowledgement. Discard the
    // session instead of issuing more SQL or assuming a rollback proves outcome.
    discard = !began || committing;
    if (began && !committing) {
      try { await client.query('ROLLBACK'); } catch { discard = true; }
    }
    throw error;
  } finally {
    client.release(discard);
  }
}
