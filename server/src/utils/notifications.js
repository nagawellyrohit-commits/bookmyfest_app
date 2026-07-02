import nodemailer from 'nodemailer';
import axios from 'axios';

const cleanEnvVar = (val) => {
  if (typeof val !== 'string') return val;
  return val.replace(/^["']|["']$/g, '').trim();
};

// Configure Nodemailer SMTP Transporter
const createMailTransporter = () => {
  const smtpUser = cleanEnvVar(process.env.SMTP_USER);

  // If credentials are placeholders, return a mock transporter
  if (!smtpUser || smtpUser === 'smtp_user_placeholder') {
    return {
      sendMail: async (mailOptions) => {
        console.log(`[MOCK EMAIL SENT] To: ${mailOptions.to} | Subject: ${mailOptions.subject}\nBody: ${mailOptions.text || mailOptions.html}`);
        return { messageId: 'mock-id-12345' };
      }
    };
  }

  const host = cleanEnvVar(process.env.SMTP_HOST) || 'smtp.mailtrap.io';
  const port = parseInt(cleanEnvVar(process.env.SMTP_PORT) || '2525');
  const pass = cleanEnvVar(process.env.SMTP_PASS);

  return nodemailer.createTransport({
    host: host,
    port: port,
    secure: true,
    auth: {
      user: smtpUser,
      pass: pass,
    },
  });
};

/**
 * Send an email notification via SMTP
 * @param {string} to - Recipient email
 * @param {string} subject - Email subject
 * @param {string} text - Plain text body
 * @param {string} html - HTML body (optional)
 */
export const sendEmailNotification = async (to, subject, text, html = '') => {
  const brevoApiKey = cleanEnvVar(process.env.BREVO_API_KEY);
  const fromEmail = cleanEnvVar(process.env.SMTP_FROM) || 'no-reply@bookmyfest.co';

  if (brevoApiKey) {
    try {
      const response = await axios.post(
        'https://api.brevo.com/v3/smtp/email',
        {
          sender: { name: 'BookMyFest', email: fromEmail },
          to: [{ email: to }],
          subject: subject,
          htmlContent: html || `<p>${text}</p>`,
          textContent: text
        },
        {
          headers: {
            'api-key': brevoApiKey,
            'content-type': 'application/json',
            'accept': 'application/json'
          }
        }
      );
      console.log(`[Brevo Email Sent] Message ID: ${response.data.messageId}`);
      return { success: true, messageId: response.data.messageId };
    } catch (error) {
      const errMsg = error.response?.data?.message || error.response?.data || error.message;
      console.error('[Brevo Email Failed]', errMsg);
      return { success: false, error: errMsg };
    }
  }

  try {
    const transporter = createMailTransporter();
    const info = await transporter.sendMail({
      from: fromEmail,
      to,
      subject,
      text,
      html,
    });
    console.log(`[Email Sent] Message ID: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[Email Failed]', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Send a WhatsApp message notification
 * @param {string} toPhone - Recipient phone number with country code (e.g., "+919876543210")
 * @param {string} message - Message text body
 */
export const sendWhatsAppNotification = async (toPhone, message) => {
  // If API credentials are placeholders, fallback to console logging
  if (process.env.WHATSAPP_AUTH_TOKEN === 'auth_token_placeholder') {
    console.log(`[MOCK WHATSAPP SENT] To: ${toPhone} | Message: ${message}`);
    return { success: true, messageId: 'mock-whatsapp-id' };
  }

  try {
    // Standard Twilio WhatsApp send endpoint setup (adaptable for Meta Cloud API or local BSPs)
    const url = process.env.WHATSAPP_API_URL;
    const token = process.env.WHATSAPP_AUTH_TOKEN;
    const from = process.env.WHATSAPP_FROM_NUMBER || 'whatsapp:+14155238886';

    const authHeader = Buffer.from(`AC_placeholder:${token}`).toString('base64'); // Twilio uses Basic Auth username:password

    const data = new URLSearchParams();
    data.append('To', `whatsapp:${toPhone}`);
    data.append('From', from);
    data.append('Body', message);

    const response = await axios.post(url, data, {
      headers: {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    console.log(`[WhatsApp Sent] ID: ${response.data.sid || 'sent'}`);
    return { success: true, messageId: response.data.sid };
  } catch (error) {
    console.error('[WhatsApp Failed]', error.response?.data || error.message);
    return { success: false, error: error.message };
  }
};
