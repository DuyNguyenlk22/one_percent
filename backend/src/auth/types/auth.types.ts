import { User } from 'generated/prisma/client';
import { ApiProperty } from '@nestjs/swagger';

export type SafeUser = Omit<User, 'passwordHash'>;

export class AuthResponse {
  @ApiProperty()
  accessToken: string;

  @ApiProperty()
  user: SafeUser;
}
