import { ApiError } from '../api_error.js';

function object(value: unknown, fields: string[]): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).length !== fields.length || Object.keys(value).some((key) => !fields.includes(key))) {
    throw new ApiError('validationFailed', 'Invalid authentication request.', 400);
  }
  return value as Record<string, unknown>;
}

function isDartTrimEmpty(value: string): boolean {
  // Match the installed Dart VM's trim set explicitly: JavaScript trim omits
  // U+0085. This predicate never changes the password used for hashing/login.
  return !/[^\u0009-\u000d\u0020\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]/u.test(value);
}

export function credentials(body: unknown, registration = true): { username: string; canonicalUsername: string; password: string } {
  const value = object(body, ['username', 'password']);
  if (typeof value.username !== 'string' || typeof value.password !== 'string') {
    throw new ApiError('validationFailed', 'Username and password must be strings.', 400);
  }
  const username = value.username.trim();
  // Explicit ASCII policy avoids differences between Dart, JS and database Unicode case folding.
  if (!/^[A-Za-z0-9_. -]{1,32}$/.test(username)) {
    throw new ApiError('validationFailed', 'Username must be 1-32 ASCII letters, numbers, spaces, dots, underscores or hyphens.', 400);
  }
  // Registration minimums must not lock out existing accounts at login. Inspect
  // whitespace only for validation; return the original password unchanged.
  if (isDartTrimEmpty(value.password) || (registration && value.password.length < 4) ||
      value.password.length > 128 || Buffer.byteLength(value.password, 'utf8') > 512) {
    throw new ApiError('validationFailed', registration
      ? 'Password must contain a non-whitespace character and be between 4 and 128 characters.'
      : 'Password must not be blank and must not exceed 128 characters.', 400);
  }
  return { username, canonicalUsername: username.toLowerCase(), password: value.password };
}

export function refreshCredential(body: unknown): string {
  const value = object(body, ['refreshToken']);
  if (typeof value.refreshToken !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(value.refreshToken)) {
    throw new ApiError('unauthenticated', 'Invalid authentication credentials.', 401);
  }
  return value.refreshToken;
}

export function unauthenticated(): ApiError {
  return new ApiError('unauthenticated', 'Invalid authentication credentials.', 401);
}
