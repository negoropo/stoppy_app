import argon2 from 'argon2';
import { ApiError } from '../api_error.js';

export interface PasswordHasher {
  hash(password: string): Promise<string>;
  verify(hash: string | null, password: string): Promise<boolean>;
}

export class ArgonPasswordHasher implements PasswordHasher {
  private active = 0;
  // Public dummy hash, not an account credential. Precomputation avoids giving
  // the first unknown account a distinct extra-hash timing path.
  private readonly dummy = '$argon2id$v=19$m=19456,p=1,t=2$k83gbxF4yHvbIDgYcukGZg$EffI1XgCQIVtk5AD5tz5QzBlDADDzE30yWcm6E+SdrM';
  private readonly options = { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 } as const;

  private async bounded<T>(work: () => Promise<T>): Promise<T> {
    // Reject overload instead of creating an unbounded queue of memory-hard work.
    if (this.active >= 2) throw new ApiError('rateLimited', 'Authentication is busy. Please try again later.', 429);
    this.active++;
    try { return await work(); } finally { this.active--; }
  }

  hash(password: string): Promise<string> {
    return this.bounded(() => argon2.hash(password, this.options));
  }

  verify(hash: string | null, password: string): Promise<boolean> {
    return this.bounded(async () => {
      // Unknown accounts still perform a real Argon2 verification. No user-specific timing shortcut.
      const candidate = hash ?? this.dummy;
      const verified = await argon2.verify(candidate, password);
      return hash !== null && verified;
    });
  }
}
