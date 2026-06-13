import prisma from '../config/db.js';
import { logAudit } from '../utils/dbHelper.js';
import { getAiCertificateSuggestions } from '../utils/aiService.js';

// Get AI suggested certificate templates
export const getCertificateSuggestions = async (req, res, next) => {
  const { id: eventId } = req.params;
  const actor = req.user;

  try {
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: { college: true }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Restriction check
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot access certificates for another college'
      });
    }

    const suggestions = await getAiCertificateSuggestions(
      event.title,
      event.description,
      event.college.name
    );

    res.status(200).json({
      success: true,
      data: suggestions
    });

  } catch (error) {
    next(error);
  }
};

// Approve a certificate template
export const approveCertificateTemplate = async (req, res, next) => {
  const { id: eventId } = req.params;
  const {
    templateName,
    primaryColor,
    secondaryColor,
    fontFamily,
    backgroundStyle,
    layoutDescription
  } = req.body;

  const actor = req.user;

  try {
    // 1. Verify inputs
    if (!templateName || !primaryColor || !secondaryColor || !fontFamily || !backgroundStyle) {
      return res.status(400).json({
        success: false,
        message: 'Missing layout details: templateName, primaryColor, secondaryColor, fontFamily, and backgroundStyle are required.'
      });
    }

    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // 2. Auth restriction check
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot approve templates for another college'
      });
    }

    if (!actor.isVerified && actor.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Account is pending verification. Approval actions are locked.'
      });
    }

    const templatePayload = {
      templateName,
      primaryColor,
      secondaryColor,
      fontFamily,
      backgroundStyle,
      layoutDescription: layoutDescription || ''
    };

    // 3. Save to event
    const updatedEvent = await prisma.event.update({
      where: { id: eventId },
      data: {
        certificateTemplate: templatePayload
      }
    });

    // 4. Log to Audit
    await logAudit(
      actor.id,
      'APPROVE_CERTIFICATE_TEMPLATE',
      'events',
      eventId,
      event.certificateTemplate,
      templatePayload
    );

    res.status(200).json({
      success: true,
      message: 'Certificate template approved successfully',
      data: updatedEvent.certificateTemplate
    });

  } catch (error) {
    next(error);
  }
};

