import { User } from 'generated/prisma/client';
import { ApiProperty } from '@nestjs/swagger';

export type SafeUser = Omit<User, 'passwordHash'>;

export class AuthResponse {
  @ApiProperty()
  accessToken: string;

  @ApiProperty()
  user: SafeUser;
}

export class MessageResponse {
  @ApiProperty()
  message: string;
}

export class VerifyResetCodeResponse {
  @ApiProperty({
    description:
      'Short-lived token proving the code was verified. Pass it to /auth/reset-password.',
  })
  resetToken: string;
}

/** Claims carried by the token `verifyResetCode` issues. */
export interface ResetTokenPayload {
  userId: string;
  prcId: string;
  typ: string;
}
