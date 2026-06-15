import express from 'express';
import {
  registerForEvent,
  getEventRegistrations,
  confirmRegistrationPayment,
  unregisterFromEvent
} from '../controllers/registrationController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Student routes (Register & Unregister)
router.post('/:id/register', authenticateToken, registerForEvent);
router.delete('/:id/registrations/:regId', authenticateToken, unregisterFromEvent);

// Coordinator/Admin routes (View event signups, verify payments)
router.get('/:id/registrations', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), getEventRegistrations);
router.post('/:id/registrations/:regId/confirm', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), confirmRegistrationPayment);

export default router;