// Download / Get Student certificate
export const downloadCertificate = async (req, res, next) => {
  const { id: eventId } = req.params;
  const userId = req.user.id;
  const format = req.query.format; // e.g. "html"

  try {
    // 1. Fetch Event with details
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: {
        college: true
      }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // 2. Fetch User
    const student = await prisma.user.findUnique({
      where: { id: userId }
    });

    // 3. Verify event has approved template
    if (!event.certificateTemplate) {
      return res.status(400).json({
        success: false,
        message: 'The event coordinators have not approved the certificate templates for this event yet.'
      });
    }

    // 4. Verify user attended and scan is verified
    const attendance = await prisma.attendance.findUnique({
      where: {
        eventId_userId: { eventId, userId }
      },
      include: {
        verifier: {
          select: { fullName: true }
        }
      }
    });

    if (!attendance) {
      return res.status(403).json({
        success: false,
        message: 'Access Denied: Certificates are only available to verified attendees. No attendance record found.'
      });
    }

    const template = event.certificateTemplate;
    const issueDate = new Date(attendance.markedAt).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    const certificatePayload = {
      studentName: student.fullName,
      eventTitle: event.title,
      collegeName: event.college.name,
      issueDate,
      verifierName: attendance.verifier?.fullName || 'College Board Coordinator',
      design: template
    };

    // Return HTML formatting if requested
    if (format === 'html') {
      const htmlOutput = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Certificate of Participation</title>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&family=Playfair+Display:ital,wght@0,700;1,400&family=Outfit:wght@400;700&family=Fira+Code:wght@400;700&family=Montserrat:wght@400;700&display=swap" rel="stylesheet">
        <style>
          body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-color: #e2e8f0;
            font-family: '${template.fontFamily}', sans-serif;
          }
          .certificate-container {
            width: 800px;
            height: 550px;
            padding: 40px;
            box-sizing: border-box;
            background: ${template.backgroundStyle};
            color: ${template.backgroundStyle.includes('#fafaf9') || template.backgroundStyle.includes('#f5f5f4') ? '#0f172a' : '#ffffff'};
            border: 10px solid ${template.primaryColor};
            border-radius: 12px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.15);
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            align-items: center;
            text-align: center;
            position: relative;
          }
          .inner-border {
            position: absolute;
            top: 15px;
            left: 15px;
            right: 15px;
            bottom: 15px;
            border: 2px solid ${template.secondaryColor};
            border-radius: 6px;
            pointer-events: none;
          }
          .header {
            margin-top: 20px;
          }
          .college-name {
            font-size: 1.1rem;
            text-transform: uppercase;
            letter-spacing: 2px;
            font-weight: 700;
            color: ${template.primaryColor};
          }
          .cert-title {
            font-size: 2.5rem;
            margin: 15px 0 5px 0;
            font-weight: 700;
          }
          .subtitle {
            font-size: 1rem;
            opacity: 0.8;
            font-style: italic;
          }
          .recipient-section {
            margin: 30px 0;
          }
          .presented-to {
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1.5px;
            opacity: 0.7;
          }
          .student-name {
            font-size: 2.2rem;
            font-weight: 700;
            margin: 10px 0;
            border-bottom: 2px solid ${template.primaryColor};
            padding-bottom: 5px;
            display: inline-block;
          }
          .description {
            font-size: 1rem;
            max-width: 600px;
            margin: 0 auto;
            line-height: 1.5;
            opacity: 0.9;
          }
          .footer {
            width: 100%;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            margin-bottom: 20px;
            padding: 0 40px;
            box-sizing: border-box;
          }
          .signature-block {
            display: flex;
            flex-direction: column;
            align-items: center;
          }
          .signature-line {
            width: 150px;
            border-top: 1px solid ${template.backgroundStyle.includes('#fafaf9') ? '#475569' : '#94a3b8'};
            margin-bottom: 5px;
          }
          .sig-title {
            font-size: 0.75rem;
            opacity: 0.8;
          }
          .badge {
            width: 70px;
            height: 70px;
            border-radius: 50%;
            background-color: ${template.primaryColor};
            display: flex;
            justify-content: center;
            align-items: center;
            border: 3px double ${template.secondaryColor};
            font-size: 0.6rem;
            font-weight: 700;
            color: #ffffff;
            transform: rotate(-10deg);
          }
        </style>
      </head>
      <body>
        <div class="certificate-container">
          <div class="inner-border"></div>
          
          <div class="header">
            <div class="college-name">${event.college.name}</div>
            <div class="cert-title">Certificate of Participation</div>
            <div class="subtitle">This is proudly presented to</div>
          </div>

          <div class="recipient-section">
            <div class="student-name">${student.fullName}</div>
            <div class="description">
              For actively participating and successfully completing the multi-college event <strong>"${event.title}"</strong> conducted on <strong>${issueDate}</strong>.
            </div>
          </div>

          <div class="footer">
            <div class="signature-block">
              <div class="signature-line"></div>
              <div class="sig-title">Date: ${issueDate}</div>
            </div>
            
            <div class="badge">
              OFFICIAL<br>VERIFIED
            </div>

            <div class="signature-block">
              <div class="signature-line"></div>
              <div class="sig-title">${attendance.verifier?.fullName || 'Event Organizer'}<br>Coordinator</div>
            </div>
          </div>
        </div>
      </body>
      </html>
      `;
      res.setHeader('Content-Type', 'text/html');
      return res.status(200).send(htmlOutput);
    }

    // Default JSON payload response
    res.status(200).json({
      success: true,
      data: certificatePayload
    });

  } catch (error) {
    next(error);
  }
};
