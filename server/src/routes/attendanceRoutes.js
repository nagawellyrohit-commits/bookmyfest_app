import express from 'express';
import {
  scanEventQr,
  getEventAttendance,
  verifyAttendanceRecord
} from '../controllers/attendanceController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Student routes (Scan QR attendance)
router.post('/:id/scan', authenticateToken, scanEventQr);

// Coordinator/Admin routes (View attendance logs, manually verify logs)
router.get('/:id/attendance', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), getEventAttendance);
router.post('/:id/attendance/:attendanceId/verify', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), verifyAttendanceRecord);

export default router;
