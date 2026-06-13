import prisma from '../config/db.js';
import crypto from 'crypto';
import { logAudit } from '../utils/dbHelper.js';

// Create a new event
export const createEvent = async (req, res, next) => {
  const {
    title,
    description,
    eventDate,
    registrationDeadline,
    isPaid,
    entryFee,
    upiId
  } = req.body;

  try {
    const actor = req.user;

    // Check verification status (coordinators / admins must be verified)
    if (actor.role !== 'super_admin' && !actor.isVerified) {
      return res.status(403).json({
        success: false,
        message: 'Account is pending verification by faculty admin. Cannot publish events yet.'
      });
    }

    // Set College ID based on user credentials
    let finalCollegeId = actor.collegeId;
    if (actor.role === 'super_admin') {
      if (!req.body.collegeId) {
        return res.status(400).json({ success: false, message: 'Super admin must specify collegeId' });
      }
      finalCollegeId = req.body.collegeId;
    }

    if (!finalCollegeId) {
      return res.status(400).json({ success: false, message: 'User must belong to a college to create events' });
    }

    // Generate unique QR code string
    const qrAttendanceCode = `cc_qr_${crypto.randomUUID()}`;

    const event = await prisma.event.create({
      data: {
        collegeId: finalCollegeId,
        createdBy: actor.id,
        title,
        description,
        eventDate: new Date(eventDate),
        registrationDeadline: new Date(registrationDeadline),
        isPaid: !!isPaid,
        entryFee: isPaid ? Number(entryFee) : 0.00,
        upiId: isPaid ? upiId : null,
        qrAttendanceCode
      }
    });

    // Write to audit log
    await logAudit(
      actor.id,
      'CREATE_EVENT',
      'events',
      event.id,
      null,
      event
    );

    res.status(201).json({
      success: true,
      message: 'Event created successfully',
      data: event
    });

  } catch (error) {
    next(error);
  }
};

// Fetch all events with role and college checks
export const getAllEvents = async (req, res, next) => {
  try {
    const actor = req.user;
    let whereClause = {};

    // Faculty admins and Coordinators are strictly restricted to their college events
    if (actor.role === 'faculty_admin' || actor.role === 'coordinator') {
      whereClause.collegeId = actor.collegeId;
    }

    const events = await prisma.event.findMany({
      where: whereClause,
      include: {
        college: {
          select: { name: true }
        },
        creator: {
          select: { fullName: true, email: true }
        }
      },
      orderBy: {
        eventDate: 'asc'
      }
    });

    res.status(200).json({
      success: true,
      data: events
    });
  } catch (error) {
    next(error);
  }
};

// Fetch specific event details
export const getEventById = async (req, res, next) => {
  const { id } = req.params;

  try {
    const actor = req.user;
    const event = await prisma.event.findUnique({
      where: { id },
      include: {
        college: {
          select: { name: true }
        },
        creator: {
          select: { fullName: true, email: true }
        }
      }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Faculty admin & coordinator restricted to college
    if ((actor.role === 'faculty_admin' || actor.role === 'coordinator') && event.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot view events of other colleges'
      });
    }

    res.status(200).json({
      success: true,
      data: event
    });
  } catch (error) {
    next(error);
  }
};

// Update an existing event
export const updateEvent = async (req, res, next) => {
  const { id } = req.params;
  const {
    title,
    description,
    eventDate,
    registrationDeadline,
    isPaid,
    entryFee,
    upiId
  } = req.body;

  try {
    const actor = req.user;

    // Check verification status
    if (actor.role !== 'super_admin' && !actor.isVerified) {
      return res.status(403).json({
        success: false,
        message: 'Account is pending verification. Cannot modify events.'
      });
    }

    const existingEvent = await prisma.event.findUnique({ where: { id } });
    if (!existingEvent) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Role boundary checks
    if (actor.role !== 'super_admin' && existingEvent.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot update events belonging to another college'
      });
    }

    // Update payload
    const updatedEvent = await prisma.event.update({
      where: { id },
      data: {
        title: title || existingEvent.title,
        description: description !== undefined ? description : existingEvent.description,
        eventDate: eventDate ? new Date(eventDate) : existingEvent.eventDate,
        registrationDeadline: registrationDeadline ? new Date(registrationDeadline) : existingEvent.registrationDeadline,
        isPaid: isPaid !== undefined ? !!isPaid : existingEvent.isPaid,
        entryFee: isPaid !== undefined ? (isPaid ? Number(entryFee) : 0.00) : existingEvent.entryFee,
        upiId: isPaid !== undefined ? (isPaid ? upiId : null) : existingEvent.upiId
      }
    });

    // Write to audit log
    await logAudit(
      actor.id,
      'UPDATE_EVENT',
      'events',
      id,
      existingEvent,
      updatedEvent
    );

    res.status(200).json({
      success: true,
      message: 'Event updated successfully',
      data: updatedEvent
    });

  } catch (error) {
    next(error);
  }
};

// Delete an event
export const deleteEvent = async (req, res, next) => {
  const { id } = req.params;

  try {
    const actor = req.user;

    // Check verification status
    if (actor.role !== 'super_admin' && !actor.isVerified) {
      return res.status(403).json({
        success: false,
        message: 'Account is pending verification. Cannot delete events.'
      });
    }

    const existingEvent = await prisma.event.findUnique({ where: { id } });
    if (!existingEvent) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Role boundaries
    if (actor.role !== 'super_admin' && existingEvent.collegeId !== actor.collegeId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Cannot delete events belonging to another college'
      });
    }

    await prisma.event.delete({ where: { id } });

    // Write to audit log
    await logAudit(
      actor.id,
      'DELETE_EVENT',
      'events',
      id,
      existingEvent,
      null
    );

    res.status(200).json({
      success: true,
      message: 'Event deleted successfully'
    });

  } catch (error) {
    next(error);
  }
};
