import { HabitModel } from 'generated/prisma/models';

/**
 * A habit row as `GET /habits?date=` returns it.
 *
 * `getHabits` answers with one shape or the other depending on whether a date
 * was asked for, so naming the decorated one lets callers narrow the union
 * instead of casting.
 */
export type DecoratedHabit = HabitModel & {
  doneToday: boolean;
  currentStreak: number;
};
