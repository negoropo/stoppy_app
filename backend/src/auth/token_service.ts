import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { SignJWT, jwtVerify } from 'jose';
import type { AuthConfig } from './auth_config.js';
import { unauthenticated } from './auth_validation.js';

export interface SessionPayload { accessToken: string; refreshToken: string; expiresAt: string }
export const isUuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
export const tokenDigest = (value: string): string => createHash('sha256').update(value).digest('hex');
export const newRefreshToken = (): string => randomBytes(32).toString('base64url');

export class TokenService {
  constructor(private readonly config: AuthConfig) {}

  async issue(playerId: string, sessionId: string, refreshToken: string, now: Date, sessionExpiry: Date): Promise<SessionPayload> {
    const issuedAt = Math.floor(now.getTime() / 1000);
    const expiration = Math.min(issuedAt + this.config.accessSeconds, Math.floor(sessionExpiry.getTime() / 1000));
    if (expiration <= issuedAt) throw unauthenticated();
    const accessToken = await new SignJWT({ sid: sessionId }).setProtectedHeader({ alg: 'EdDSA', typ: 'JWT' })
      .setSubject(playerId).setJti(randomUUID()).setIssuer(this.config.issuer).setAudience(this.config.audience)
      .setIssuedAt(issuedAt).setExpirationTime(expiration).sign(this.config.privateKey);
    return { accessToken, refreshToken, expiresAt: new Date(expiration * 1000).toISOString() };
  }

  async verify(authorization: string | undefined, now: Date): Promise<{ playerId: string; sessionId: string }> {
    if (!authorization || authorization.length > 4096 || !/^Bearer [A-Za-z0-9_.-]+$/i.test(authorization)) throw unauthenticated();
    try {
      const { payload } = await jwtVerify(authorization.slice(7), this.config.publicKey, {
        algorithms: ['EdDSA'], issuer: this.config.issuer, audience: this.config.audience,
        typ: 'JWT', currentDate: now, requiredClaims: ['sub', 'sid', 'jti', 'iat', 'exp'],
      });
      if (!isUuid(payload.sub) || !isUuid(payload.sid) || !isUuid(payload.jti) ||
          !Number.isInteger(payload.iat) || !Number.isInteger(payload.exp) ||
          payload.iat! > Math.floor(now.getTime() / 1000) || payload.exp! <= payload.iat! ||
          payload.exp! - payload.iat! > this.config.accessSeconds) throw unauthenticated();
      return { playerId: payload.sub, sessionId: payload.sid };
    } catch { throw unauthenticated(); }
  }
}
