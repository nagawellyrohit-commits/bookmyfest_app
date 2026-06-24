import prisma from '../config/db.js';
import { Prisma } from '@prisma/client';
import crypto from 'crypto';
import { logAudit } from '../utils/dbHelper.js';
import { sendEmailNotification } from '../utils/notifications.js';

// Create a new event
export const createEvent = async (req, res, next) => {
  const {
    title,
    description,
    eventDate,
    registrationDeadline,
    isPaid,
    entryFee,
    upiId,
    branch,
    brochureUrl,
    brochurePages,
    posterUrl1,
    posterUrl2,
    posterUrl3,
    posterUrl4,
    whatsAppGroupLink,
    eventType,
    minMembers,
    maxMembers,
    category
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

    // Validate brochure page count
    const brochurePagesNum = brochurePages ? Number(brochurePages) : 0;
    if (brochurePagesNum > 150) {
      return res.status(400).json({ success: false, message: 'Brochure limit is 150 pages' });
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
        qrAttendanceCode,
        branch: branch || 'Open',
        category: category || 'Other',
        brochureUrl: brochureUrl || null,
        brochurePages: brochurePagesNum,
        posterUrl1: posterUrl1 || null,
        posterUrl2: posterUrl2 || null,
        posterUrl3: posterUrl3 || null,
        posterUrl4: posterUrl4 || null,
        whatsAppGroupLink: whatsAppGroupLink || null,
        eventType: eventType || 'individual',
        minMembers: minMembers ? Number(minMembers) : 1,
        maxMembers: maxMembers ? Number(maxMembers) : 1,
        isApproved: actor.role === 'coordinator' ? false : true,
        isPendingDeletion: false
      }
    });

    // Send email notifications to faculties if created by a coordinator
    if (actor.role === 'coordinator') {
      try {
        const coordinatorUser = await prisma.user.findUnique({
          where: { id: actor.id },
          select: { fullName: true }
        });
        const coordinatorName = coordinatorUser?.fullName || 'A coordinator';

        const faculties = await prisma.user.findMany({
          where: {
            role: 'faculty_admin',
            collegeId: actor.collegeId,
            isVerified: true
          },
          select: {
            email: true,
            fullName: true
          }
        });
        for (const faculty of faculties) {
          const subject = `New Event Pending Approval: ${event.title}`;
          const text = `Hello ${faculty.fullName},\n\nCoordinator ${coordinatorName} has created a new event "${event.title}" and it is pending your approval.\n\nPlease log in to review and approve this event.`;
          const html = `<p>Hello <strong>${faculty.fullName}</strong>,</p>
                        <p>Coordinator <strong>${coordinatorName}</strong> has created a new event <strong>"${event.title}"</strong> and it is pending your approval.</p>
                        <p>Please log in to review and approve this event.</p>`;
          sendEmailNotification(faculty.email, subject, text, html).catch(err => console.error("Error sending email to faculty:", err));
        }
      } catch (err) {
        console.error("Error sending event creation email notification to faculties:", err);
      }
    }

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

    // Students and guests only see approved events
    if (actor.role === 'student' || actor.role === 'guest') {
      whereClause.isApproved = true;
    }

    const events = await prisma.event.findMany({
      where: whereClause,
      include: {
        college: {
          select: { name: true }
        },
        creator: {
          select: { fullName: true, email: true }
        },
        registrations: {
          where: {
            userId: actor.id
          }
        },
        _count: {
          select: { registrations: true }
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
        },
        registrations: {
          where: {
            userId: actor.id
          }
        },
        _count: {
          select: { registrations: true }
        }
      }
    });

    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    // Students and guests cannot view unapproved events
    if ((actor.role === 'student' || actor.role === 'guest') && !event.isApproved) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Event is pending approval'
      });
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
  const updateData = req.body;

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

    // Validate brochure pages
    if (updateData.brochurePages && Number(updateData.brochurePages) > 150) {
      return res.status(400).json({ success: false, message: 'Brochure limit is 150 pages' });
    }

    // If Coordinator:
    if (actor.role === 'coordinator') {
      let updatedEvent;
      const wasRejected = existingEvent.rejectionReason !== null;

      if (wasRejected) {
        // If it was rejected, we store the edits in pendingUpdates so it shows as edited with options.
        // We do NOT clear rejectionReason here so the faculty knows why it was rejected.
        updatedEvent = await prisma.event.update({
          where: { id },
          data: {
            pendingUpdates: updateData
          }
        });
      } else if (!existingEvent.isApproved) {
        // Direct update for draft/unapproved event if it was NOT rejected
        const finalData = {};
        if (updateData.title !== undefined) finalData.title = updateData.title;
        if (updateData.description !== undefined) finalData.description = updateData.description;
        if (updateData.eventDate !== undefined) finalData.eventDate = new Date(updateData.eventDate);
        if (updateData.registrationDeadline !== undefined) finalData.registrationDeadline = new Date(updateData.registrationDeadline);
        if (updateData.isPaid !== undefined) {
          finalData.isPaid = !!updateData.isPaid;
          finalData.entryFee = updateData.isPaid ? Number(updateData.entryFee || 0) : 0.00;
          finalData.upiId = updateData.isPaid ? updateData.upiId : null;
        }
        if (updateData.branch !== undefined) finalData.branch = updateData.branch;
        if (updateData.category !== undefined) finalData.category = updateData.category;
        if (updateData.brochureUrl !== undefined) finalData.brochureUrl = updateData.brochureUrl;
        if (updateData.brochurePages !== undefined) finalData.brochurePages = Number(updateData.brochurePages);
        if (updateData.posterUrl1 !== undefined) finalData.posterUrl1 = updateData.posterUrl1;
        if (updateData.posterUrl2 !== undefined) finalData.posterUrl2 = updateData.posterUrl2;
        if (updateData.posterUrl3 !== undefined) finalData.posterUrl3 = updateData.posterUrl3;
        if (updateData.posterUrl4 !== undefined) finalData.posterUrl4 = updateData.posterUrl4;
        if (updateData.whatsAppGroupLink !== undefined) finalData.whatsAppGroupLink = updateData.whatsAppGroupLink;
        if (updateData.eventType !== undefined) finalData.eventType = updateData.eventType;
        if (updateData.minMembers !== undefined) finalData.minMembers = Number(updateData.minMembers);
        if (updateData.maxMembers !== undefined) finalData.maxMembers = Number(updateData.maxMembers);
        
        finalData.rejectionReason = null; // Clear rejection reason
        finalData.pendingUpdates = null;  // Clear pending updates just in case

        updatedEvent = await prisma.event.update({
          where: { id },
          data: finalData
        });
      } else {
        // Save changes to pendingUpdates for already approved events
        updatedEvent = await prisma.event.update({
          where: { id },
          data: {
            pendingUpdates: updateData,
            rejectionReason: null // Clear any prior rejection reason
          }
        });
      }

      // Send email notifications to faculty of the same college
      try {
        const coordinatorUser = await prisma.user.findUnique({
          where: { id: actor.id },
          select: { fullName: true }
        });
        const coordinatorName = coordinatorUser?.fullName || 'A coordinator';

        const faculties = await prisma.user.findMany({
          where: {
            role: 'faculty_admin',
            collegeId: actor.collegeId,
            isVerified: true
          },
          select: {
            email: true,
            fullName: true
          }
        });
        const eventTitle = updatedEvent.title || existingEvent.title;
        for (const faculty of faculties) {
          const subject = wasRejected 
            ? `Edited Rejected Event: ${eventTitle}`
            : `Event Update Request: ${eventTitle}`;
          const text = wasRejected
            ? `Hello ${faculty.fullName},\n\nCoordinator ${coordinatorName} has edited the rejected event "${eventTitle}".\n\nPlease log in to review and approve/reject these updates.`
            : `Hello ${faculty.fullName},\n\nCoordinator ${coordinatorName} has edited the event "${eventTitle}".\n\nPlease log in to review and approve/reject these updates.`;
          const html = wasRejected
            ? `<p>Hello <strong>${faculty.fullName}</strong>,</p>
               <p>Coordinator <strong>${coordinatorName}</strong> has edited the rejected event <strong>"${eventTitle}"</strong>.</p>
               <p>Please log in to review and approve/reject these updates.</p>`
            : `<p>Hello <strong>${faculty.fullName}</strong>,</p>
               <p>Coordinator <strong>${coordinatorName}</strong> has edited the event <strong>"${eventTitle}"</strong>.</p>
               <p>Please log in to review and approve/reject these updates.</p>`;
          sendEmailNotification(faculty.email, subject, text, html).catch(err => console.error("Error sending email to faculty:", err));
        }
      } catch (err) {
        console.error("Error sending event edit email notification to faculties:", err);
      }

      return res.status(200).json({
        success: true,
        message: wasRejected
          ? 'Event updates submitted for the rejected event'
          : (existingEvent.isApproved
              ? 'Event updates submitted and pending Faculty Admin approval'
              : 'Event updated successfully and pending Faculty Admin approval'),
        data: updatedEvent
      });
    }

    // If Faculty Admin or Super Admin: direct update
    const finalData = {};
    if (updateData.title !== undefined) finalData.title = updateData.title;
    if (updateData.description !== undefined) finalData.description = updateData.description;
    if (updateData.eventDate !== undefined) finalData.eventDate = new Date(updateData.eventDate);
    if (updateData.registrationDeadline !== undefined) finalData.registrationDeadline = new Date(updateData.registrationDeadline);
    if (updateData.isPaid !== undefined) {
      finalData.isPaid = !!updateData.isPaid;
      finalData.entryFee = updateData.isPaid ? Number(updateData.entryFee || 0) : 0.00;
      finalData.upiId = updateData.isPaid ? updateData.upiId : null;
    }
    if (updateData.branch !== undefined) finalData.branch = updateData.branch;
    if (updateData.category !== undefined) finalData.category = updateData.category;
    if (updateData.brochureUrl !== undefined) finalData.brochureUrl = updateData.brochureUrl;
    if (updateData.brochurePages !== undefined) finalData.brochurePages = Number(updateData.brochurePages);
    if (updateData.posterUrl1 !== undefined) finalData.posterUrl1 = updateData.posterUrl1;
    if (updateData.posterUrl2 !== undefined) finalData.posterUrl2 = updateData.posterUrl2;
    if (updateData.posterUrl3 !== undefined) finalData.posterUrl3 = updateData.posterUrl3;
    if (updateData.posterUrl4 !== undefined) finalData.posterUrl4 = updateData.posterUrl4;
    if (updateData.whatsAppGroupLink !== undefined) finalData.whatsAppGroupLink = updateData.whatsAppGroupLink;
    if (updateData.eventType !== undefined) finalData.eventType = updateData.eventType;
    if (updateData.minMembers !== undefined) finalData.minMembers = Number(updateData.minMembers);
    if (updateData.maxMembers !== undefined) finalData.maxMembers = Number(updateData.maxMembers);

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: finalData
    });

    await logAudit(actor.id, 'UPDATE_EVENT', 'events', id, existingEvent, updatedEvent);

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

    // If Coordinator: set pending deletion flag (unless the event is not approved/draft)
    if (actor.role === 'coordinator') {
      if (!existingEvent.isApproved) {
        await prisma.event.delete({ where: { id } });
        await logAudit(actor.id, 'DELETE_EVENT', 'events', id, existingEvent, null);
        return res.status(200).json({
          success: true,
          message: 'Event deleted/discarded successfully'
        });
      }

      const updatedEvent = await prisma.event.update({
        where: { id },
        data: {
          isPendingDeletion: true
        }
      });
      return res.status(200).json({
        success: true,
        message: 'Event deletion request submitted and pending Faculty Admin approval',
        data: updatedEvent
      });
    }

    // Direct delete for Faculty/Super Admin
    await prisma.event.delete({ where: { id } });

    await logAudit(actor.id, 'DELETE_EVENT', 'events', id, existingEvent, null);

    res.status(200).json({
      success: true,
      message: 'Event deleted successfully'
    });

  } catch (error) {
    next(error);
  }
};

