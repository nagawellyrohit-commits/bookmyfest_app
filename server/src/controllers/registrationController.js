import prisma from '../config/db.js';
import { logAudit } from '../utils/dbHelper.js';
import { sendEmailNotification, sendWhatsAppNotification } from '../utils/notifications.js';

// Register a user for an event
export const registerForEvent = async (req, res, next) => {
  const { id: eventId } = req.params;
  const { registrationType, paymentReference, groupSize } = req.body;
  const userId = req.user.id;

  try {
    // 1. Check if event exists
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: { college: true }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Check if event is approved
    if (!event.isApproved) {
      return res.status(403).json({ success: false, message: 'Cannot register: Event is pending approval by faculty' });
    }

    // 2. Check registration deadline
    if (new Date() > new Date(event.registrationDeadline)) {
      return res.status(400).json({ success: false, message: 'Registration deadline has passed' });
    }

    // Validate registration type and group size
    const regType = registrationType || 'individual';
    if (regType === 'group') {
      if (event.eventType === 'individual') {
        return res.status(400).json({ success: false, message: 'This event only allows individual registrations' });
      }
      const size = groupSize ? Number(groupSize) : 1;
      if (size < event.minMembers || size > event.maxMembers) {
        return res.status(400).json({
          success: false,
          message: `Group size must be between ${event.minMembers} and ${event.maxMembers} members`
        });
      }
    } else {
      if (event.eventType === 'group') {
        return res.status(400).json({ success: false, message: 'This event only allows group registrations' });
      }
    }

    // 3. Check if already registered
    const existingRegistration = await prisma.registration.findFirst({
      where: { eventId, userId }
    });

    if (existingRegistration) {
      return res.status(400).json({
        success: false,
        message: 'You are already registered for this event',
        data: existingRegistration
      });
    }

    // 4. Handle paid event validation
    let paymentStatus = 'free_event';
    if (event.isPaid) {
      if (!paymentReference) {
        return res.status(400).json({
          success: false,
          message: 'Payment reference is required for paid events. Please upload/specify the UPI receipt details.'
        });
      }
      paymentStatus = 'pending';
    }

    // 5. Create registration
    const registration = await prisma.registration.create({
      data: {
        eventId,
        userId,
        registrationType: regType,
        paymentStatus,
        paymentReference: event.isPaid ? paymentReference : null
      },
      include: {
        user: {
          select: { fullName: true, email: true, phone: true }
        }
      }
    });

    // 6. Send notification alerts
    const subject = `Registration Update: ${event.title}`;
    let messageText = '';

    if (paymentStatus === 'free_event') {
      messageText = `Hello ${registration.user.fullName},\n\nYour registration for the event "${event.title}" is confirmed! We look forward to seeing you.`;
    } else {
      messageText = `Hello ${registration.user.fullName},\n\nWe have received your registration for the paid event "${event.title}". Your registration is PENDING confirmation of your payment reference: ${paymentReference}. You will receive another alert once approved.`;
    }

    if (event.whatsAppGroupLink) {
      messageText += `\n\nPlease join the WhatsApp group to stay in touch: ${event.whatsAppGroupLink}`;
    }

    // Async notify
    sendEmailNotification(registration.user.email, subject, messageText);
    if (registration.user.phone) {
      sendWhatsAppNotification(registration.user.phone, messageText);
    }

    res.status(201).json({
      success: true,
      message: paymentStatus === 'free_event' ? 'Registered successfully' : 'Registration submitted, pending payment confirmation',
      data: registration
    });

  } catch (error) {
    next(error);
  }
};

