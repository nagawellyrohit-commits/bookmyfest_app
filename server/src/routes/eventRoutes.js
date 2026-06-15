import express from 'express';
import {
  createEvent,
  getAllEvents,
  getEventById,
  updateEvent,
  deleteEvent,
  getPendingEventApprovals,
  approveEventUpdate,
  rejectEventUpdate,
  approveEventDelete,
  rejectEventDelete
} from '../controllers/eventController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Pending approvals list and actions (Faculty Admin / Super Admin)
router.get('/pending-approvals', authenticateToken, authorizeRoles('faculty_admin', 'super_admin'), getPendingEventApprovals);
router.post('/:id/approve-update', authenticateToken, authorizeRoles('faculty_admin', 'super_admin'), approveEventUpdate);
router.post('/:id/reject-update', authenticateToken, authorizeRoles('faculty_admin', 'super_admin'), rejectEventUpdate);
router.post('/:id/approve-delete', authenticateToken, authorizeRoles('faculty_admin', 'super_admin'), approveEventDelete);
router.post('/:id/reject-delete', authenticateToken, authorizeRoles('faculty_admin', 'super_admin'), rejectEventDelete);

// Public routes for logged in users (Students see all; Coordinators & Admins see college-specific)
router.get('/', authenticateToken, getAllEvents);
router.get('/:id', authenticateToken, getEventById);

// Protected routes (Only coordinators, faculty admins, and super admins can publish or modify)
router.post('/', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), createEvent);
router.put('/:id', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), updateEvent);
router.delete('/:id', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), deleteEvent);

export default router;