// Get pending event approvals (Updates or Deletions) for a College
export const getPendingEventApprovals = async (req, res, next) => {
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only faculty/super admins can view pending event approvals' });
    }

    const pending = await prisma.event.findMany({
      where: {
        collegeId: actor.role === 'super_admin' ? undefined : actor.collegeId,
        OR: [
          { isApproved: false },
          { isPendingDeletion: true },
          { pendingUpdates: { not: Prisma.AnyNull } }
        ]
      },
      include: {
        creator: {
          select: { fullName: true }
        }
      },
      orderBy: {
        updatedAt: 'desc'
      }
    });

    res.status(200).json({
      success: true,
      data: pending
    });
  } catch (error) {
    next(error);
  }
};

// Approve proposed event updates
export const approveEventUpdate = async (req, res, next) => {
  const { id } = req.params;
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || (!event.pendingUpdates && event.isApproved)) {
      return res.status(404).json({ success: false, message: 'Event or pending approvals not found' });
    }

    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Access denied: college mismatch' });
    }

    const updates = event.pendingUpdates;
    const finalData = { pendingUpdates: null, rejectionReason: null }; // clear pending updates and rejection reason

    if (!event.isApproved) {
      finalData.isApproved = true;
    }

    if (updates) {
      if (updates.title !== undefined) finalData.title = updates.title;
      if (updates.description !== undefined) finalData.description = updates.description;
      if (updates.eventDate !== undefined) finalData.eventDate = new Date(updates.eventDate);
      if (updates.registrationDeadline !== undefined) finalData.registrationDeadline = new Date(updates.registrationDeadline);
      if (updates.isPaid !== undefined) {
        finalData.isPaid = !!updates.isPaid;
        finalData.entryFee = updates.isPaid ? Number(updates.entryFee || 0) : 0.00;
        finalData.upiId = updates.isPaid ? updates.upiId : null;
      }
      if (updates.branch !== undefined) finalData.branch = updates.branch;
      if (updates.category !== undefined) finalData.category = updates.category;
      if (updates.brochureUrl !== undefined) finalData.brochureUrl = updates.brochureUrl;
      if (updates.brochurePages !== undefined) finalData.brochurePages = Number(updates.brochurePages);
      if (updates.posterUrl1 !== undefined) finalData.posterUrl1 = updates.posterUrl1;
      if (updates.posterUrl2 !== undefined) finalData.posterUrl2 = updates.posterUrl2;
      if (updates.posterUrl3 !== undefined) finalData.posterUrl3 = updates.posterUrl3;
      if (updates.posterUrl4 !== undefined) finalData.posterUrl4 = updates.posterUrl4;
      if (updates.whatsAppGroupLink !== undefined) finalData.whatsAppGroupLink = updates.whatsAppGroupLink;
      if (updates.eventType !== undefined) finalData.eventType = updates.eventType;
      if (updates.minMembers !== undefined) finalData.minMembers = Number(updates.minMembers);
      if (updates.maxMembers !== undefined) finalData.maxMembers = Number(updates.maxMembers);
    }

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: finalData
    });

    await logAudit(actor.id, 'APPROVE_EVENT_UPDATE', 'events', id, event, updatedEvent);

    // Send email notifications to coordinators of the same college
    try {
      const actorUser = await prisma.user.findUnique({
        where: { id: actor.id },
        select: { fullName: true }
      });
      const actorName = actorUser?.fullName || 'Faculty/Admin';

      const coordinators = await prisma.user.findMany({
        where: {
          role: 'coordinator',
          collegeId: event.collegeId,
          isVerified: true
        },
        select: {
          email: true,
          fullName: true
        }
      });
      const eventTitle = updatedEvent.title || event.title;
      for (const coord of coordinators) {
        const subject = event.isApproved
          ? `Event Update Approved: ${eventTitle}`
          : `Event Created/Approved: ${eventTitle}`;
        const text = event.isApproved
          ? `Hello ${coord.fullName},\n\nThe proposed updates for the event "${eventTitle}" have been approved by ${actorName}.\n\nYou can now view the updated event on BookMyFest.`
          : `Hello ${coord.fullName},\n\nThe event "${eventTitle}" has been approved and published by ${actorName}.\n\nYou can now view the event on BookMyFest.`;
        const html = event.isApproved
          ? `<p>Hello <strong>${coord.fullName}</strong>,</p>
             <p>The proposed updates for the event <strong>"${eventTitle}"</strong> have been approved by <strong>${actorName}</strong>.</p>
             <p>You can now view the updated event on BookMyFest.</p>`
          : `<p>Hello <strong>${coord.fullName}</strong>,</p>
             <p>The event <strong>"${eventTitle}"</strong> has been approved and published by <strong>${actorName}</strong>.</p>
             <p>You can now view the event on BookMyFest.</p>`;
        sendEmailNotification(coord.email, subject, text, html).catch(err => console.error("Error sending email to coordinator:", err));
      }
    } catch (err) {
      console.error("Error sending event update approval email notification to coordinators:", err);
    }

    res.status(200).json({
      success: true,
      message: 'Event updates approved and applied successfully',
      data: updatedEvent
    });
  } catch (error) {
    next(error);
  }
};

