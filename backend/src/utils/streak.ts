import { Dayjs } from 'dayjs';
import { formatDate } from './dayjs';

export const computeCurrentStreak = (dates: Date[], targetDate: Dayjs) => {
  const completedDays = new Set(dates.map((date) => formatDate(date)));

  let streak = 0;
  let current = targetDate;

  while (completedDays.has(current.format('YYYY-MM-DD'))) {
    streak++;
    current = current.subtract(1, 'day');
  }

  return streak;
};
