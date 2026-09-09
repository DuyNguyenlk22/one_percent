import { formatDate, standardizeDate, today } from './dayjs';

describe('standardizeDate', () => {
  it('returns UTC midnight for a plain YYYY-MM-DD string', () => {
    expect(standardizeDate('2026-03-14').toISOString()).toBe(
      '2026-03-14T00:00:00.000Z',
    );
  });

  it('keeps the local calendar day of a Date and drops the time', () => {
    const localNoon = new Date(2026, 2, 14, 12, 0, 0);
    expect(standardizeDate(localNoon).toISOString()).toBe(
      '2026-03-14T00:00:00.000Z',
    );
  });
});

describe('formatDate', () => {
  it('reads the day key in UTC, so a stored DATE never shifts', () => {
    expect(formatDate(new Date('2026-03-14T00:00:00.000Z'))).toBe('2026-03-14');
  });
});

describe('today', () => {
  it('is a function, so a long-running process does not keep its boot day', () => {
    expect(typeof today).toBe('function');
    expect(today().toISOString()).toBe(
      standardizeDate(new Date()).toISOString(),
    );
  });
});
