// ---------------------------------------------------------------------------
// OTP Provider Interface
// Business logic NEVER imports a concrete provider -- only this interface.
// ---------------------------------------------------------------------------

export interface OtpSendResult {
  /** true = message dispatched to channel (no guarantee of delivery) */
  success: boolean;
  channel: 'whatsapp' | 'email';
  error?: string;
}

export interface OtpProvider {
  /** Send a 6-digit OTP to the given destination (phone or email) */
  sendOtp(destination: string, code: string): Promise<OtpSendResult>;
  /** Human-readable channel name for logging */
  readonly channelName: 'whatsapp' | 'email';
}
