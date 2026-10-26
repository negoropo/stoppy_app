import type { FastifyInstance } from 'fastify';
import type { AuthOperations } from './auth_service.js';
import { AuthRateLimiter } from './auth_rate_limiter.js';

export function registerAuthRoutes(app: FastifyInstance, auth: AuthOperations, limiter = new AuthRateLimiter()): void {
  // Encapsulation keeps auth limits out of health/readiness and future competitive APIs.
  app.register(async (routes) => {
    routes.addHook('onRequest', async (request) => { limiter.checkIp(request.ip); });
    for (const action of ['register', 'login', 'refresh'] as const) {
      routes.post(`/api/v1/auth/${action}`, async (request) => {
        if (action !== 'refresh') limiter.checkAccount(request.body);
        return { success: true, data: await auth[action](request.body) };
      });
    }
    routes.get('/api/v1/player/profile', async (request) => ({
      success: true, data: await auth.profile(request.headers.authorization),
    }));
  });
}
