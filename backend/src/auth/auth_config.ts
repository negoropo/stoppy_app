import { createPrivateKey, createPublicKey, generateKeyPairSync, type KeyObject } from 'node:crypto';

export interface AuthConfig {
  readonly privateKey: KeyObject;
  readonly publicKey: KeyObject;
  readonly issuer: string;
  readonly audience: string;
  readonly accessSeconds: number;
  readonly refreshSeconds: number;
}

let developmentKey: KeyObject | undefined;

function lifetime(value: string | undefined, fallback: number, maximum: number): number {
  const parsed = Number(value ?? fallback);
  if (!/^\d+$/.test(value ?? String(fallback)) || !Number.isSafeInteger(parsed) || parsed < 60 || parsed > maximum) {
    throw new Error('Invalid authentication token lifetime.');
  }
  return parsed;
}

export function loadAuthConfig(env: NodeJS.ProcessEnv, production: boolean): AuthConfig {
  let privateKey: KeyObject;
  try {
    if (env.AUTH_PRIVATE_KEY) {
      privateKey = createPrivateKey(env.AUTH_PRIVATE_KEY.replace(/\\n/g, '\n'));
    } else {
      if (production) throw new Error();
      // Local-only convenience: configure a stable key to survive process restarts.
      developmentKey ??= generateKeyPairSync('ed25519').privateKey;
      privateKey = developmentKey;
    }
    if (privateKey.asymmetricKeyType !== 'ed25519') throw new Error();
  } catch { throw new Error('AUTH_PRIVATE_KEY must be an Ed25519 private key; production requires an explicit key.'); }
  const issuer = env.AUTH_ISSUER ?? (production ? '' : 'stoppy-local');
  const audience = env.AUTH_AUDIENCE ?? (production ? '' : 'stoppy-app-local');
  if ([issuer, audience].some((value) => !value.trim() || value !== value.trim() || value.length > 200 || /[\x00-\x20\x7f]/.test(value))) {
    throw new Error('Explicit, valid authentication issuer and audience are required.');
  }
  const accessSeconds = lifetime(env.AUTH_ACCESS_SECONDS, 86400, 7 * 86400);
  const refreshSeconds = lifetime(env.AUTH_REFRESH_SECONDS, 30 * 86400, 90 * 86400);
  if (accessSeconds >= refreshSeconds) throw new Error('Refresh lifetime must exceed access lifetime.');
  return Object.freeze({ privateKey, publicKey: createPublicKey(privateKey), issuer, audience, accessSeconds, refreshSeconds });
}
