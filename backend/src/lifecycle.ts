import type { FastifyInstance } from 'fastify';
import { buildApp } from './app.js';
import type { Config } from './config.js';
import { checkDatabase, type Database } from './database.js';

export async function startApplication(
  config: Config,
  database: Database,
  listen: (app: FastifyInstance) => Promise<void> = async (app) => {
    await app.listen({ host: config.host, port: config.port });
  },
): Promise<FastifyInstance> {
  const app = buildApp(config, database);
  try {
    // Fail fast before binding if PostgreSQL is unavailable. Once started,
    // liveness remains separate from readiness during a later database outage.
    await checkDatabase(database);
    await listen(app);
    return app;
  } catch (error) {
    await app.close();
    throw error;
  }
}

export function installShutdownHandlers(
  app: { close(): Promise<unknown> },
  signals: {
    on(event: 'SIGINT' | 'SIGTERM', listener: () => void): unknown;
    off(event: 'SIGINT' | 'SIGTERM', listener: () => void): unknown;
  } = process,
  reportFailure = () => {
    console.error('Shutdown failed.');
    process.exitCode = 1;
  },
  forceExit: () => void = () => process.exit(1),
): () => void {
  let stopping = false;
  let deadline: ReturnType<typeof setTimeout> | undefined;
  const cleanup = () => {
    clearTimeout(deadline);
    signals.off('SIGINT', stop);
    signals.off('SIGTERM', stop);
  };
  const stop = () => {
    if (stopping) return;
    stopping = true;
    deadline = setTimeout(forceExit, 10000);
    deadline.unref();
    // Fastify drains in-flight requests before its onClose database hook.
    // Keep the deadline alive on rejection: failed close can leave open handles.
    void Promise.resolve().then(() => app.close()).then(cleanup).catch(() => {
      reportFailure();
    });
  };
  // Keep both handlers until shutdown finishes; repeated signals must not
  // invoke database cleanup twice or interrupt graceful request draining.
  signals.on('SIGINT', stop);
  signals.on('SIGTERM', stop);
  return cleanup;
}
