import { IsEmailAddress, IsPassword } from './validators';

export class LoginAuthDto {
  @IsEmailAddress()
  email: string;

  @IsPassword()
  password: string;
}
