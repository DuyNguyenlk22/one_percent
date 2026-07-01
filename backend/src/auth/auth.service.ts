/* eslint-disable @typescript-eslint/no-unused-vars */
import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from 'src/prisma.service';
import { AuthResponse, SafeUser } from './types/auth.types';
import { JwtService } from '@nestjs/jwt';
import { omit } from 'lodash';
import { comparePassword, hashingPassword } from 'src/utils';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
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

    const accessToken = await this.jwtService.signAsync({ id: user.id });

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
}
