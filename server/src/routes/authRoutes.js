import express from 'express';
import { register, login, getMe, getPendingCoordinators, verifyCoordinator } from '../controllers/authController.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Public registration and login routes
router.post('/register', register);
router.post('/login', login);

// Protected user profile route (requires valid Bearer token)
router.get('/me', authenticateToken, getMe);
router.get('/pending-coordinators', authenticateToken, getPendingCoordinators);
router.post('/coordinators/:userId/verify', authenticateToken, verifyCoordinator);

export default router;
