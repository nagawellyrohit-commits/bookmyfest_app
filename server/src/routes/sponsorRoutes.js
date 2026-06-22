import express from 'express';
import {
  getAllSponsors,
  createSponsor,
  updateSponsor,
  deleteSponsor
} from '../controllers/sponsorController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Public route to fetch sponsors for the welcome screen
router.get('/', getAllSponsors);

// Super Admin restricted CRUD operations
router.post('/', authenticateToken, authorizeRoles('super_admin'), createSponsor);
router.put('/:id', authenticateToken, authorizeRoles('super_admin'), updateSponsor);
router.delete('/:id', authenticateToken, authorizeRoles('super_admin'), deleteSponsor);

export default router;
