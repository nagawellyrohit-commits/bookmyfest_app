import express from 'express';
import {
  register,
  login,
  getMe,
  getPendingCoordinators,
  verifyCoordinator,
  getPendingFaculties,
  verifyFaculty,
  deleteCoordinator,
  updateProfile,
  uploadFile,
  uploadImage,
  forgotPassword,
  verifyResetCode,
  resetPassword
} from '../controllers/authController.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Public registration and login routes
router.post('/register', register);
router.post('/login', login);
router.post('/upload', uploadFile);
router.post('/upload-image', uploadImage);
router.post('/forgot-password', forgotPassword);
router.post('/verify-reset-code', verifyResetCode);
router.post('/reset-password', resetPassword);

// Protected user profile routes (require valid Bearer token)
router.get('/me', authenticateToken, getMe);
router.put('/me/profile', authenticateToken, updateProfile);

router.get('/pending-coordinators', authenticateToken, getPendingCoordinators);
router.post('/coordinators/:userId/verify', authenticateToken, verifyCoordinator);
router.delete('/coordinators/:userId', authenticateToken, deleteCoordinator);

// Super Admin Only: Faculty approvals
router.get('/pending-faculties', authenticateToken, getPendingFaculties);
router.post('/faculties/:userId/verify', authenticateToken, verifyFaculty);

export default router;
