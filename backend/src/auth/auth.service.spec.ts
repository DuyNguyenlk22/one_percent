import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { PrismaService } from 'src/prisma.service';

describe('AuthService token claims', () => {
  const user = {
    id: 'aaaaaaaa-0000-4000-8000-000000000001',
    email: 'alex@example.com',
    passwordHash: '$2b$10$abcdefghijklmnopqrstuv',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };

  let service: AuthService;
  let jwt: { sign: jest.Mock; signAsync: jest.Mock };
  let prisma: { user: { findUnique: jest.Mock; create: jest.Mock } };

  beforeEach(async () => {
    jwt = {
      sign: jest.fn().mockReturnValue('token'),
      signAsync: jest.fn().mockResolvedValue('token'),
    };
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(user),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('register signs the userId claim JwtStrategy reads', async () => {
    await service.register(user.email, 'password123');

    expect(jwt.signAsync).toHaveBeenCalledWith({ userId: user.id });
  });

  it('register never leaks the password hash', async () => {
    const response = await service.register(user.email, 'password123');

    expect(response.user).not.toHaveProperty('passwordHash');
  });
});