// Discard proposed event updates
export const rejectEventUpdate = async (req, res, next) => {
  const { id } = req.params;
  const { reason } = req.body;
  const finalReason = reason || 'No specific modifications suggested by faculty';
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Access denied: college mismatch' });
    }

    // Get actor user name for emails
    let actorName = 'Faculty/Admin';
    try {
      const actorUser = await prisma.user.findUnique({
        where: { id: actor.id },
        select: { fullName: true }
      });
      if (actorUser) actorName = actorUser.fullName;
    } catch (err) {
      console.error(err);
    }

    if (!event.isApproved) {
      const updatedEvent = await prisma.event.update({
        where: { id },
        data: {
          rejectionReason: finalReason
        }
      });

      // Send email notifications to coordinators of the same college
      try {
        const coordinators = await prisma.user.findMany({
          where: {
            role: 'coordinator',
            collegeId: event.collegeId,
            isVerified: true
          },
          select: {
            email: true,
            fullName: true
          }
        });
        const eventTitle = event.title;
        for (const coord of coordinators) {
          const subject = `Event Creation Rejected: ${eventTitle}`;
          const text = `Hello ${coord.fullName},\n\nThe request to create/publish the event "${eventTitle}" has been rejected/discarded by ${actorName}.\n\nReason/Modifications:\n${finalReason}`;
          const html = `<p>Hello <strong>${coord.fullName}</strong>,</p>
                        <p>The request to create/publish the event <strong>"${eventTitle}"</strong> has been rejected/discarded by <strong>${actorName}</strong>.</p>
                        <p><strong>Reason/Modifications requested:</strong> ${finalReason}</p>`;
          sendEmailNotification(coord.email, subject, text, html).catch(err => console.error("Error sending email to coordinator:", err));
        }
      } catch (err) {
        console.error("Error sending event creation rejection email notification to coordinators:", err);
      }

      return res.status(200).json({
        success: true,
        message: 'Event creation request rejected and reason saved',
        data: updatedEvent
      });
    }

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: {
        pendingUpdates: null,
        rejectionReason: finalReason
      }
    });

    // Send email notifications to coordinators of the same college
    try {
      const coordinators = await prisma.user.findMany({
        where: {
          role: 'coordinator',
          collegeId: event.collegeId,
          isVerified: true
        },
        select: {
          email: true,
          fullName: true
        }
      });
      const eventTitle = event.title;
      for (const coord of coordinators) {
        const subject = `Event Update Rejected: ${eventTitle}`;
        const text = `Hello ${coord.fullName},\n\nThe proposed updates for the event "${eventTitle}" have been rejected/discarded by ${actorName}.\n\nReason/Modifications:\n${finalReason}`;
        const html = `<p>Hello <strong>${coord.fullName}</strong>,</p>
                      <p>The proposed updates for the event <strong>"${eventTitle}"</strong> have been rejected/discarded by <strong>${actorName}</strong>.</p>
                      <p><strong>Reason/Modifications requested:</strong> ${finalReason}</p>`;
        sendEmailNotification(coord.email, subject, text, html).catch(err => console.error("Error sending email to coordinator:", err));
      }
    } catch (err) {
      console.error("Error sending event update rejection email notification to coordinators:", err);
    }

    res.status(200).json({
      success: true,
      message: 'Pending updates discarded and reason saved',
      data: updatedEvent
    });
  } catch (error) {
    next(error);
  }
};

