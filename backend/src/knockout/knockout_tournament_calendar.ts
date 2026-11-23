const lisbon = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Europe/Lisbon',
  calendar: 'gregory',
  numberingSystem: 'latn',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
  era: 'short',
});

function civilDate(value: string): Date {
  if (typeof value !== 'string' || !/^(?!0000)\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new RangeError('Expected a civil date in YYYY-MM-DD format.');
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw new RangeError('Invalid civil date.');
  }
  return date;
}

/** Validate the date label stored by PostgreSQL, independently of any instant. */
export function tournamentMonthLabel(value: string): string {
  if (civilDate(value).getUTCDate() !== 1) {
    throw new RangeError('Tournament month must be the first civil day.');
  }
  return value;
}

function lisbonWallTimeAsUtc(instant: Date): Date {
  const parts = Object.fromEntries(lisbon.formatToParts(instant).map(({ type, value }) => [type, value]));
  const year = parts.era === 'BC' ? 1 - Number(parts.year) : Number(parts.year);
  const wallTime = new Date(0);
  wallTime.setUTCFullYear(year, Number(parts.month) - 1, Number(parts.day));
  wallTime.setUTCHours(Number(parts.hour), Number(parts.minute), Number(parts.second));
  return wallTime;
}

export function tournamentMonthAt(instant: Date): string {
  const wallDate = lisbonWallTimeAsUtc(instant).toISOString();
  return tournamentMonthLabel(`${wallDate.slice(0, 7)}-01`);
}

/** UTC is only a scratch calendar for adding civil days to a date label. */
export function addCivilDays(value: string, days: number): string {
  const date = civilDate(value);
  if (!Number.isSafeInteger(days)) throw new RangeError('Civil day offset must be an integer.');
  date.setUTCDate(date.getUTCDate() + days);
  const shifted = date.toISOString().split('T')[0]!;
  civilDate(shifted);
  return shifted;
}

export function lisbonDayStart(value: string): Date {
  const nominal = civilDate(value).getTime();
  const dayMs = 24 * 60 * 60 * 1000;
  // Try the Lisbon offsets on both sides of the requested midnight. An offset
  // determined at UTC midnight alone can be wrong on a clock-change date.
  // Round-trip candidates so skipped or repeated midnights require a policy.
  const candidates = new Set<number>();
  for (const delta of [-dayMs, 0, dayMs]) {
    const sample = nominal + delta;
    const offset = lisbonWallTimeAsUtc(new Date(sample)).getTime() - sample;
    const candidate = nominal - offset;
    if (lisbonWallTimeAsUtc(new Date(candidate)).getTime() === nominal) candidates.add(candidate);
  }
  if (candidates.size !== 1) throw new RangeError('Lisbon midnight must resolve to exactly one instant.');
  return new Date([...candidates][0]!);
}
