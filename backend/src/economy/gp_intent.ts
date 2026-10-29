import { createHash } from 'node:crypto';

export const gpIntegerMax = 2147483647;
export const gpFingerprintVersion = 1;
export type JsonValue = null | boolean | number | string | readonly JsonValue[] | { readonly [key: string]: JsonValue };

/** Internal, trusted business intent, never a mobile request body or profile write. */
export interface GpCommand {
  readonly playerId: string;
  readonly operationName: string;
  readonly operationVersion: number;
  readonly idempotencyKey: string;
  readonly amount: number;
  readonly reason: string;
  readonly sourceType: string;
  readonly sourceId: string;
  // Stable, already resolved business identity, not a freshly derived current period.
  readonly context: { readonly [key: string]: JsonValue };
}

export class InvalidGpIntent extends Error {
  constructor() { super('Invalid internal GP intent.'); }
}

const identifier = (value: unknown): value is string =>
  typeof value === 'string' && value.length >= 1 && value.length <= 128 && !/[^A-Za-z0-9._:-]/.test(value);

function jsonString(value: string): string {
  // PostgreSQL jsonb cannot represent NUL or unpaired UTF-16 surrogates. Reject
  // rather than fingerprinting a replacement character or failing at transport.
  if (value.includes('\0') || Array.from(value).some((char) =>
    char.length === 1 && char.charCodeAt(0) >= 0xd800 && char.charCodeAt(0) <= 0xdfff)) throw new InvalidGpIntent();
  return JSON.stringify(value);
}

/** V1 uses JSON's distinct types, sorted object keys and ordered arrays. No coercion. */
export function canonicalIntent(value: unknown, depth = 0): string {
  if (depth > 16) throw new InvalidGpIntent();
  if (typeof value === 'string') return jsonString(value);
  if (value === null || typeof value === 'boolean') return JSON.stringify(value);
  if (typeof value === 'number' && Number.isSafeInteger(value)) return JSON.stringify(value);
  if (typeof value !== 'object' || value === null) throw new InvalidGpIntent();
  if (Array.isArray(value)) {
    // Sparse arrays and extra properties are not JSON intent.
    if (Object.keys(value).length !== value.length || Reflect.ownKeys(value).length !== value.length + 1) throw new InvalidGpIntent();
    return '[' + Array.from(value, (item) => canonicalIntent(item, depth + 1)).join(',') + ']';
  }
  if (Object.getPrototypeOf(value) !== Object.prototype && Object.getPrototypeOf(value) !== null) throw new InvalidGpIntent();
  if (Reflect.ownKeys(value).length !== Object.keys(value).length) throw new InvalidGpIntent();
  return '{' + Object.keys(value).sort().map((key) => {
    const descriptor = Object.getOwnPropertyDescriptor(value, key)!;
    if (!('value' in descriptor)) throw new InvalidGpIntent();
    return jsonString(key) + ':' + canonicalIntent(descriptor.value, depth + 1);
  }).join(',') + '}';
}

export function prepareGpIntent(command: GpCommand, direction: 'credit' | 'debit') {
  if (!command || typeof command.playerId !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(command.playerId) ||
      !identifier(command.operationName) || !identifier(command.idempotencyKey) ||
      !Number.isInteger(command.operationVersion) || command.operationVersion <= 0 || command.operationVersion > gpIntegerMax ||
      !Number.isInteger(command.amount) || command.amount <= 0 || command.amount > gpIntegerMax ||
      !identifier(command.reason) || !identifier(command.sourceType) ||
      command.reason === 'opening_snapshot' || command.sourceType === 'opening_snapshot' ||
      typeof command.sourceId !== 'string' || Array.from(command.sourceId).length < 1 ||
      Array.from(command.sourceId).length > 256 || command.sourceId !== command.sourceId.trim() ||
      /\p{Cc}/u.test(command.sourceId) || !command.context || typeof command.context !== 'object' ||
      Array.isArray(command.context)) throw new InvalidGpIntent();
  const encoded = canonicalIntent({
    format: 'stoppy.gp.intent', version: gpFingerprintVersion, direction,
    playerId: command.playerId, operationName: command.operationName, operationVersion: command.operationVersion,
    amount: command.amount, reason: command.reason, sourceType: command.sourceType, sourceId: command.sourceId,
    context: command.context,
  });
  if (Buffer.byteLength(encoded) > 16384) throw new InvalidGpIntent();
  // Snapshot before the first await; caller mutation cannot change what is executed.
  const snapshot = JSON.parse(encoded) as GpCommand & { direction: 'credit' | 'debit' };
  return { command: { ...snapshot, idempotencyKey: command.idempotencyKey },
    fingerprint: createHash('sha256').update(encoded).digest('hex') };
}
