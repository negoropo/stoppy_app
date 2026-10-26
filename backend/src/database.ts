import pg from 'pg';
import type { Config } from './config.js';

export interface QueryConnection {
  query(sql: string, values?: unknown[]): Promise<{ rows: Record<string, unknown>[] }>;
}

export interface TransactionConnection extends QueryConnection {
  release(discard?: boolean): void;
}

export interface Database extends QueryConnection {
  connect(): Promise<TransactionConnection>;
  close(): Promise<void>;
}

interface AcquiredClient extends TransactionConnection {
  on(event: 'error', listener: (error: Error) => void): unknown;
  removeListener(event: 'error', listener: (error: Error) => void): unknown;
}

/** Owns the error listener until pg installs its idle listener during release. */
export function protectTransactionConnection(client: AcquiredClient): TransactionConnection {
  let failed = false;
  let released = false;
  let signalFailure!: () => void;
  // Resolving, rather than rejecting, also handles errors between queries without
  // creating an unhandled rejection. Each active query races this failure signal.
  const failure = new Promise<void>((resolve) => { signalFailure = resolve; });
  const unavailable = () => new Error('Database connection is unavailable.');
  const onError = () => { failed = true; signalFailure(); };
  client.on('error', onError);
  return {
    async query(sql, values) {
      if (failed || released) throw unavailable();
      try {
        const result = await Promise.race([
          client.query(sql, values),
          failure.then(() => { throw unavailable(); }),
        ]);
        if (failed || released) throw unavailable();
        return result;
      } catch (error) {
        // Preserve ordinary SQL error codes, but never propagate raw socket errors.
        if (failed) throw unavailable();
        throw error;
      }
    },
    release(discard = false) {
      if (released) return;
      released = true;
      try { client.release(discard || failed); }
      finally { client.removeListener('error', onError); }
    },
  };
}

export function databaseOptions(config: Config, purpose: 'api' | 'migration' = 'api'): pg.PoolConfig {
  // Schema changes can legitimately exceed API latency budgets. Both profiles
  // remain bounded; client timeout includes a margin for server cancellation.
  const statementTimeout = purpose === 'migration' ? 120000 : 5000;
  return {
    connectionString: config.databaseUrl,
    ssl: config.databaseSsl === 'verify-full' ? { rejectUnauthorized: true } : false,
    max: 5,
    connectionTimeoutMillis: 3000,
    idleTimeoutMillis: 10000,
    statement_timeout: statementTimeout,
    query_timeout: statementTimeout + (purpose === 'migration' ? 5000 : 1000),
    application_name: 'stoppy-backend',
  };
}

export function createDatabase(config: Config, onIdleError: () => void, purpose: 'api' | 'migration' = 'api'): Database {
  const pool = new pg.Pool(databaseOptions(config, purpose));
  // An idle connection failure must be handled without leaking credentials or
  // crashing the process; readiness independently checks current connectivity.
  pool.on('error', onIdleError);
  return {
    query: (sql, values) => pool.query(sql, values),
    connect: () => new Promise<TransactionConnection>((resolve, reject) => {
      // pg removes the idle error listener just before calling this callback.
      // Attach synchronously, before resolving, to avoid an unguarded microtask gap.
      pool.connect((error, client) => {
        if (error) reject(error);
        else if (client) resolve(protectTransactionConnection(client));
        else reject(new Error('Database connection is unavailable.'));
      });
    }),
    close: () => pool.end(),
  };
}

export async function checkDatabase(database: QueryConnection): Promise<void> {
  await database.query('SELECT 1 AS connected');
}