// Fetch all registrations for a specific event (Coordinators / Faculty Admins / Super Admins only)
export const getEventRegistrations = async (req, res, next) => {
  const { id: eventId } = req.params;
  const actor = req.user;

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // College boundaries check
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view registrations for other colleges'
      });
    }

    const registrations = await prisma.registration.findMany({
      where: { eventId },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            department: true,
            isFinalYear: true,
            college: {
              select: { name: true }
            }
          }
        }
      },
      orderBy: {
        registrationDate: 'desc'
      }
    });

    // Enforce coordinator view limit (Name, College Name, Phone only)
    if (actor.role === 'coordinator') {
      const mapped = registrations.map(reg => ({
        id: reg.id,
        registrationType: reg.registrationType,
        paymentStatus: reg.paymentStatus,
        paymentReference: reg.paymentReference,
        registrationDate: reg.registrationDate,
        user: {
          fullName: reg.user.fullName,
          phone: reg.user.phone,
          college: {
            name: reg.user.college?.name || 'N/A'
          }
        }
      }));
      return res.status(200).json({ success: true, data: mapped });
    }

    res.status(200).json({
      success: true,
      data: registrations
    });

  } catch (error) {
    next(error);
  }
};

// Confirm payment / approve registration (Coordinators / Faculty Admins / Super Admins only)
export const confirmRegistrationPayment = async (req, res, next) => {
  const { id: eventId, regId } = req.params;
  const actor = req.user;

  try {
    // 1. Fetch Event & Registration
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    const registration = await prisma.registration.findUnique({
      where: { id: regId },
      include: {
        user: {
          select: { fullName: true, email: true, phone: true }
        }
      }
    });

    if (!registration || registration.eventId !== eventId) {
      return res.status(404).json({ success: false, message: 'Registration not found for this event' });
    }

    // 2. Verify coordinator permissions
    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot modify registrations for other colleges'
      });
    }

    if (!actor.isVerified && actor.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Coordinator is not verified. Approval actions are locked.'
      });
    }

    // 3. Update payment status
    const updatedRegistration = await prisma.registration.update({
      where: { id: regId },
      data: { paymentStatus: 'completed' }
    });

    // 4. Log audit log
    await logAudit(
      actor.id,
      'CONFIRM_PAYMENT',
      'registrations',
      regId,
      registration,
      updatedRegistration
    );

    // 5. Send confirmation alert
    const subject = `Payment Confirmed: ${event.title}`;
    const confirmationText = `Hello ${registration.user.fullName},\n\nGood news! Your payment for "${event.title}" has been verified. Your registration is now officially CONFIRMED.`;

    sendEmailNotification(registration.user.email, subject, confirmationText);
    if (registration.user.phone) {
      sendWhatsAppNotification(registration.user.phone, confirmationText);
    }

    res.status(200).json({
      success: true,
      message: 'Registration payment confirmed successfully',
      data: updatedRegistration
    });

  } catch (error) {
    next(error);
  }
};

// Cancel/unregister a registration (Students only, before deadline)
export const unregisterFromEvent = async (req, res, next) => {
  const { id: eventId, regId } = req.params;
  const userId = req.user.id;

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Verify deadline
    if (new Date() > new Date(event.registrationDeadline)) {
      return res.status(400).json({ success: false, message: 'Cannot unregister: Registration deadline has passed' });
    }

    const registration = await prisma.registration.findUnique({ where: { id: regId } });
    if (!registration || registration.eventId !== eventId || registration.userId !== userId) {
      return res.status(404).json({ success: false, message: 'Registration not found or unauthorized' });
    }

    await prisma.registration.delete({ where: { id: regId } });

    res.status(200).json({
      success: true,
      message: 'Successfully unregistered from the event'
    });
  } catch (error) {
    next(error);
  }
};

// Get all pending payments for events belonging to the actor's college
export const getPendingPayments = async (req, res, next) => {
  const actor = req.user;

  try {
    let whereClause = {
      paymentStatus: 'pending'
    };

    // If not super admin, restrict to college events
    if (actor.role !== 'super_admin') {
      whereClause.event = {
        collegeId: actor.collegeId
      };
    }

    const registrations = await prisma.registration.findMany({
      where: whereClause,
      include: {
        event: {
          select: {
            id: true,
            title: true
          }
        },
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            department: true,
            college: {
              select: { name: true }
            }
          }
        }
      },
      orderBy: {
        registrationDate: 'desc'
      }
    });

    res.status(200).json({
      success: true,
      data: registrations
    });

  } catch (error) {
    next(error);
  }
};
