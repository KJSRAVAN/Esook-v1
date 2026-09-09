import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { OtpProvider, OtpSendResult } from './otp.interface';

/**
 * Email OTP provider - fallback when WhatsApp is unavailable.
 *
 * Environment variables required:
 *   SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, EMAIL_FROM
 */
@Injectable()
export class EmailOtpProvider implements OtpProvider {
  readonly channelName = 'email' as const;
  private readonly logger = new Logger(EmailOtpProvider.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    this.initTransporter();
  }

  private initTransporter(): void {
    const host = this.config.get<string>('SMTP_HOST');
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');

    if (!host || !user || !pass) {
      this.logger.warn('Email OTP provider not fully configured -- SMTP env vars missing');
      return;
    }

    this.transporter = nodemailer.createTransport({
      host,
      port: this.config.get<number>('SMTP_PORT', 587),
      secure: this.config.get<boolean>('SMTP_SECURE', false),
      auth: { user, pass },
    });
  }

  async sendOtp(email: string, code: string): Promise<OtpSendResult> {
    if (!this.transporter) {
      return { success: false, channel: 'email', error: 'Email not configured' };
    }

    const from = this.config.get<string>('EMAIL_FROM', 'Esook <noreply@esook.store>');

    try {
      await this.transporter.sendMail({
        from,
        to: email,
        subject: `Your Esook verification code`,
        text: `Your one-time code is: ${code}\n\nThis code expires in 5 minutes. Do not share it with anyone.`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:400px;margin:0 auto">
            <h2 style="color:#1a1a1a">Your verification code</h2>
            <div style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#2563eb;
                        padding:20px;background:#f0f4ff;border-radius:8px;text-align:center">
              ${code}
            </div>
            <p style="color:#666;margin-top:16px">
              This code expires in <strong>5 minutes</strong>.<br>
              Never share this code with anyone.
            </p>
          </div>
        `,
      });

      // Log masked address only
      const masked = email.replace(/(.{2})(.*)(@.*)/, '$1***$3');
      this.logger.log(`Email OTP sent to ${masked}`);
      return { success: true, channel: 'email' };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Email OTP send failed: ${msg}`);
      return { success: false, channel: 'email', error: msg };
    }
  }
}
