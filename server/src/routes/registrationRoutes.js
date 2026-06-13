import express from 'express';
import {
  registerForEvent,
  getEventRegistrations,
  confirmRegistrationPayment
} from '../controllers/registrationController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Student routes (Register for event)
router.post('/:id/register', authenticateToken, registerForEvent);

// Coordinator/Admin routes (View event signups, verify payments)
router.get('/:id/registrations', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), getEventRegistrations);
router.post('/:id/registrations/:regId/confirm', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), confirmRegistrationPayment);

export default router;