// Approve deletion of event
export const approveEventDelete = async (req, res, next) => {
  const { id } = req.params;
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event || !event.isPendingDeletion) {
      return res.status(404).json({ success: false, message: 'Event or pending deletion request not found' });
    }

    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Access denied: college mismatch' });
    }

    await prisma.event.delete({ where: { id } });

    await logAudit(actor.id, 'APPROVE_EVENT_DELETE', 'events', id, event, null);

    // Send email notifications to coordinators of the same college
    try {
      const actorUser = await prisma.user.findUnique({
        where: { id: actor.id },
        select: { fullName: true }
      });
      const actorName = actorUser?.fullName || 'Faculty/Admin';

      const coordinators = await prisma.user.findMany({
        where: {
          role: 'coordinator',
          collegeId: event.collegeId,
          isVerified: true
        },
        select: {
          email: true,
          fullName: true
        }
      });
      const eventTitle = event.title;
      for (const coord of coordinators) {
        const subject = `Event Deleted: ${eventTitle}`;
        const text = `Hello ${coord.fullName},\n\nThe event "${eventTitle}" has been deleted following approval of the deletion request by ${actorName}.`;
        const html = `<p>Hello <strong>${coord.fullName}</strong>,</p>
                      <p>The event <strong>"${eventTitle}"</strong> has been deleted following approval of the deletion request by <strong>${actorName}</strong>.</p>`;
        sendEmailNotification(coord.email, subject, text, html).catch(err => console.error("Error sending email to coordinator:", err));
      }
    } catch (err) {
      console.error("Error sending event delete approval email notification to coordinators:", err);
    }

    res.status(200).json({
      success: true,
      message: 'Event deletion request approved, event deleted'
    });
  } catch (error) {
    next(error);
  }
};

