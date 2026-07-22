import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import nodemailer from 'nodemailer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../.env') });

const cleanEnvVar = (val) => {
  if (typeof val !== 'string') return val;
  return val.replace(/^["']|["']$/g, '').trim();
};

async function sendNotification() {
  const status = process.argv[2]; // 'SUCCESS' or 'FAILED'
  const details = process.argv[3] || 'No extra details provided.';
  const email = cleanEnvVar(process.env.BACKUP_ADMIN_EMAIL) || 'support@bookmyfest.co';

  console.log(`[Backup Notify] Status: ${status} | Target: ${email}`);

  const smtpUser = cleanEnvVar(process.env.SMTP_USER);
  const smtpPass = cleanEnvVar(process.env.SMTP_PASS);
  const smtpHost = cleanEnvVar(process.env.SMTP_HOST);
  const smtpPort = parseInt(cleanEnvVar(process.env.SMTP_PORT) || '587');
  const smtpFrom = cleanEnvVar(process.env.SMTP_FROM) || 'BookMyFest Backup <support@bookmyfest.co>';

  if (!smtpUser || !smtpPass || !smtpHost) {
    console.error('❌ SMTP configuration missing in .env. Skipping email notification.');
    process.exit(0);
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: false,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const subject = `[Backup ${status}] BookMyFest System Backup`;
  const timestamp = new Date().toISOString();
  
  const text = `
Status: ${status}
Timestamp: ${timestamp}

Details:
${details}

Best,
BookMyFest System Agent
  `;

  const html = `
    <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
      <h2 style="color: ${status === 'SUCCESS' ? '#10b981' : '#ef4444'}; margin-top: 0;">Backup Notification: ${status}</h2>
      <p>A scheduled backup run completed with status <strong>${status}</strong>.</p>
      <hr style="border: 0; border-top: 1px solid #f1f5f9; margin: 15px 0;" />
      <p><strong>Timestamp:</strong> ${timestamp}</p>
      <p><strong>Log Details:</strong></p>
      <pre style="background: #f8fafc; padding: 12px; border-radius: 6px; font-size: 13px; overflow-x: auto; max-height: 300px;">${details}</pre>
      <hr style="border: 0; border-top: 1px solid #f1f5f9; margin: 15px 0;" />
      <p style="font-size: 11px; color: #64748b;">This is an automated system email from BookMyFest.</p>
    </div>
  `;

  try {
    await transporter.sendMail({
      from: smtpFrom,
      to: email,
      subject: subject,
      text: text,
      html: html,
    });
    console.log('✅ Backup status email sent successfully.');
  } catch (error) {
    console.error('❌ Failed to send backup status email:', error.message);
  }
}

sendNotification();
