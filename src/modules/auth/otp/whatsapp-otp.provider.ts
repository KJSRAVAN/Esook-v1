import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import { OtpProvider, OtpSendResult } from './otp.interface';

/**
 * WhatsApp OTP provider via Meta Cloud API.
 *
 * Uses a pre-approved WhatsApp message template that contains one variable
 * (the OTP code). Template must be created and approved in Meta Business Suite.
 *
 * Environment variables required:
 *   WHATSAPP_API_URL
 *   WHATSAPP_PHONE_NUMBER_ID
 *   WHATSAPP_ACCESS_TOKEN
 *   WHATSAPP_OTP_TEMPLATE_NAME
 *   WHATSAPP_OTP_TEMPLATE_LANG
 */
@Injectable()
export class WhatsAppOtpProvider implements OtpProvider {
  readonly channelName = 'whatsapp' as const;
  private readonly logger = new Logger(WhatsAppOtpProvider.name);

  constructor(private readonly config: ConfigService) {}

  async sendOtp(phone: string, code: string): Promise<OtpSendResult> {
    const apiUrl = this.config.get<string>('WHATSAPP_API_URL');
    const phoneNumberId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');
    const accessToken = this.config.get<string>('WHATSAPP_ACCESS_TOKEN');
    const templateName = this.config.get<string>('WHATSAPP_OTP_TEMPLATE_NAME', 'otp_verification');
    const templateLang = this.config.get<string>('WHATSAPP_OTP_TEMPLATE_LANG', 'en');

    if (!phoneNumberId || !accessToken) {
      this.logger.warn('WhatsApp provider not configured -- missing env vars');
      return { success: false, channel: 'whatsapp', error: 'WhatsApp not configured' };
    }

    const url = `${apiUrl}/${phoneNumberId}/messages`;
    const payload = {
      messaging_product: 'whatsapp',
      to: phone,
      type: 'template',
      template: {
        name: templateName,
        language: { code: templateLang },
        components: [
          {
            type: 'body',
            parameters: [{ type: 'text', text: code }],
          },
          {
            type: 'button',
            sub_type: 'url',
            index: '0',
            parameters: [{ type: 'text', text: code }],
          },
        ],
      },
    };

    try {
      await axios.post(url, payload, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        timeout: 10_000,
      });

      // Do NOT log the code itself
      this.logger.log(`WhatsApp OTP sent to +${phone.slice(0, 4)}****`);
      return { success: true, channel: 'whatsapp' };
    } catch (err) {
      const axiosErr = err as AxiosError;
      const errMsg = axiosErr.response?.data
        ? JSON.stringify(axiosErr.response.data)
        : axiosErr.message;
      this.logger.error(`WhatsApp OTP send failed: ${errMsg}`);
      return { success: false, channel: 'whatsapp', error: errMsg };
    }
  }
}