// Cancel deletion request of event
export const rejectEventDelete = async (req, res, next) => {
  const { id } = req.params;
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) {
      return res.status(404).json({ success: false, message: 'Event not found' });
    }

    if (actor.role !== 'super_admin' && event.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Access denied: college mismatch' });
    }

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: { isPendingDeletion: false }
    });

    // Send email notifications to coordinators of the same college
    try {
      const actorUser = await prisma.user.findUnique({
        where: { id: actor.id },
        select: { fullName: true }
      });
      const actorName = actorUser?.fullName || 'Faculty/Admin';

      const coordinators = await prisma.user.findMany({
        where: {
          role: 'coordinator',
          collegeId: event.collegeId,
          isVerified: true
        },
        select: {
          email: true,
          fullName: true
        }
      });
      const eventTitle = event.title;
      for (const coord of coordinators) {
        const subject = `Event Deletion Rejected: ${eventTitle}`;
        const text = `Hello ${coord.fullName},\n\nThe request to delete the event "${eventTitle}" has been rejected/cancelled by ${actorName}.`;
        const html = `<p>Hello <strong>${coord.fullName}</strong>,</p>
                      <p>The request to delete the event <strong>"${eventTitle}"</strong> has been rejected/cancelled by <strong>${actorName}</strong>.</p>`;
        sendEmailNotification(coord.email, subject, text, html).catch(err => console.error("Error sending email to coordinator:", err));
      }
    } catch (err) {
      console.error("Error sending event delete rejection email notification to coordinators:", err);
    }

    res.status(200).json({
      success: true,
      message: 'Event deletion request rejected',
      data: updatedEvent
    });
  } catch (error) {
    next(error);
  }
};
