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
    connect: () => pool.connect(),
    close: () => pool.end(),
  };
}

export async function checkDatabase(database: QueryConnection): Promise<void> {
  await database.query('SELECT 1 AS connected');
}
