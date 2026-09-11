import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';
import { IsPassword } from './validators';

export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty()
  @ApiProperty({ description: 'The token returned by /auth/verify-reset-code' })
  resetToken: string;

  @IsPassword()
  newPassword: string;
}
