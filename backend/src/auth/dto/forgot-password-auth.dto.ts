import { IsEmail, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class ForgotPasswordAuthDto {
  @IsEmail({}, { message: 'Please provide a valid email' })
  @IsNotEmpty()
  @ApiProperty()
  email: string;
}
