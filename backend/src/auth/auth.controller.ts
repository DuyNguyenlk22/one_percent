import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  Get,
  UseGuards,
} from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginAuthDto } from './dto/login-auth.dto';
import { RegisterAuthDto } from './dto/register-auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import {
  AuthResponse,
  MessageResponse,
  VerifyResetCodeResponse,
} from './types/auth.types';
import { CurrentUser } from 'src/common/decorators';
import { ForgotPasswordAuthDto } from './dto/forgot-password-auth.dto';
import { VerifyResetCodeDto } from './dto/verify-reset-code.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Controller('auth')
@ApiTags('Auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('/login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() body: LoginAuthDto) {
    return await this.authService.login(body.email, body.password);
  }

  @Post('/register')
  @ApiCreatedResponse({ type: AuthResponse })
  async register(@Body() body: RegisterAuthDto) {
    return this.authService.register(body.email, body.password);
  }

  /**
   * Throttled alongside verify-reset-code: the per-row attempt cap stops one
   * code being guessed, the throttle stops an attacker cycling fresh codes.
   */
  @Post('/forgot-password')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Email a password reset code',
    description:
      'Always succeeds with the same message, whether or not the address is registered.',
  })
  @ApiOkResponse({ type: MessageResponse })
  forgotPassword(@Body() { email }: ForgotPasswordAuthDto) {
    return this.authService.forgotPassword(email);
  }

  @Post('/verify-reset-code')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Exchange a reset code for a short-lived reset token',
  })
  @ApiOkResponse({ type: VerifyResetCodeResponse })
  verifyResetCode(@Body() { email, code }: VerifyResetCodeDto) {
    return this.authService.verifyResetCode(email, code);
  }

  @Post('/reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Set a new password using a reset token',
    description:
      'Returns no access token on purpose — the user signs in again with the new password.',
  })
  @ApiOkResponse({ type: MessageResponse })
  resetPassword(@Body() { resetToken, newPassword }: ResetPasswordDto) {
    return this.authService.resetPassword(resetToken, newPassword);
  }

  @Get('/me')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async getProfile(@CurrentUser('id') userId: string) {
    return this.authService.getProfile(userId);
  }
}
