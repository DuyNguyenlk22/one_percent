import { User } from 'generated/prisma/client';

export type SafeUser = Omit<User, 'passwordHash'>;

export type LoginResult = {
  accessToken: string;
  user: SafeUser;
};
