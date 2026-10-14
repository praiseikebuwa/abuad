import nodemailer, { Transporter } from 'nodemailer';

/**
 * Brevo (Sendinblue) email service.
 * Supports both:
 * 1. Brevo v3 HTTPS REST API (via BREVO_API_KEY) - port 443, immune to firewall/SMTP blocks
 * 2. Brevo SMTP (via SMTP_USER, SMTP_PASS, SMTP_HOST, SMTP_PORT)
 */
let transporter: Transporter | null = null;

function getTransporter(): Transporter {
  if (transporter) return transporter;

  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass) {
    throw new Error('SMTP_USER / SMTP_PASS are not configured');
  }

  const port = Number(process.env.SMTP_PORT || 465);
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp-relay.brevo.com',
    port,
    secure: port === 465, // Direct SSL/TLS on port 465 is faster & more reliable than 587
    auth: { user, pass },
    connectionTimeout: 8000, // 8s connection timeout to prevent 60s Nginx 504 timeouts
    greetingTimeout: 5000,
    socketTimeout: 10000,
  });
  return transporter;
}

const FROM = () => process.env.MAIL_FROM || 'ABUAD App <no-reply@abuadapp.com.ng>';

export async function sendMail(to: string, subject: string, html: string, text?: string) {
  // Option 1: Brevo v3 HTTP API (if BREVO_API_KEY is provided)
  const brevoApiKey = process.env.BREVO_API_KEY;
  if (brevoApiKey) {
    const fromStr = FROM();
    const match = fromStr.match(/^(.*)<(.*)>$/);
    const senderName = match ? match[1].trim() : 'ABUAD App';
    const senderEmail = match ? match[2].trim() : fromStr.trim();

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': brevoApiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        sender: { name: senderName, email: senderEmail },
        to: [{ email: to }],
        subject,
        htmlContent: html,
        textContent: text || '',
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Brevo API Error (${response.status}): ${errBody}`);
    }
    return response.json();
  }

  // Option 2: SMTP via Nodemailer
  return getTransporter().sendMail({ from: FROM(), to, subject, html, text });
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
}

export async function sendPasswordResetEmail(to: string, name: string, resetUrl: string) {
  const safeName = escapeHtml(name || 'there');
  const html = `<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#0b1020;font-family:Segoe UI,Roboto,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:32px 12px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#141a33;border-radius:20px;padding:36px;color:#e8ebf7;">
        <tr><td style="font-size:26px;font-weight:800;letter-spacing:2px;color:#ffffff;">ABUAD</td></tr>
        <tr><td style="padding-top:20px;font-size:18px;font-weight:700;">Reset your password</td></tr>
        <tr><td style="padding-top:12px;font-size:15px;line-height:1.6;color:#b9c0dc;">
          Hi ${safeName},<br/>We received a request to reset the password for your ABUAD account.
          Click the button below to choose a new one. This link expires in <b>1 hour</b>.
        </td></tr>
        <tr><td align="center" style="padding:28px 0;">
          <a href="${resetUrl}" style="background:#f5b63c;color:#141a33;text-decoration:none;font-weight:800;padding:14px 32px;border-radius:12px;display:inline-block;">Reset Password</a>
        </td></tr>
        <tr><td style="font-size:13px;line-height:1.6;color:#8a91b0;">
          If the button doesn't work, copy this link into your browser:<br/>
          <a href="${resetUrl}" style="color:#7fb3ff;word-break:break-all;">${resetUrl}</a>
        </td></tr>
        <tr><td style="padding-top:24px;font-size:12px;color:#6b7290;">
          If you didn't request this, you can safely ignore this email — your password won't change.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;

  const text = `Hi ${name || 'there'},\n\nReset your ABUAD password using this link (expires in 1 hour):\n${resetUrl}\n\nIf you didn't request this, ignore this email.`;

  return sendMail(to, 'Reset your ABUAD password', html, text);
}
