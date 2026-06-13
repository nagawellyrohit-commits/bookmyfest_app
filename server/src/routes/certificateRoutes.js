import express from 'express';
import {
  getCertificateSuggestions,
  approveCertificateTemplate,
  downloadCertificate
} from '../controllers/certificateController.js';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';

const router = express.Router();

// Coordinator/Admin routes (Request suggestions & approve choice)
router.get('/:id/certificates/suggestions', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), getCertificateSuggestions);
router.post('/:id/certificates/approve', authenticateToken, authorizeRoles('coordinator', 'faculty_admin', 'super_admin'), approveCertificateTemplate);

// Student/Attendee route (Download certified participation layout)
router.get('/:id/certificates/download', authenticateToken, downloadCertificate);

export default router;
