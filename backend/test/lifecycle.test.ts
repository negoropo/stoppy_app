import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { setImmediate as nextTurn } from 'node:timers/promises';
import { installShutdownHandlers } from '../src/lifecycle.js';

test('SIGINT/SIGTERM coalesce cleanup and cancel deadline only after successful close', async (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  const signals = new EventEmitter();
  let finish!: () => void;
  const closing = new Promise<void>((resolve) => { finish = resolve; });
  let closes = 0;
  let forced = 0;
  const cleanup = installShutdownHandlers({ close: () => { closes++; return closing; } },
    signals, () => assert.fail('Unexpected shutdown failure'), () => { forced++; });
  try {
    signals.emit('SIGINT');
    signals.emit('SIGINT');
    signals.emit('SIGTERM');
    await nextTurn();
    assert.equal(closes, 1);
    context.mock.timers.tick(9999);
    assert.equal(forced, 0);
    finish();
    await nextTurn();
    context.mock.timers.tick(1);
    assert.equal(forced, 0);
    assert.equal(signals.listenerCount('SIGINT'), 0);
    assert.equal(signals.listenerCount('SIGTERM'), 0);
  } finally { cleanup(); }
});

test('failed shutdown reports no exception details and retains the forced-exit deadline', async (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  const signals = new EventEmitter();
  let closes = 0;
  let failures = 0;
  let forced = 0;
  const cleanup = installShutdownHandlers({ close: async () => { closes++; throw new Error('password=secret SQL'); } },
    signals, (...args: unknown[]) => { failures++; assert.deepEqual(args, []); }, () => { forced++; });
  try {
    signals.emit('SIGTERM');
    await nextTurn();
    assert.equal(failures, 1);
    signals.emit('SIGINT');
    assert.equal(closes, 1);
    context.mock.timers.tick(9999);
    assert.equal(forced, 0);
    context.mock.timers.tick(1);
    assert.equal(forced, 1);
  } finally { cleanup(); }
});

test('stalled shutdown remains bounded', async (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  let forced = 0;
  const signals = new EventEmitter();
  const cleanup = installShutdownHandlers({ close: () => new Promise(() => {}) }, signals,
    () => assert.fail('Unexpected rejection'), () => { forced++; });
  try {
    signals.emit('SIGTERM');
    await nextTurn();
    context.mock.timers.tick(10000);
    assert.equal(forced, 1);
  } finally { cleanup(); }
});

