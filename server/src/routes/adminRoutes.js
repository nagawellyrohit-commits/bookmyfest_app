import express from 'express';
import { getFinalYearJobProfiles } from '../controllers/adminController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// GET /api/admin/job-profiles - Accessible only by super_admin
router.get('/job-profiles', authenticateToken, authorizeRoles('super_admin'), getFinalYearJobProfiles);

export default router;
