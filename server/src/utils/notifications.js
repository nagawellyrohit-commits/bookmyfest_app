import nodemailer from 'nodemailer';
import axios from 'axios';

// Configure Nodemailer SMTP Transporter
const createMailTransporter = () => {
  // If credentials are placeholders, return a mock transporter
  if (process.env.SMTP_USER === 'smtp_user_placeholder') {
    return {
      sendMail: async (mailOptions) => {
        console.log(`[MOCK EMAIL SENT] To: ${mailOptions.to} | Subject: ${mailOptions.subject}\nBody: ${mailOptions.text || mailOptions.html}`);
        return { messageId: 'mock-id-12345' };
      }
    };
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.mailtrap.io',
    port: parseInt(process.env.SMTP_PORT || '2525'),
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
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
  try {
    const transporter = createMailTransporter();
    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || 'no-reply@collegeconnect.com',
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
