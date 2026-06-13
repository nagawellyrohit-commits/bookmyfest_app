import express from 'express';
import {
  createEvent,
  getAllEvents,
  getEventById,
  updateEvent,
  deleteEvent
} from '../controllers/eventController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Public routes for logged in users (Students see all; Coordinators & Admins see college-specific)
router.get('/', authenticateToken, getAllEvents);
router.get('/:id', authenticateToken, getEventById);

// Protected routes (Only coordinators, faculty admins, and super admins can publish or modify)
router.post('/', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), createEvent);
router.put('/:id', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), updateEvent);
router.delete('/:id', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), deleteEvent);

export default router;
