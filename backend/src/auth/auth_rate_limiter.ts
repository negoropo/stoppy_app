import { createHash } from 'node:crypto';
import { ApiError } from '../api_error.js';

export class AuthRateLimiter {
  private readonly windows = new Map<string, { count: number; endsAt: number }>();
  constructor(private readonly now: () => number = Date.now, private readonly capacity = 10000) {}

  private consume(key: string, limit: number): void {
    const now = this.now();
    let window = this.windows.get(key);
    if (!window || window.endsAt <= now) {
      if (this.windows.size >= this.capacity) {
        for (const [candidate, value] of this.windows) if (value.endsAt <= now) this.windows.delete(candidate);
      }
      // Do not evict live buckets: an attacker could otherwise reset its own limit.
      if (!this.windows.has(key) && this.windows.size >= this.capacity) this.reject();
      window = { count: 0, endsAt: now + 60000 };
      this.windows.set(key, window);
    }
    if (++window.count > limit) this.reject();
  }

  private reject(): never { throw new ApiError('rateLimited', 'Too many authentication attempts. Please try again later.', 429); }

  checkIp(ip: string): void { this.consume(`ip:${ip}`, 30); }

  checkAccount(body: unknown): void {
    if (body && typeof body === 'object' && 'username' in body && typeof body.username === 'string') {
      const canonical = body.username.trim().slice(0, 256).toLowerCase();
      this.consume('account:' + createHash('sha256').update(canonical).digest('hex'), 10);
    }
  }
}
