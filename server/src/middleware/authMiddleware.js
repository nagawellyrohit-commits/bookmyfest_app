import jwt from 'jsonwebtoken';
import prisma from '../config/db.js';

// Middleware to verify if request has valid JWT token
export const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Format: "Bearer TOKEN"

  if (!token) {
    return res.status(401).json({ success: false, message: 'Authentication token is missing' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'college_connect_super_secret_jwt_key_2026');
    
    // Check if the user still exists in the database
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, role: true, collegeId: true, isVerified: true }
    });

    if (!user) {
      return res.status(401).json({ success: false, message: 'User associated with this token no longer exists' });
    }

    // Attach decoded user information to request
    req.user = user; 
    next();
  } catch (error) {
    return res.status(403).json({ success: false, message: 'Invalid or expired authentication token' });
  }
};

// Middleware factory to authorize access to specific roles only
export const authorizeRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'User is not authenticated' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ 
        success: false, 
        message: `Forbidden: Access restricted. Requires one of: [${allowedRoles.join(', ')}]. Current role: '${req.user.role}'` 
      });
    }

    next();
  };
};
