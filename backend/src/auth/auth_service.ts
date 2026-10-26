import { randomUUID } from 'node:crypto';
import type { AuthConfig } from './auth_config.js';
import type { AuthRepository, NewSession, PlayerProfile } from './auth_repository.js';
import type { PasswordHasher } from './password_hasher.js';
import { TokenService, newRefreshToken, tokenDigest, type SessionPayload } from './token_service.js';
import { credentials, refreshCredential, unauthenticated } from './auth_validation.js';

export interface AuthOperations {
  register(body: unknown): Promise<{ playerProfile: PlayerProfile; session: SessionPayload }>;
  login(body: unknown): Promise<{ playerProfile: PlayerProfile; session: SessionPayload }>;
  refresh(body: unknown): Promise<{ session: SessionPayload }>;
  profile(authorization: string | undefined): Promise<PlayerProfile>;
}

export class AuthService implements AuthOperations {
  constructor(private readonly config: AuthConfig, private readonly repository: AuthRepository,
    private readonly passwords: PasswordHasher, private readonly tokens: TokenService,
    private readonly now: () => Date = () => new Date()) {}

  private async session(playerId: string): Promise<{ record: NewSession; payload: SessionPayload }> {
    const createdAt = this.now();
    const expiresAt = new Date(createdAt.getTime() + this.config.refreshSeconds * 1000);
    const refreshToken = newRefreshToken();
    const record = { id: randomUUID(), playerId, tokenId: randomUUID(), digest: tokenDigest(refreshToken), createdAt, expiresAt };
    const payload = await this.tokens.issue(playerId, record.id, refreshToken, createdAt, expiresAt);
    return { record, payload };
  }

  async register(body: unknown) {
    const input = credentials(body);
    // Hash outside the transaction so expensive CPU work never holds row locks.
    const passwordHash = await this.passwords.hash(input.password);
    const id = randomUUID();
    const session = await this.session(id);
    const playerProfile = await this.repository.register(id, input.username, passwordHash, session.record);
    return { playerProfile, session: session.payload };
  }

  async login(body: unknown) {
    const input = credentials(body, false);
    const account = await this.repository.findCredentials(input.canonicalUsername);
    if (!await this.passwords.verify(account?.passwordHash ?? null, input.password) || !account) throw unauthenticated();
    const session = await this.session(account.profile.id);
    await this.repository.createSession(session.record);
    return { playerProfile: account.profile, session: session.payload };
  }

  async refresh(body: unknown) {
    const token = refreshCredential(body);
    const replacement = newRefreshToken();
    const session = await this.repository.rotate(tokenDigest(token), randomUUID(), tokenDigest(replacement),
      (playerId, sessionId, now, expiry) => this.tokens.issue(playerId, sessionId, replacement, now, expiry));
    if (!session) throw unauthenticated();
    return { session };
  }

  async profile(authorization: string | undefined) {
    const identity = await this.tokens.verify(authorization, this.now());
    const profile = await this.repository.authenticatedProfile(identity.playerId, identity.sessionId);
    if (!profile) throw unauthenticated();
    return profile;
  }
}
