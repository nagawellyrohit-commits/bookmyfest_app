import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../config/db.js';
import { sendEmailNotification, sendWhatsAppNotification } from '../utils/notifications.js';

// Register a new user
export const register = async (req, res, next) => {
  const {
    fullName,
    email,
    password,
    phone,
    role,
    collegeId,
    collegeName, // If passed, we can find or create the college dynamically
    department,
    idProofUrl,
    isFinalYear,
    resumeUrl
  } = req.body;

  try {
    // 1. Check if user already exists
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'A user with this email already exists' });
    }

    // 2. Handle College relation
    let finalCollegeId = collegeId || null;
    if (!finalCollegeId && collegeName) {
      // Find or create the college dynamically to make registration seamless
      let college = await prisma.college.findFirst({
        where: { name: { equals: collegeName, mode: 'insensitive' } }
      });
      if (!college) {
        college = await prisma.college.create({
          data: { name: collegeName }
        });
      }
      finalCollegeId = college.id;
    }

    // 3. Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // 4. Create User (within transaction to handle potential JobProfile creation)
    const result = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          fullName,
          email,
          passwordHash,
          phone,
          role: role || 'student',
          collegeId: finalCollegeId,
          department,
          idProofUrl,
          isFinalYear: !!isFinalYear,
          isVerified: role === 'student' // Students verified by default; coordinators/admins need approval
        }
      });

      // If final year is selected and resume is provided, create the Job Profile record
      let jobProfile = null;
      if (isFinalYear && resumeUrl) {
        jobProfile = await tx.jobProfile.create({
          data: {
            userId: newUser.id,
            resumeUrl
          }
        });
      }

      return { newUser, jobProfile };
    });

    // 5. Send registration notification alerts (Email & WhatsApp)
    const welcomeSubject = 'Welcome to CollegeConnect!';
    const welcomeMsg = `Hello ${fullName},\n\nYour registration on CollegeConnect as a ${role || 'student'} has been successfully processed. Thank you for signing up!`;
    
    // Asynchronous send (do not block the response)
    sendEmailNotification(email, welcomeSubject, welcomeMsg);
    if (phone) {
      sendWhatsAppNotification(phone, welcomeMsg);
    }

    // 6. Return response (excluding password hash)
    const { passwordHash: _, ...userWithoutPassword } = result.newUser;
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: userWithoutPassword,
        jobProfile: result.jobProfile
      }
    });

  } catch (error) {
    next(error);
  }
};

// Login user
export const login = async (req, res, next) => {
  const { email, password } = req.body;

  try {
    // 1. Verify fields
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide both email and password' });
    }

    // 2. Fetch user
    const user = await prisma.user.findUnique({
      where: { email },
      include: { college: true }
    });

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // 3. Verify password
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // 4. Generate JWT
    const jwtSecret = process.env.JWT_SECRET || 'college_connect_super_secret_jwt_key_2026';
    const token = jwt.sign(
      {
        id: user.id,
        role: user.role,
        collegeId: user.collegeId
      },
      jwtSecret,
      { expiresIn: '24h' }
    );

    // 5. Return profile and token
    const { passwordHash: _, ...userWithoutPassword } = user;
    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        user: userWithoutPassword
      }
    });

  } catch (error) {
    next(error);
  }
};

// Get current user profile
export const getMe = async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: {
        college: true,
        jobProfile: true
      }
    });

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const { passwordHash: _, ...userWithoutPassword } = user;
    res.status(200).json({
      success: true,
      data: userWithoutPassword
    });

  } catch (error) {
    next(error);
  }
};

// Get pending coordinators for faculty admin's college
export const getPendingCoordinators = async (req, res, next) => {
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only faculty admins can view pending coordinators' });
    }

    const pending = await prisma.user.findMany({
      where: {
        role: 'coordinator',
        isVerified: false,
        collegeId: actor.role === 'super_admin' ? undefined : actor.collegeId
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        department: true,
        idProofUrl: true,
        createdAt: true
      }
    });

    res.status(200).json({
      success: true,
      data: pending
    });
  } catch (error) {
    next(error);
  }
};

// Approve coordinator verification
export const verifyCoordinator = async (req, res, next) => {
  const { userId } = req.params;
  try {
    const actor = req.user;
    if (actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only faculty admins can verify coordinators' });
    }

    const targetUser = await prisma.user.findUnique({ where: { id: userId } });
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'Coordinator not found' });
    }

    if (actor.role !== 'super_admin' && targetUser.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Cannot verify coordinators for other colleges' });
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { isVerified: true }
    });

    res.status(200).json({
      success: true,
      message: 'Coordinator verified successfully',
      data: {
        id: updatedUser.id,
        fullName: updatedUser.fullName,
        isVerified: updatedUser.isVerified
      }
    });
  } catch (error) {
    next(error);
  }
};

