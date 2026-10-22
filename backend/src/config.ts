export interface Config {
  readonly environment: 'development' | 'test' | 'production';
  readonly host: string;
  readonly port: number;
  readonly logLevel: 'silent' | 'error' | 'warn' | 'info' | 'debug';
  readonly databaseUrl: string;
  readonly databaseSsl: 'disable' | 'verify-full';
}

function choice<T extends string>(value: string, values: readonly T[], name: string): T {
  if (!values.includes(value as T)) throw new Error(`Invalid ${name}.`);
  return value as T;
}

export function loadConfig(env: NodeJS.ProcessEnv): Config {
  const environment = choice(env.NODE_ENV ?? 'development', ['development', 'test', 'production'], 'NODE_ENV');
  const host = env.HOST ?? '127.0.0.1';
  if (!host.trim() || /[\s/]/.test(host)) throw new Error('Invalid HOST.');
  const rawPort = env.PORT ?? '3000';
  const port = Number(rawPort);
  if (!/^\d+$/.test(rawPort) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }
  const databaseSsl = choice(env.DATABASE_SSL ?? 'disable', ['disable', 'verify-full'], 'DATABASE_SSL');
  if (environment === 'production' && databaseSsl !== 'verify-full') {
    throw new Error('Production DATABASE_SSL must be verify-full.');
  }
  const databaseUrl = env.DATABASE_URL;
  try {
    if (!databaseUrl || databaseUrl !== databaseUrl.trim()) throw new Error();
    const url = new URL(databaseUrl);
    if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname || url.pathname.length < 2) {
      throw new Error();
    }
    // Connection-string TLS overrides could silently bypass the explicit policy.
    if ([...url.searchParams.keys()].some((key) => key.toLowerCase().startsWith('ssl'))) throw new Error();
  } catch {
    // Configuration errors must never echo URLs containing credentials.
    throw new Error('DATABASE_URL must be a PostgreSQL URL with a database name and no SSL overrides.');
  }
  return Object.freeze({
    environment, host, port, databaseUrl,
    databaseSsl,
    logLevel: choice(env.LOG_LEVEL ?? 'info', ['silent', 'error', 'warn', 'info', 'debug'], 'LOG_LEVEL'),
  });
}
