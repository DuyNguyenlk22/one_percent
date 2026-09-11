import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { EmailService } from './email.service';

const CONFIG: Record<string, string> = {
  SMTP_HOST: 'smtp.example.test',
  SMTP_PORT: '2525',
  SMTP_SECURE: 'false',
  SMTP_USER: 'smtp-user',
  SMTP_PASS: 'smtp-pass',
  MAIL_FROM: 'Bloom <no-reply@bloom.app>',
};

/**
 * A real nodemailer transport in `jsonTransport` mode: nodemailer composes the
 * message for real — addresses, headers, both bodies — but hands it back as
 * JSON instead of opening a socket. `sent` therefore holds what nodemailer
 * actually produced, so the assertions below are on real behaviour rather than
 * on a stubbed sendMail.
 */
function recordingTransport(): {
  transport: nodemailer.Transporter;
  sent: Record<string, any>[];
} {
  const json = nodemailer.createTransport({ jsonTransport: true });
  const sent: Record<string, any>[] = [];

  const transport = {
    sendMail: async (options: nodemailer.SendMailOptions) => {
      const info = (await json.sendMail(options)) as { message: string };
      sent.push(JSON.parse(info.message) as Record<string, any>);
      return info;
    },
  } as unknown as nodemailer.Transporter;

  return { transport, sent };
}

async function buildService(
  transport: nodemailer.Transporter,
): Promise<EmailService> {
  jest.spyOn(nodemailer, 'createTransport').mockReturnValue(transport);

  const moduleRef = await Test.createTestingModule({
    providers: [
      EmailService,
      {
        provide: ConfigService,
        useValue: { get: (key: string) => CONFIG[key] },
      },
    ],
  }).compile();

  return moduleRef.get(EmailService);
}

describe('EmailService', () => {
  afterEach(() => jest.restoreAllMocks());

  it('builds the transport from the SMTP_* config values', async () => {
    const createTransport = jest.spyOn(nodemailer, 'createTransport');

    await buildService(recordingTransport().transport);

    expect(createTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        host: 'smtp.example.test',
        port: 2525,
        secure: false,
        auth: { user: 'smtp-user', pass: 'smtp-pass' },
      }),
    );
  });

  it('sends the code to the requested address from MAIL_FROM', async () => {
    const { transport, sent } = recordingTransport();
    const service = await buildService(transport);

    await service.sendPasswordResetCode('alex@example.com', '481920');

    expect(sent[0].to).toEqual([
      expect.objectContaining({ address: 'alex@example.com' }),
    ]);
    expect(sent[0].from).toEqual(
      expect.objectContaining({ address: 'no-reply@bloom.app' }),
    );
  });

  it('carries the code and its expiry window in both bodies', async () => {
    const { transport, sent } = recordingTransport();
    const service = await buildService(transport);

    await service.sendPasswordResetCode('alex@example.com', '481920');

    expect(sent[0].text).toContain('481920');
    expect(sent[0].text).toContain('15 minutes');
    expect(sent[0].html).toContain('481920');
  });

  it('logs and swallows an unreachable SMTP host instead of throwing', async () => {
    const transport = {
      sendMail: jest.fn().mockRejectedValue(new Error('ECONNREFUSED')),
    } as unknown as nodemailer.Transporter;
    const service = await buildService(transport);
    const logged = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);

    await expect(
      service.sendPasswordResetCode('alex@example.com', '481920'),
    ).resolves.toBeUndefined();

    expect(logged).toHaveBeenCalledWith(
      expect.stringContaining('alex@example.com'),
      expect.any(String),
    );
  });
});
