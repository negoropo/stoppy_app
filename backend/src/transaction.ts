import type { Database, QueryConnection } from './database.js';

/** Never replay an uncertain commit; discarding the connection is not proof of rollback. */
export async function inTransaction<T>(database: Database, operation: (connection: QueryConnection) => Promise<T>): Promise<T> {
  const connection = await database.connect();
  let began = false;
  let committing = false;
  let discard = false;
  try {
    await connection.query('BEGIN');
    began = true;
    await connection.query("SET LOCAL lock_timeout = '3s'");
    const result = await operation(connection);
    committing = true;
    await connection.query('COMMIT');
    return result;
  } catch (error) {
    discard = !began || committing;
    if (began && !committing) {
      try { await connection.query('ROLLBACK'); } catch { discard = true; }
    }
    throw error;
  } finally { connection.release(discard); }
}
