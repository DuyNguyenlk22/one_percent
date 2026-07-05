import dayjs from 'dayjs';

export const DATE_FORMAT = 'YYYY-MM-DD';
export const TODAY = dayjs().format(DATE_FORMAT);

export const standardizeDate = (date: string) => {
  return dayjs(date).toISOString();
};
