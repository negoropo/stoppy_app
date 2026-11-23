import { createHash } from 'node:crypto';
import { RequestRateLimiter } from '../request_rate_limiter.js';

export class AuthRateLimiter {
  private readonly limiter: RequestRateLimiter;
  constructor(now: () => number = Date.now, capacity = 10000) {
    this.limiter = new RequestRateLimiter('Too many authentication attempts. Please try again later.', now, capacity);
  }

  checkIp(ip: string): void { this.limiter.consume(`ip:${ip}`, 30); }

  checkAccount(body: unknown): void {
    if (body && typeof body === 'object' && 'username' in body && typeof body.username === 'string') {
      const canonical = body.username.trim().slice(0, 256).toLowerCase();
      this.limiter.consume('account:' + createHash('sha256').update(canonical).digest('hex'), 10);
    }
  }
}
