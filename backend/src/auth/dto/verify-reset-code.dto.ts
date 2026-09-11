import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';
import { IsEmailAddress } from './validators';

export class VerifyResetCodeDto {
  @IsEmailAddress()
  email: string;

  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{6}$/, { message: 'Code must be 6 digits' })
  @ApiProperty({ example: '481920' })
  code: string;
}
