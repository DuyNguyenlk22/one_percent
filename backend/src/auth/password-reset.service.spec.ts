/**
 * The FakePrisma double below mirrors Prisma's loosely-typed query arguments
 * (`{ where, data, orderBy }`), so the unsafe-* rules are off for this file.
 */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-return */
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { EmailService } from 'src/email/email.service';
import { PrismaService } from 'src/prisma.service';
import { hashingPassword } from 'src/utils';

const ACCESS_SECRET = 'access-secret';
const RESET_SECRET = 'reset-secret';

const GENERIC_MESSAGE =
  'If that email is registered, a reset code is on its way.';
const INVALID_CODE_MESSAGE = 'Invalid or expired code';

type StoredUser = { id: string; email: string; passwordHash: string };
type StoredCode = {
  id: string;
  seq: number;
  userId: string;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
  verifiedAt: Date | null;
  consumedAt: Date | null;
  createdAt: Date;
};

/**
 * An in-memory stand-in for the two tables this feature touches. Assertions can
 * then read back what was actually stored — which row got consumed, what
 * `attempts` reached — instead of inspecting mock call arguments.
 */
class FakePrisma {
  users: StoredUser[] = [];
  codes: StoredCode[] = [];
  private seq = 0;

  user = {
    findUnique: ({ where }: any) =>
      Promise.resolve(
        this.users.find(
          (u) =>
            (where.id !== undefined && u.id === where.id) ||
            (where.email !== undefined && u.email === where.email),
        ) ?? null,
      ),
    update: ({ where, data }: any) => {
      const user = this.users.find((u) => u.id === where.id);
      if (!user) throw new Error(`no user ${where.id}`);
      Object.assign(user, data);
      return Promise.resolve(user);
    },
  };

  passwordResetCode = {
    findFirst: ({ where }: any) =>
      Promise.resolve(
        this.matching(where).sort((a, b) => b.seq - a.seq)[0] ?? null,
      ),
    findUnique: ({ where }: any) =>
      Promise.resolve(this.codes.find((c) => c.id === where.id) ?? null),
    create: ({ data }: any) => {
      const row: StoredCode = {
        id: `prc-${this.seq}`,
        seq: this.seq++,
        attempts: 0,
        verifiedAt: null,
        consumedAt: null,
        createdAt: new Date(),
        ...data,
      };
      this.codes.push(row);
      return Promise.resolve(row);
    },
    update: ({ where, data }: any) => {
      const row = this.codes.find((c) => c.id === where.id);
      if (!row) throw new Error(`no reset code ${where.id}`);
      this.apply(row, data);
      return Promise.resolve(row);
    },
    updateMany: ({ where, data }: any) => {
      const rows = this.matching(where);
      rows.forEach((row) => this.apply(row, data));
      return Promise.resolve({ count: rows.length });
    },
  };

  $transaction = (operations: Promise<unknown>[]) => Promise.all(operations);

  private matching(where: any = {}): StoredCode[] {
    return this.codes.filter(
      (c) =>
        (where.userId === undefined || c.userId === where.userId) &&
        (where.consumedAt === undefined || c.consumedAt === where.consumedAt),
    );
  }

  /** Supports the `{ increment: n }` form the service uses for `attempts`. */
  private apply(row: StoredCode, data: any): void {
    for (const [key, value] of Object.entries(data)) {
      if (value && typeof value === 'object' && 'increment' in value) {
        (row as any)[key] += (value as { increment: number }).increment;
      } else {
        (row as any)[key] = value;
      }
    }
  }
}

