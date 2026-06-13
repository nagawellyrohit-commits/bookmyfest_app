import prisma from '../config/db.js';
import { logAudit } from '../utils/dbHelper.js';

// Scan QR code to mark attendance
export const scanEventQr = async (req, res, next) => {
  const { id: eventId } = req.params;
  const { qrCode } = req.body;
  const userId = req.user.id;

  try {
    // 1. Fetch Event
    const event = await prisma.event.findUnique({
      where: { id: eventId }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // 2. Validate QR Code matches
    if (qrCode !== event.qrAttendanceCode) {
      return res.status(400).json({ success: false, message: 'Invalid QR code. Please verify you scanned the correct event code.' });
    }

    // 3. Verify user is registered (must be free or completed paid registration)
    const registration = await prisma.registration.findFirst({
      where: {
        eventId,
        userId,
        paymentStatus: { in: ['completed', 'free_event'] }
      }
    });

    if (!registration) {
      return res.status(400).json({
        success: false,
        message: 'You must be registered (and payment confirmed if paid) to mark attendance for this event.'
      });
    }

    // 4. Check if attendance already marked
    const existingAttendance = await prisma.attendance.findUnique({
      where: {
        eventId_userId: { eventId, userId }
      }
    });

    if (existingAttendance) {
      return res.status(400).json({
        success: false,
        message: 'Attendance already recorded for this event.',
        data: existingAttendance
      });
    }

    // 5. Create Attendance record (marked automatically, verifiedBy set to creator by default for auto-verification)
    const attendance = await prisma.attendance.create({
      data: {
        eventId,
        userId,
        verifiedBy: event.createdBy // Auto-verified by the event organizer/creator
      }
    });

    res.status(201).json({
      success: true,
      message: 'Attendance marked and verified successfully!',
      data: attendance
    });

  } catch (error) {
    next(error);
  }
};

// Fetch event attendance list (Coordinators / Admins of the college)
export const getEventAttendance = async (req, res, next) => {
  const { id: eventId } = req.params;
  const actor = req.user;

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // College checks
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view attendance for other colleges'
      });
    }

    const attendanceList = await prisma.attendance.findMany({
      where: { eventId },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            department: true
          }
        },
        verifier: {
          select: {
            fullName: true
          }
        }
      },
      orderBy: {
        markedAt: 'desc'
      }
    });

    res.status(200).json({
      success: true,
      data: attendanceList
    });

  } catch (error) {
    next(error);
  }
};

// Verify/audit attendance manual override (Coordinators / Admins)
export const verifyAttendanceRecord = async (req, res, next) => {
  const { id: eventId, attendanceId } = req.params;
  const actor = req.user;

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // College checks
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot edit attendance for other colleges'
      });
    }

    if (!actor.isVerified && actor.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Coordinator account must be verified to perform manual audit updates.'
      });
    }

    const attendance = await prisma.attendance.findUnique({ where: { id: attendanceId } });
    if (!attendance || attendance.eventId !== eventId) {
      return res.status(404).json({ success: false, message: 'Attendance record not found' });
    }

    const updatedAttendance = await prisma.attendance.update({
      where: { id: attendanceId },
      data: { verifiedBy: actor.id }
    });

    // Log to Audit Log
    await logAudit(
      actor.id,
      'VERIFY_ATTENDANCE',
      'attendance',
      attendanceId,
      attendance,
      updatedAttendance
    );

    res.status(200).json({
      success: true,
      message: 'Attendance record verified successfully',
      data: updatedAttendance
    });

  } catch (error) {
    next(error);
  }
};
