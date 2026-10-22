import Fastify from 'fastify';
import { ApiError, failure } from './api_error.js';
import type { Config } from './config.js';
import { checkDatabase, type Database } from './database.js';

export function buildApp(config: Config, database: Database) {
  const app = Fastify({
    logger: config.logLevel === 'silent' ? false : {
      level: config.logLevel,
      redact: ['req.headers.authorization', 'req.headers.cookie', 'req.headers["idempotency-key"]'],
      // Log only method and route path, never query credentials or bodies.
      serializers: { req: (req) => ({ method: req.method, url: req.url.split('?')[0] ?? '/' }) },
    },
    bodyLimit: 16 * 1024,
    requestTimeout: 10000,
    connectionTimeout: 10000,
    keepAliveTimeout: 5000,
    trustProxy: false,
    forceCloseConnections: 'idle',
  });

  app.addHook('onSend', async (_request, reply) => {
    reply.header('Cache-Control', 'no-store');
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
  });
  app.setNotFoundHandler(async (_request, reply) => {
    return reply.code(404).send(failure('notFound', 'Route not found.'));
  });
  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ApiError) {
      return reply.code(error.statusCode).send(failure(error.code, error.message));
    }
    if (error instanceof Error && 'statusCode' in error &&
        typeof error.statusCode === 'number' && error.statusCode >= 400 && error.statusCode < 500) {
      return reply.code(error.statusCode).send(failure('validationFailed', 'Invalid request.'));
    }
    // Database/driver exceptions can contain SQL and credentials. Log only an
    // opaque request identifier, and send the established safe error envelope.
    request.log.error({ requestId: request.id }, 'Request failed.');
    return reply.code(500).send(failure('serverError', 'Internal server error.'));
  });
  app.get('/api/v1/health', async () => ({ success: true, data: { status: 'ok', service: 'stoppy-api' } }));
  app.get('/api/v1/ready', async () => {
    try {
      await checkDatabase(database);
      return { success: true, data: { status: 'ready' } };
    } catch {
      throw new ApiError('serverError', 'Service is not ready.', 503);
    }
  });
  app.addHook('onClose', async () => database.close());
  return app;
}
