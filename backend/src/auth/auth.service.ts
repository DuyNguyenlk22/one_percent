/* eslint-disable @typescript-eslint/no-unused-vars */
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from 'src/prisma.service';
import {
  AuthResponse,
  MessageResponse,
  ResetTokenPayload,
  SafeUser,
  VerifyResetCodeResponse,
} from './types/auth.types';
import { JwtService } from '@nestjs/jwt';
import { omit } from 'lodash';
import { comparePassword, hashingPassword } from 'src/utils';
import { randomInt } from 'node:crypto';
import { EmailService } from 'src/email/email.service';
import dayjs from 'dayjs';

/** How long an emailed code stays usable. */
const CODE_TTL_MINUTES = 5;
/** Minimum gap between two sends for the same user. */
const RESEND_COOLDOWN_SECONDS = 60;
/** Failed verifications that kill a code. */
const MAX_ATTEMPTS = 5;
/** The reset-token claim type, checked so an access token cannot stand in. */
const RESET_TOKEN_TYPE = 'pwd_reset';

/**
 * Returned by `forgotPassword` whether or not the address is registered, so the
 * response cannot be used to enumerate accounts.
 */
const GENERIC_FORGOT_MESSAGE =
  'If that email is registered, a reset code is on its way.';

/**
 * The single failure message for every rejected verification — unknown user,
 * missing row, expired, attempts exhausted, wrong code. Distinguishing them
 * would hand an attacker exactly the signal the generic response withholds.
 */
const INVALID_CODE_MESSAGE = 'Invalid or expired code';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private config: ConfigService,
    private emailService: EmailService,
  ) {}

  async login(email: string, pwd: string): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw new NotFoundException(`No user found for email: ${email}`);
    }

    const isPwdValid = await comparePassword(pwd, user.passwordHash);

    if (!isPwdValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return {
      user: omit(user, ['passwordHash']),
      accessToken: this.jwtService.sign({ userId: user.id }),
    };
  }

  async register(email: string, pwd: string): Promise<AuthResponse> {
    const existedUser = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existedUser) {
      throw new ConflictException('Email already exists');
    }

    const hash = await hashingPassword(pwd);

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash: hash,
      },
    });

    const accessToken = await this.jwtService.signAsync({ userId: user.id });

    return {
      user: omit(user, ['passwordHash']),
      accessToken,
    };
  }

  async validateUser(userId: string): Promise<any> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (user) {
      const { passwordHash, ...result } = user;
      return result;
    }
    return null;
  }

  async getProfile(userId: string): Promise<SafeUser> {
    const user = await this.prisma.user.findUnique({
      where: {
        id: userId,
      },
      omit: {
        passwordHash: true,
      },
    });

    if (!user) {
      throw new NotFoundException(`User not found with ID: ${userId}`);
    }

    return user;
  }

  /**
   * Step 1 of 3. Always resolves with the same message: an unregistered address
   * and a failing SMTP host are both indistinguishable from success.
   */
  async forgotPassword(email: string): Promise<MessageResponse> {
    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user) {
      return { message: GENERIC_FORGOT_MESSAGE };
    }

    const latest = await this.prisma.passwordResetCode.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });

    const withinCooldown =
      latest !== null &&
      dayjs().diff(latest.createdAt, 'second') < RESEND_COOLDOWN_SECONDS;

    if (withinCooldown) {
      return { message: GENERIC_FORGOT_MESSAGE };
    }

    // A new request retires every code the user might still be holding.
    await this.prisma.passwordResetCode.updateMany({
      where: { userId: user.id, consumedAt: null },
      data: { consumedAt: dayjs().toDate() },
    });

    // randomInt, not Math.random: this value guards an account.
    const code = randomInt(100000, 1000000).toString();

    await this.prisma.passwordResetCode.create({
      data: {
        userId: user.id,
        codeHash: await hashingPassword(code),
        expiresAt: dayjs().add(CODE_TTL_MINUTES, 'minute').toDate(),
      },
    });

    await this.emailService.sendPasswordResetCode(email, code);

    return { message: GENERIC_FORGOT_MESSAGE };
  }

  /**
   * Step 2 of 3. Trades a correct code for a short-lived reset token, so the
   * code itself crosses the wire only once.
   */
  async verifyResetCode(
    email: string,
    code: string,
  ): Promise<VerifyResetCodeResponse> {
    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user) {
      throw new BadRequestException(INVALID_CODE_MESSAGE);
    }

    const resetCode = await this.prisma.passwordResetCode.findFirst({
      where: { userId: user.id, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    // `!isBefore` rather than `isAfter`: an expiry landing on this exact
    // millisecond is expired, not still live.
    if (
      !resetCode ||
      !dayjs().isBefore(resetCode.expiresAt) ||
      resetCode.attempts >= MAX_ATTEMPTS
    ) {
      throw new BadRequestException(INVALID_CODE_MESSAGE);
    }

    const isCodeValid = await comparePassword(code, resetCode.codeHash);

    if (!isCodeValid) {
      await this.prisma.passwordResetCode.update({
        where: { id: resetCode.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException(INVALID_CODE_MESSAGE);
    }

    // Restamped rather than set once, so back-navigation in the app can
    // re-verify an unexpired code instead of stranding the user.
    await this.prisma.passwordResetCode.update({
      where: { id: resetCode.id },
      data: { verifiedAt: dayjs().toDate() },
    });

    const resetToken = await this.jwtService.signAsync(
      { userId: user.id, prcId: resetCode.id, typ: RESET_TOKEN_TYPE },
      {
        secret: this.config.get<string>('JWT_RESET_SECRET'),
        expiresIn: '10m',
      },
    );

    return { resetToken };
  }

  /**
   * Step 3 of 3. Deliberately issues no access token: the user signs in again,
   * which proves the new password works and keeps one sign-in path.
   */
  async resetPassword(
    resetToken: string,
    newPassword: string,
  ): Promise<MessageResponse> {
    let payload: ResetTokenPayload;

    try {
      payload = await this.jwtService.verifyAsync<ResetTokenPayload>(
        resetToken,
        { secret: this.config.get<string>('JWT_RESET_SECRET') },
      );
    } catch {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    if (payload.typ !== RESET_TOKEN_TYPE) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    const resetCode = await this.prisma.passwordResetCode.findUnique({
      where: { id: payload.prcId },
    });

    if (
      !resetCode ||
      resetCode.userId !== payload.userId ||
      !resetCode.verifiedAt ||
      resetCode.consumedAt
    ) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    // Hashed outside the transaction: bcrypt is deliberately slow and there is
    // no reason to hold a write transaction open for it.
    const passwordHash = await hashingPassword(newPassword);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: resetCode.userId },
        data: { passwordHash },
      }),
      this.prisma.passwordResetCode.update({
        where: { id: resetCode.id },
        data: { consumedAt: dayjs().toDate() },
      }),
    ]);

    return {
      message: 'Password updated. Sign in with your new password.',
    };
  }
}
