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

  const host = cleanEnvVar(process.env.SMTP_HOST);
  const port = parseInt(cleanEnvVar(process.env.SMTP_PORT));
  const pass = cleanEnvVar(process.env.SMTP_PASS);

  return nodemailer.createTransport({
    host: host,
    port: port,
    secure: false,
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
 * @param {string|null} templateName - Optional email template name
 */
export const sendEmailNotification = async (to, subject, text, html = '', templateName = null) => {
  const brevoApiKey = cleanEnvVar(process.env.BREVO_API_KEY);
  const fromEmail = cleanEnvVar(process.env.SMTP_FROM);

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

export const WhatsAppTemplates = {
  ACCOUNT_CREATED: "account_created",
  REGISTRATION_RECEIVED: "registration_received",
  REGISTRATION_CONFIRMED: "registration_confirmed",
  PAYMENT_CONFIRMED: "payment_confirmed",
  PAYMENT_FAILED: "payment_failed",
  EVENT_REMINDER: "event_reminder",
  CERTIFICATE_READY: "certificate_ready",
  OTP_VERIFICATION: "otp_verification",
  EVENT_PENDING_APPROVAL: "event_pending_approval",
  EVENT_APPROVED: "event_approved",
  EVENT_CREATION_REJECTED: "event_creation_rejected",
  EVENT_UPDATE_REJECTED: "event_update_rejected",
  COORDINATOR_APPROVED: "coordinator_approved",
};

/**
 * Send a WhatsApp message notification using plain text or Meta Template
 * @param {string} toPhone - Recipient phone number with country code (e.g., "+919876543210")
 * @param {string} message - Message text body
 * @param {string|null} templateName - Optional Meta template name
 * @param {Array<string|number>} templateParams - Array of body parameter values
 */
export const sendWhatsAppNotification = async (toPhone, message, templateName = null, templateParams = []) => {
  let phone = "";
  try {
    if (!toPhone) {
      throw new Error("Recipient phone number is missing.");
    }
    // Remove all non-digits
    phone = toPhone.toString().replace(/\D/g, "");
    if (!phone) {
      throw new Error("Recipient phone number is invalid.");
    }
    // Auto-prepend Indian country code '91' if 10-digit mobile number is entered
    if (phone.length === 10) {
      phone = `91${phone}`;
    }

    const payload = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
    };

    if (templateName) {
      payload.type = "template";
      payload.template = {
        name: templateName,
        language: {
          code: "en"
        }
      };

      if (templateParams && templateParams.length > 0) {
        payload.template.components = [
          {
            type: "body",
            parameters: templateParams.map(param => ({
              type: "text",
              text: String(param)
            }))
          }
        ];
      }
    } else {
      payload.type = "text";
      payload.text = {
        body: message,
      };
    }

    console.log(`\n--- [WhatsApp Outbound Notification] ---`);
    console.log(`Recipient: +${phone}`);
    console.log(`Type: ${templateName ? "Template" : "Text"}`);
    if (templateName) {
      console.log(`Template Name: ${templateName}`);
      console.log(`Parameters:`, templateParams);
    } else {
      console.log(`Body:\n${message}`);
    }

    const response = await axios.post(
      `${process.env.WHATSAPP_API_URL}/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,
      payload,
      {
        headers: {
          Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
          "Content-Type": "application/json",
        },
      }
    );

    const messageId = response.data.messages?.[0]?.id || "N/A";
    console.log(`Status: Success`);
    console.log(`HTTP Status: ${response.status}`);
    console.log(`Meta Message ID: ${messageId}`);
    console.log(`----------------------------------------\n`);

    return {
      success: true,
      data: response.data,
    };
  } catch (error) {
    const errorData = error.response?.data || error.message;
    console.error(`\n--- [WhatsApp Outbound Notification FAILED] ---`);
    console.error(`Recipient: +${phone || toPhone}`);
    console.error(`Type: ${templateName ? `Template (${templateName})` : "Text"}`);
    console.error(`Status: Failed`);
    console.error(`HTTP Status: ${error.response?.status || "N/A"}`);
    console.error(`Error details:`, JSON.stringify(errorData));
    console.error(`-----------------------------------------------\n`);

    return {
      success: false,
      error: errorData,
    };
  }
};

/**
 * Send notification to both Email and WhatsApp (if phone is provided)
 * @param {Object} options
 * @param {string} [options.email] - Recipient email address
 * @param {string} [options.phone] - Recipient phone number
 * @param {string} options.subject - Email subject / WhatsApp title header
 * @param {string} options.text - Plain text message
 * @param {string} [options.html] - HTML body for email
 */
export const sendDualNotification = async ({ email, phone, subject, text, html = '' }) => {
  const promises = [];

  if (email) {
    promises.push(sendEmailNotification(email, subject, text, html));
  }

  if (phone) {
    const whatsappMsg = subject ? `📌 *${subject}*\n\n${text}` : text;
    promises.push(sendWhatsAppNotification(phone, whatsappMsg));
  }

  return Promise.allSettled(promises);
};