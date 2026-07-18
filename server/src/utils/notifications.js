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
 * Get the standardized BookMyFest brand HTML email template
 * @param {string} subject - Email subject
 * @param {string} contentHtml - Core HTML content
 */
export const getEmailTemplate = (subject, contentHtml) => {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${subject}</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #f8fafc;
      font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
      -webkit-font-smoothing: antialiased;
    }
    a {
      color: #9708AA;
      text-decoration: none;
    }
  </style>
</head>
<body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f8fafc; padding: 40px 0;">
    <tr>
      <td align="center">
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #f1f5f9; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);">
          <!-- Header Banner -->
          <tr>
            <td align="center" style="background: linear-gradient(135deg, #9708AA 0%, #70067E 100%); padding: 35px 20px;">
              <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px; text-shadow: 0 2px 4px rgba(0,0,0,0.1);">BookMyFest</h1>
              <p style="color: #f3e8ff; margin: 6px 0 0 0; font-size: 13px;">Your Ultimate Event Companion</p>
            </td>
          </tr>
          
          <!-- Content Area -->
          <tr>
            <td style="padding: 40px 35px; color: #334155; line-height: 1.7; font-size: 15px;">
              ${contentHtml}
            </td>
          </tr>
          
          <!-- Footer Area -->
          <tr>
            <td align="center" style="background-color: #f8fafc; padding: 30px; font-size: 12px; color: #64748b; border-top: 1px solid #f1f5f9; border-bottom-left-radius: 16px; border-bottom-right-radius: 16px;">
              <p style="margin: 0 0 8px 0; font-weight: 600; color: #475569;">This is an automated system email. Please do not reply directly to this email.</p>
              <p style="margin: 0 0 16px 0;">For any support, please email us at <a href="mailto:support@bookmyfest.co" style="color: #9708AA; text-decoration: none; font-weight: bold;">support@bookmyfest.co</a></p>
              <hr style="border: 0; border-top: 1px dashed #e2e8f0; margin: 15px 0;" />
              <p style="margin: 0; color: #94a3b8;">&copy; ${new Date().getFullYear()} BookMyFest. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
};

/**
 * Clean up legacy HTML templates and wrap them in the brand template
 * @param {string} subject - Email subject
 * @param {string} html - HTML content
 * @param {string} text - Plain text content
 */
const processEmailBody = (subject, html, text) => {
  let contentHtml = '';
  
  if (html) {
    let cleaned = html;
    
    // Clean old container div
    cleaned = cleaned.replace(/<div style="font-family:\s*[^>]*max-width:\s*600px;[^>]*">/, '');
    
    // Clean old welcome header
    cleaned = cleaned.replace(/<div style="text-align:\s*center;\s*border-bottom:\s*2px[^>]*">[\s\S]*?<\/div>/, '');
    
    // Clean old reset header
    cleaned = cleaned.replace(/<h2 style="color:\s*#4f46e5;\s*text-align:\s*center;">Reset Your Password<\/h2>/, '');
    
    // Clean old footer div
    cleaned = cleaned.replace(/<div style="text-align:\s*center;\s*margin-top:\s*30px;[\s\S]*?<\/div>\s*<\/div>\s*$/, '');
    cleaned = cleaned.replace(/<hr style="border:\s*0;\s*border-top:\s*1px\s*solid\s*#e2e8f0;\s*margin:\s*20px\s*0;"\s*\/>\s*<p style="font-size:\s*12px;\s*color:\s*#64748b;\s*text-align:\s*center;">&copy;\s*BookmyFest\.\s*All\s*rights\s*reserved\.<\/p>\s*<\/div>\s*$/, '');

    // Clean outer trailing div if it remains
    cleaned = cleaned.trim();
    if (cleaned.endsWith('</div>')) {
      cleaned = cleaned.substring(0, cleaned.length - 6).trim();
    }
    
    // Replace old indigo colors with BookMyFest brand magenta
    cleaned = cleaned.replace(/#4f46e5/g, '#9708AA');
    cleaned = cleaned.replace(/#6366f1/g, '#9708AA');
    
    contentHtml = cleaned;
  } else if (text) {
    contentHtml = text
      .split('\n\n')
      .map(p => `<p style="margin: 0 0 15px 0;">${p.replace(/\n/g, '<br>')}</p>`)
      .join('');
  } else {
    contentHtml = '<p>No content provided.</p>';
  }
  
  return getEmailTemplate(subject, contentHtml);
};

/**
 * Send an email notification via SMTP or Brevo
 * @param {string} to - Recipient email
 * @param {string} subject - Email subject
 * @param {string} text - Plain text body
 * @param {string} html - HTML body (optional)
 */
export const sendEmailNotification = async (to, subject, text, html = '') => {
  const brevoApiKey = cleanEnvVar(process.env.BREVO_API_KEY);
  const fromEmail = cleanEnvVar(process.env.SMTP_FROM) || 'no-reply@bookmyfest.co';
  
  const formattedHtml = processEmailBody(subject, html, text);

  if (brevoApiKey) {
    try {
      const response = await axios.post(
        'https://api.brevo.com/v3/smtp/email',
        {
          sender: { name: 'BookMyFest', email: fromEmail },
          to: [{ email: to }],
          subject: subject,
          htmlContent: formattedHtml,
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
      html: formattedHtml,
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
