import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

dayjs.extend(utc);

export const DATE_FORMAT = 'YYYY-MM-DD';

/**
 * Narrows any instant to the UTC midnight of its local calendar day, which is
 * the key shape `HabitEntry.date` (`@db.Date`) and `@@unique([habitId, date])`
 * expect.
 */
export const standardizeDate = (date: string | Date): Date =>
  new Date(`${dayjs(date).format(DATE_FORMAT)}T00:00:00.000Z`);

/**
 * Evaluated per call. A module-level constant would pin a long-running process
 * to the day it booted.
 */
export const today = (): Date => standardizeDate(new Date());

/**
 * Reads a stored day key back. UTC, because that is how it was written —
 * formatting in local time shifts the day for anyone west of Greenwich.
 */
export const formatDate = (date: Date): string =>
  dayjs(date).utc().format(DATE_FORMAT);
