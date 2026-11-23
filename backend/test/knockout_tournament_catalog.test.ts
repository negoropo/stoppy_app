import assert from 'node:assert/strict';
import { test } from 'node:test';
import { addCivilDays, lisbonDayStart, tournamentMonthAt, tournamentMonthLabel } from '../src/knockout/knockout_tournament_calendar.js';
import { KnockoutTournamentCatalog } from '../src/knockout/knockout_tournament_catalog.js';
import { FakeDatabase } from './fakes.js';

test('tournament month labels reject noncanonical and invalid dates', () => {
  assert.equal(tournamentMonthLabel('2024-02-01'), '2024-02-01');
  for (const value of ['2024-2-01', '2024-02', '2024-02-02', '2024-13-01', '0000-01-01', '2024-02-01T00:00Z']) {
    assert.throws(() => tournamentMonthLabel(value), RangeError);
  }
  assert.throws(() => addCivilDays('2023-02-29', 1), RangeError);
  assert.throws(() => addCivilDays('2024-03-31', 0.5), RangeError);
  assert.equal(addCivilDays('2024-02-28', 1), '2024-02-29');
  assert.equal(addCivilDays('2024-12-31', 1), '2025-01-01');
});

test('Lisbon month and absolute day boundaries are independent of process timezone', () => {
  const original = process.env.TZ;
  try {
    for (const timezone of ['UTC', 'America/Los_Angeles', 'Asia/Tokyo']) {
      process.env.TZ = timezone;
      assert.equal(tournamentMonthAt(new Date('2024-06-30T22:59:59.999Z')), '2024-06-01');
      assert.equal(tournamentMonthAt(new Date('2024-06-30T23:00:00Z')), '2024-07-01');
      assert.equal(tournamentMonthAt(new Date('2024-12-31T23:59:59.999Z')), '2024-12-01');
      assert.equal(tournamentMonthAt(lisbonDayStart('2025-01-01')), '2025-01-01');
      assert.equal(lisbonDayStart('2024-07-01').toISOString(), '2024-06-30T23:00:00.000Z');
      assert.equal(lisbonDayStart('2025-01-01').toISOString(), '2025-01-01T00:00:00.000Z');
    }
  } finally {
    if (original === undefined) delete process.env.TZ;
    else process.env.TZ = original;
  }
});

test('Lisbon civil days span 23 or 25 hours across daylight-saving changes', () => {
  for (const [day, start, nextStart, hours] of [
    ['2024-03-31', '2024-03-31T00:00:00.000Z', '2024-03-31T23:00:00.000Z', 23],
    ['2024-10-27', '2024-10-26T23:00:00.000Z', '2024-10-28T00:00:00.000Z', 25],
  ] as const) {
    const first = lisbonDayStart(day);
    const next = lisbonDayStart(addCivilDays(day, 1));
    assert.equal(first.toISOString(), start);
    assert.equal(next.toISOString(), nextStart);
    assert.equal((next.getTime() - first.getTime()) / 3_600_000, hours);
  }
});

test('catalog validates schedule and transition targets before acquiring a connection', async () => {
  const database = new FakeDatabase();
  const catalog = new KnockoutTournamentCatalog(database);
  const valid = {
    tournamentMonth: '2024-07-01',
    name: 'July Knockout',
    registrationOpensAt: lisbonDayStart('2024-06-15'),
    registrationClosesAt: new Date('2024-06-30T22:59:00Z'),
    startsAt: lisbonDayStart('2024-07-01'),
  };
  for (const changes of [
    { name: '   ' },
    { name: 'x'.repeat(129) },
    { name: 'invalid\0name' },
    { tournamentMonth: '2024-07-02' },
    { tournamentMonth: '2024-06-01' },
    { registrationOpensAt: new Date(NaN) },
    { registrationClosesAt: valid.registrationOpensAt },
    { registrationClosesAt: valid.startsAt },
    { registrationClosesAt: new Date('2024-07-01T01:00:00Z') },
  ]) {
    await assert.rejects(catalog.provision({ ...valid, ...changes }), { code: 'invalidInput' });
  }
  await assert.rejects(catalog.transition('invalid', 'registrationOpen'), { code: 'invalidInput' });
  // JavaScript callers can supply a target outside the TypeScript union.
  await assert.rejects(Reflect.apply(catalog.transition, catalog,
    ['12345678-abcd-4321-abcd-987654321abc', 'completed']), { code: 'invalidInput' });
  assert.equal(database.connections, 0);
});
