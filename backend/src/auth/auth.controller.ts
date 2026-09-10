import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  Get,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginAuthDto } from './dto/login-auth.dto';
import { RegisterAuthDto } from './dto/register-auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { ApiBearerAuth, ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { AuthResponse } from './types/auth.types';
import { CurrentUser } from 'src/common/decorators';
import { ForgotPasswordAuthDto } from './dto/forgot-password-auth.dto';

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

  @Post('/forgot-password')
  @ApiCreatedResponse({ type: AuthResponse })
  forgotPassword(@Body() { email }: ForgotPasswordAuthDto) {
    return `Forgot password functionality is not implemented yet. ${email}`;
  }

  @Get('/me')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async getProfile(@CurrentUser('id') userId: string) {
    return this.authService.getProfile(userId);
  }
}
