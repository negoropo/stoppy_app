import { ApiError } from './api_error.js';

export class RequestRateLimiter {
  private readonly windows = new Map<string, { count: number; endsAt: number }>();
  constructor(private readonly message: string, private readonly now: () => number = Date.now,
    private readonly capacity = 10000) {}

  consume(key: string, limit: number): void {
    const now = this.now();
    let window = this.windows.get(key);
    if (!window || window.endsAt <= now) {
      if (this.windows.size >= this.capacity) {
        for (const [candidate, value] of this.windows) if (value.endsAt <= now) this.windows.delete(candidate);
      }
      // Do not evict live buckets, as a caller could otherwise reset its limit.
      if (!this.windows.has(key) && this.windows.size >= this.capacity) this.reject();
      window = { count: 0, endsAt: now + 60000 };
      this.windows.set(key, window);
    }
    if (++window.count > limit) this.reject();
  }

  private reject(): never { throw new ApiError('rateLimited', this.message, 429); }
}
