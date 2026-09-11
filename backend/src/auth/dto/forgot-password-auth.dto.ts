import { IsEmailAddress } from './validators';

export class ForgotPasswordAuthDto {
  @IsEmailAddress()
  email: string;
}
