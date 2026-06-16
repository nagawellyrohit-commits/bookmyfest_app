import express from 'express';
import {
  getFinalYearJobProfiles,
  getAllStudents,
  getAllFaculties,
  getAllCoordinators,
  getAllJobProfiles
} from '../controllers/adminController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// GET /api/admin/job-profiles - Accessible only by super_admin (Legacy/Test compatible)
router.get('/job-profiles', authenticateToken, authorizeRoles('super_admin'), getFinalYearJobProfiles);

// Super Admin user & profile directories
router.get('/students', authenticateToken, authorizeRoles('super_admin'), getAllStudents);
router.get('/faculties', authenticateToken, authorizeRoles('super_admin'), getAllFaculties);
router.get('/coordinators', authenticateToken, authorizeRoles('super_admin'), getAllCoordinators);
router.get('/all-job-profiles', authenticateToken, authorizeRoles('super_admin'), getAllJobProfiles);

export default router;
