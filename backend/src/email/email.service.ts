import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/** Matches the `expiresAt` window `AuthService.forgotPassword` stamps on the row. */
const CODE_TTL_LABEL = '5 minutes';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly transporter: nodemailer.Transporter;
  private readonly from: string;

  constructor(private readonly config: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.config.get<string>('SMTP_HOST'),
      port: Number(this.config.get<string>('SMTP_PORT') ?? 587),
      secure: this.config.get<string>('SMTP_SECURE') === 'true',
      auth: {
        user: this.config.get<string>('SMTP_USER'),
        pass: this.config.get<string>('SMTP_PASS'),
      },
    });

    this.from =
      this.config.get<string>('MAIL_FROM') ?? 'Bloom <no-reply@bloom.app>';
  }

  /**
   * Failures are logged and swallowed on purpose: `POST /auth/forgot-password`
   * must answer identically for a registered and an unregistered address, and a
   * 500 from a dead SMTP host would tell an attacker the address exists.
   */
  async sendPasswordResetCode(to: string, code: string): Promise<void> {
    try {
      await this.transporter.sendMail({
        from: this.from,
        to,
        subject: 'Your Bloom password reset code',
        text: this.plainTextBody(code),
        html: this.htmlBody(code),
      });
    } catch (error) {
      this.logger.error(
        `Failed to send password reset code to ${to}`,
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  private plainTextBody(code: string): string {
    return [
      'Reset your Bloom password',
      '',
      `Your password reset code is ${code}.`,
      `It expires in ${CODE_TTL_LABEL}.`,
      '',
      'If you did not ask to reset your password, ignore this email — your',
      'password will not change.',
    ].join('\n');
  }

  private htmlBody(code: string): string {
    return [
      '<h2>Reset your Bloom password</h2>',
      '<p>Your password reset code is:</p>',
      `<p style="font-size:28px;font-weight:700;letter-spacing:6px;margin:16px 0">${code}</p>`,
      `<p>It expires in ${CODE_TTL_LABEL}.</p>`,
      '<p>If you did not ask to reset your password, ignore this email — your password will not change.</p>',
    ].join('');
  }
}
