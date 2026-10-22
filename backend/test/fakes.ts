import type { Database, TransactionConnection } from '../src/database.js';
import { loadConfig } from '../src/config.js';

export const testConfig = loadConfig({ NODE_ENV: 'test', LOG_LEVEL: 'silent', DATABASE_URL: 'postgresql://localhost/stoppy_test' });

export class FakeDatabase implements Database, TransactionConnection {
  readonly calls: { sql: string; values?: unknown[] }[] = [];
  applied: Record<string, unknown>[] = [];
  failureSql: string | undefined;
  rollbackFails = false;
  closed = 0;
  connections = 0;
  released: boolean[] = [];
  async query(sql: string, values?: unknown[]) {
    this.calls.push(values === undefined ? { sql } : { sql, values });
    if (sql === this.failureSql || (sql === 'ROLLBACK' && this.rollbackFails)) {
      throw new Error('Sensitive database error with credentials and SQL.');
    }
    return { rows: sql.startsWith('SELECT version, checksum') ? this.applied : [] };
  }
  async connect() { this.connections++; return this; }
  release(discard = false) { this.released.push(discard); }
  async close() { this.closed++; }
}
