import type { FastifyInstance } from 'fastify';
import { ApiError } from '../api_error.js';
import type { AuthOperations } from '../auth/auth_service.js';
import { unauthenticated } from '../auth/auth_validation.js';
import type { Database } from '../database.js';
import { RequestRateLimiter } from '../request_rate_limiter.js';
import { registrationResponse, registrationUnavailable } from './knockout_registration_response.js';
import { KnockoutRegistrationFailure, KnockoutRegistrationService } from './knockout_registration_service.js';

const canonicalUuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;
// JSON.parse overwrites duplicate keys. Limit this one-field contract to one
// JSON member before parsing, including when the member name is escaped.
const jsonString = String.raw`"(?:[^"\\]|\\.)*"`;
const oneStringField = new RegExp(String.raw`^\s*\{\s*${jsonString}\s*:\s*${jsonString}\s*\}\s*$`);

function invalidRequest(message = 'Invalid Knockout registration request.') {
  return new ApiError('validationFailed', message, 400);
}

function singleHeader(raw: readonly string[], name: string): string | undefined {
  let value: string | undefined;
  for (let index = 0; index < raw.length; index += 2) {
    if (raw[index]?.toLowerCase() !== name) continue;
    if (value !== undefined) return undefined;
    value = raw[index + 1];
  }
  return value;
}

export function registerKnockoutRegistrationRoute(app: FastifyInstance, database: Database, auth: AuthOperations): void {
  const service = new KnockoutRegistrationService(database);
  const limiter = new RequestRateLimiter('Too many Knockout registration attempts. Please try again later.');
  app.register(async (routes) => {
    routes.removeContentTypeParser('application/json');
    routes.addContentTypeParser('application/json', { parseAs: 'string' }, (_request, body, done) => {
      try {
        if (typeof body !== 'string' || !oneStringField.test(body)) throw invalidRequest();
        const parsed: unknown = JSON.parse(body);
        done(null, parsed);
      } catch {
        done(invalidRequest());
      }
    });
    routes.post<{ Body: Record<string, unknown> }>('/api/v1/knockout/register', {
      onRequest: async (request) => {
        limiter.consume(`ip:${request.ip}`, 30);
        const contentType = singleHeader(request.raw.rawHeaders, 'content-type');
        if (!contentType || !/^application\/json(?:\s*;\s*charset\s*=\s*(?:utf-8|"utf-8"))?$/i.test(contentType)) {
          throw new ApiError('validationFailed', 'Content-Type must be application/json.', 415);
        }
      },
    }, async (request) => {
      const authorization = singleHeader(request.raw.rawHeaders, 'authorization');
      if (!authorization) throw unauthenticated();
      const idempotencyKey = singleHeader(request.raw.rawHeaders, 'idempotency-key');
      if (!idempotencyKey || idempotencyKey.length > 128 || /[^A-Za-z0-9._:-]/.test(idempotencyKey)) {
        throw invalidRequest('One valid Idempotency-Key header is required.');
      }
      const tournamentId = request.body?.tournamentId;
      if (request.url.includes('?') || typeof tournamentId !== 'string'
        || tournamentId.length !== 36 || !canonicalUuid.test(tournamentId)) throw invalidRequest();

      try {
        const { id: playerId } = await auth.profile(authorization);
        limiter.consume(`player:${playerId}`, 12);
        const intent = { playerId, tournamentId, idempotencyKey };
        const result = await service.register(intent);
        const data = await registrationResponse(database, intent, result, () => auth.profile(authorization));
        return { success: true, data };
      } catch (error) {
        if (error instanceof ApiError) throw error;
        throw registrationUnavailable(error instanceof KnockoutRegistrationFailure ? error.code : 'infrastructureFailure');
      }
    });
  });
}
