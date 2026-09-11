import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PassportModule } from '@nestjs/passport';
import { JwtModule, JwtModuleOptions } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { JwtStrategy } from './jwt.strategy';
import { PrismaService } from 'src/prisma.service';
import { EmailModule } from 'src/email/email.module';

@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],

      useFactory: (
        config: ConfigService,
      ): Promise<JwtModuleOptions> | JwtModuleOptions => ({
        secret: config.get('JWT_SECRET'),

        signOptions: {
          expiresIn: config.get('JWT_EXPIRES_IN'),
        },
      }),
    }),
    PassportModule,
    EmailModule,
    // Applied per-route via `@UseGuards(ThrottlerGuard)` on the password reset
    // endpoints rather than as a global guard, so the rest of the API keeps its
    // current behaviour.
    ThrottlerModule.forRoot({
      errorMessage: 'Too many requests. Please try again in a minute.',
      throttlers: [{ ttl: 60_000, limit: 5 }],
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, PrismaService],
})
export class AuthModule {}
