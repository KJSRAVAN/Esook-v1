import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';
import { OtpProvider, OtpSendResult } from './otp.interface';

/**
 * Email OTP provider using Resend HTTPS API.
 *
 * Environment variables required:
 *   RESEND_API_KEY
 *   EMAIL_FROM (optional, defaults to 'Esook <noreply@esook.store>')
 */
@Injectable()
export class EmailOtpProvider implements OtpProvider {
  readonly channelName = 'email' as const;
  private readonly logger = new Logger(EmailOtpProvider.name);
  private resend: Resend | null = null;

  constructor(private readonly config: ConfigService) {
    this.initClient();
  }

  private initClient(): void {
    const apiKey = this.config.get<string>('RESEND_API_KEY');
    if (!apiKey) {
      this.logger.warn('Email OTP provider not configured: RESEND_API_KEY is missing');
      return;
    }
    this.resend = new Resend(apiKey);
  }

  async sendOtp(
    email: string,
    code: string,
    purpose: 'verification' | 'password_reset' = 'verification',
  ): Promise<OtpSendResult> {
    if (!this.resend) {
      return { success: false, channel: 'email', error: 'Email not configured' };
    }

    const from = this.config.get<string>('EMAIL_FROM', 'Esook <noreply@esook.store>');
    const isReset = purpose === 'password_reset';
    const subject = isReset
      ? 'Your Esook password reset code'
      : 'Your Esook verification code';
    const title = isReset ? 'Reset Your Password' : 'Your verification code';
    const expiryText = isReset ? '10 minutes' : '5 minutes';
    const instructions = isReset
      ? 'Enter this code to set a new password for your Esook account.'
      : 'Enter this code to verify your Esook customer account.';

    try {
      const { data, error } = await this.resend.emails.send({
        from,
        to: email,
        subject,
        text: `${title}\n\nYour one-time code is: ${code}\n\n${instructions}\nThis code expires in ${expiryText}. Never share it with anyone.`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:400px;margin:0 auto">
            <h2 style="color:#1a1a1a">${title}</h2>
            <div style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#2563eb;
                        padding:20px;background:#f0f4ff;border-radius:8px;text-align:center">
              ${code}
            </div>
            <p style="color:#666;margin-top:16px">
              ${instructions}<br>
              This code expires in <strong>${expiryText}</strong>.<br>
              Never share this code with anyone.
            </p>
          </div>
        `,
      });

      if (error) {
        this.logger.error(`Resend API error: ${error.name} - ${error.message}`);
        return { success: false, channel: 'email', error: error.message };
      }

      // Log masked address only — never log the OTP
      const masked = email.replace(/(.{2})(.*)(@.*)/, '$1***$3');
      this.logger.log(`Email OTP sent to ${masked} for ${purpose} (Resend ID: ${data?.id})`);
      return { success: true, channel: 'email' };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Resend unexpected failure: ${msg}`);
      return { success: false, channel: 'email', error: msg };
    }
  }
}
