import type { FastifyInstance, FastifyRequest } from 'fastify';
import { ApiError } from '../api_error.js';
import type { AuthOperations } from '../auth/auth_service.js';
import type { QueryConnection } from '../database.js';
import { KnockoutReadRepository } from './knockout_read_repository.js';

const path = '/api/v1/knockout';
const canonicalUuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;

function tournamentIdFrom(request: FastifyRequest, scope: 'required' | 'optional' | 'none'): string | undefined {
  const query = request.query as Record<string, unknown>;
  const keys = Object.keys(query);
  if (keys.length === 0 && scope !== 'required') return undefined;
  const id = query.tournamentId;
  if (scope === 'none' || keys.length !== 1 || typeof id !== 'string' || id.length !== 36 || !canonicalUuid.test(id)) {
    throw new ApiError('validationFailed', 'Invalid Knockout read query.', 400);
  }
  return id;
}

function unavailable(): never {
  throw new ApiError('notImplemented', 'This Knockout competitive projection is unavailable.', 501,
    { reason: 'competitiveProjectionUnavailable' });
}

export function registerKnockoutReadRoutes(app: FastifyInstance, database: QueryConnection, auth: AuthOperations): void {
  const repository = new KnockoutReadRepository(database);
  app.get(`${path}/tournament`, async (request) => {
    const tournamentId = tournamentIdFrom(request, 'optional');
    await auth.profile(request.headers.authorization);
    const data = tournamentId ? { tournament: await repository.tournament(tournamentId) } : await repository.discover();
    return { success: true, data };
  });
  app.get(`${path}/entry`, async (request) => {
    const tournamentId = tournamentIdFrom(request, 'required')!;
    const player = await auth.profile(request.headers.authorization);
    const { registeredAt, entryCostGamePoints } = await repository.playerRegistration(tournamentId, player.id);
    const correlation = { tournamentId, playerId: player.id };
    return { success: true, data: { ...correlation, playerEntry: registeredAt === null ? null : {
      ...correlation, username: player.username, accountCreatedAt: player.createdAt, registeredAt, entryCostGamePoints,
    } } };
  });
  app.get(`${path}/status`, async (request) => {
    const tournamentId = tournamentIdFrom(request, 'required')!;
    const { id: playerId } = await auth.profile(request.headers.authorization);
    const entry = await repository.playerRegistration(tournamentId, playerId);
    const state = entry.registeredAt === null ? 'notRegistered'
      : entry.awaitingStart ? 'registeredWaitingStart' : 'registeredCompetitionUnavailable';
    return { success: true, data: { tournamentId, playerId, tournamentStatus: entry.tournamentStatus,
      registrationWindowOpen: entry.registrationWindowOpen, state } };
  });
  app.get(`${path}/active-duel`, async (request) => {
    const tournamentId = tournamentIdFrom(request, 'required')!;
    await auth.profile(request.headers.authorization);
    await repository.tournament(tournamentId);
    return unavailable();
  });
  for (const projection of ['records', 'history', 'hall-of-fame']) {
    app.get(`${path}/${projection}`, async (request) => {
      tournamentIdFrom(request, 'none');
      await auth.profile(request.headers.authorization);
      return unavailable();
    });
  }
}
