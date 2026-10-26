import type { Database, TransactionConnection } from '../src/database.js';
import { loadConfig } from '../src/config.js';
import { EventEmitter } from 'node:events';

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

/** Models pg's synchronous handoff back to its pool-owned idle error listener. */
export class EventDatabaseClient extends EventEmitter implements TransactionConnection {
  readonly calls: string[] = [];
  readonly releases: boolean[] = [];
  readonly idleError = () => {};
  beforeQuery: (sql: string) => void | Promise<void> = () => {};
  async query(sql: string) {
    this.calls.push(sql);
    await this.beforeQuery(sql);
    return { rows: [] };
  }
  release(discard = false) {
    this.releases.push(discard);
    this.on('error', this.idleError);
  }
}