describe('AuthService password reset', () => {
  let service: AuthService;
  let prisma: FakePrisma;
  let sent: { to: string; code: string }[];
  let user: StoredUser;

  /** The code most recently delivered by email — what the real user would type. */
  const lastCode = () => sent[sent.length - 1].code;
  const newestRow = () => prisma.codes[prisma.codes.length - 1];

  beforeEach(async () => {
    prisma = new FakePrisma();
    sent = [];
    user = {
      id: 'aaaaaaaa-0000-4000-8000-000000000001',
      email: 'alex@example.com',
      passwordHash: await hashingPassword('old-password'),
    };
    prisma.users.push(user);

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: JwtService,
          useValue: new JwtService({ secret: ACCESS_SECRET }),
        },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) =>
              ({
                JWT_SECRET: ACCESS_SECRET,
                JWT_RESET_SECRET: RESET_SECRET,
              })[key],
          },
        },
        {
          provide: EmailService,
          useValue: {
            sendPasswordResetCode: (to: string, code: string) => {
              sent.push({ to, code });
              return Promise.resolve();
            },
          },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('forgotPassword', () => {
    it('answers identically for a registered and an unregistered address', async () => {
      const registered = await service.forgotPassword(user.email);
      const unregistered = await service.forgotPassword('nobody@example.com');

      expect(registered).toEqual({ message: GENERIC_MESSAGE });
      expect(unregistered).toEqual(registered);
    });

    it('sends only for the registered address', async () => {
      await service.forgotPassword('nobody@example.com');
      expect(sent).toHaveLength(0);

      await service.forgotPassword(user.email);
      expect(sent).toEqual([
        { to: user.email, code: expect.stringMatching(/^\d{6}$/) },
      ]);
    });

    it('stores the code hashed, never in the clear', async () => {
      await service.forgotPassword(user.email);

      expect(newestRow().codeHash).not.toContain(lastCode());
    });

    it('expires the stored code 15 minutes out', async () => {
      const before = Date.now();
      await service.forgotPassword(user.email);

      const ttl = newestRow().expiresAt.getTime() - before;
      expect(ttl).toBeGreaterThan(14 * 60 * 1000);
      expect(ttl).toBeLessThanOrEqual(15 * 60 * 1000 + 1000);
    });

    it('consumes prior unconsumed rows when a new code is requested', async () => {
      await service.forgotPassword(user.email);
      const first = newestRow();
      backdate(first, 61_000);

      await service.forgotPassword(user.email);

      expect(first.consumedAt).toBeInstanceOf(Date);
      expect(newestRow().consumedAt).toBeNull();
      expect(prisma.codes).toHaveLength(2);
    });

    it('suppresses a resend inside 60 seconds of the previous request', async () => {
      await service.forgotPassword(user.email);

      const second = await service.forgotPassword(user.email);

      expect(second).toEqual({ message: GENERIC_MESSAGE });
      expect(sent).toHaveLength(1);
      expect(prisma.codes).toHaveLength(1);
    });

    it('allows a resend once the cooldown has elapsed', async () => {
      await service.forgotPassword(user.email);
      backdate(newestRow(), 61_000);

      await service.forgotPassword(user.email);

      expect(sent).toHaveLength(2);
      expect(prisma.codes).toHaveLength(2);
    });
  });

  describe('verifyResetCode', () => {
    it('returns a reset token for the correct code', async () => {
      await service.forgotPassword(user.email);

      const { resetToken } = await service.verifyResetCode(
        user.email,
        lastCode(),
      );

      expect(typeof resetToken).toBe('string');
      expect(newestRow().verifiedAt).toBeInstanceOf(Date);
    });

    it('issues a token JwtStrategy’s access secret will not accept', async () => {
      await service.forgotPassword(user.email);
      const { resetToken } = await service.verifyResetCode(
        user.email,
        lastCode(),
      );

      const asAccessToken = new JwtService({ secret: ACCESS_SECRET });
      expect(() => asAccessToken.verify(resetToken)).toThrow();

      const asResetToken = new JwtService({ secret: RESET_SECRET });
      expect(asResetToken.verify(resetToken)).toEqual(
        expect.objectContaining({
          userId: user.id,
          prcId: newestRow().id,
          typ: 'pwd_reset',
        }),
      );
    });

    it('rejects a wrong code and counts the attempt', async () => {
      await service.forgotPassword(user.email);

      await expect(
        service.verifyResetCode(user.email, '000000'),
      ).rejects.toThrow(INVALID_CODE_MESSAGE);
      expect(newestRow().attempts).toBe(1);
    });

    it('stops accepting the code once 5 attempts are spent', async () => {
      await service.forgotPassword(user.email);
      for (let i = 0; i < 5; i++) {
        await expect(
          service.verifyResetCode(user.email, '000000'),
        ).rejects.toThrow(INVALID_CODE_MESSAGE);
      }

      // The correct code no longer works either.
      await expect(
        service.verifyResetCode(user.email, lastCode()),
      ).rejects.toThrow(INVALID_CODE_MESSAGE);
      expect(newestRow().attempts).toBe(5);
    });

    it('rejects a code past its expiry', async () => {
      await service.forgotPassword(user.email);
      newestRow().expiresAt = new Date(Date.now() - 1000);

      await expect(
        service.verifyResetCode(user.email, lastCode()),
      ).rejects.toThrow(INVALID_CODE_MESSAGE);
    });

    it('rejects a code whose row was already consumed', async () => {
      await service.forgotPassword(user.email);
      const code = lastCode();
      newestRow().consumedAt = new Date();

      await expect(service.verifyResetCode(user.email, code)).rejects.toThrow(
        INVALID_CODE_MESSAGE,
      );
    });

    it('rejects an unknown address with the same message as a wrong code', async () => {
      await expect(
        service.verifyResetCode('nobody@example.com', '123456'),
      ).rejects.toThrow(INVALID_CODE_MESSAGE);
    });

    it('re-verifies a still-valid code so back-navigation is not a dead end', async () => {
      await service.forgotPassword(user.email);
      const first = await service.verifyResetCode(user.email, lastCode());

      const second = await service.verifyResetCode(user.email, lastCode());

      expect(second.resetToken).toEqual(expect.any(String));
      expect(first.resetToken).toEqual(expect.any(String));
    });
  });

  describe('resetPassword', () => {
    const verifiedToken = async (service: AuthService, email: string) => {
      const { resetToken } = await service.verifyResetCode(
        email,
        sentCode(sent),
      );
      return resetToken;
    };

    it('replaces the password and consumes the row', async () => {
      await service.forgotPassword(user.email);
      const resetToken = await verifiedToken(service, user.email);
      const previousHash = user.passwordHash;

      await service.resetPassword(resetToken, 'brand-new-password');

      expect(user.passwordHash).not.toBe(previousHash);
      expect(newestRow().consumedAt).toBeInstanceOf(Date);
    });

    it('lets the user log in with the new password afterwards', async () => {
      await service.forgotPassword(user.email);
      const resetToken = await verifiedToken(service, user.email);

      await service.resetPassword(resetToken, 'brand-new-password');

      await expect(
        service.login(user.email, 'brand-new-password'),
      ).resolves.toEqual(
        expect.objectContaining({ accessToken: expect.any(String) }),
      );
    });

    it('refuses to reuse the same reset token twice', async () => {
      await service.forgotPassword(user.email);
      const resetToken = await verifiedToken(service, user.email);
      await service.resetPassword(resetToken, 'brand-new-password');

      await expect(
        service.resetPassword(resetToken, 'another-password'),
      ).rejects.toThrow();
    });

    it('refuses a token whose row was never verified', async () => {
      await service.forgotPassword(user.email);
      const forged = new JwtService({ secret: RESET_SECRET }).sign({
        userId: user.id,
        prcId: newestRow().id,
        typ: 'pwd_reset',
      });

      await expect(
        service.resetPassword(forged, 'brand-new-password'),
      ).rejects.toThrow();
    });

    it('refuses a token signed with the access secret', async () => {
      await service.forgotPassword(user.email);
      const accessToken = new JwtService({ secret: ACCESS_SECRET }).sign({
        userId: user.id,
        prcId: newestRow().id,
        typ: 'pwd_reset',
      });

      await expect(
        service.resetPassword(accessToken, 'brand-new-password'),
      ).rejects.toThrow();
    });

    it('refuses a valid reset-secret token that is not a reset token', async () => {
      await service.forgotPassword(user.email);
      await service.verifyResetCode(user.email, sentCode(sent));
      const wrongType = new JwtService({ secret: RESET_SECRET }).sign({
        userId: user.id,
        prcId: newestRow().id,
        typ: 'access',
      });

      await expect(
        service.resetPassword(wrongType, 'brand-new-password'),
      ).rejects.toThrow();
    });
  });
});

function sentCode(sent: { to: string; code: string }[]): string {
  return sent[sent.length - 1].code;
}

/** Moves a row's `createdAt` back so the resend cooldown reads as elapsed. */
function backdate(row: StoredCode, ms: number): void {
  row.createdAt = new Date(row.createdAt.getTime() - ms);
}
