import dayjs from 'dayjs';

export const DATE_FORMAT = 'YYYY-MM-DD';
export const TODAY = dayjs().toISOString();

export const standardizeDate = (date: string | Date) => {
  return dayjs(date).toISOString();
};

export const formatDate = (date: Date) => {
  return dayjs(date).format(DATE_FORMAT);
};
