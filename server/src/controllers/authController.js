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
    resumeUrl,
    studentId,
    businessName,
    description,
    contactPhone,
    websiteUrl,
    instagramUrl,
    linkedinUrl,
    branch,
    passingYear
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

    // Validate limits per college and studentId uniqueness
    if (finalCollegeId) {
      if (role === 'faculty_admin') {
        const facultyCount = await prisma.user.count({
          where: { collegeId: finalCollegeId, role: 'faculty_admin' }
        });
        if (facultyCount >= 2) {
          return res.status(400).json({
            success: false,
            message: 'A maximum of 2 Faculty Admins are allowed per college'
          });
        }
      } else if (role === 'coordinator') {
        const coordinatorCount = await prisma.user.count({
          where: { collegeId: finalCollegeId, role: 'coordinator' }
        });
        if (coordinatorCount >= 4) {
          return res.status(400).json({
            success: false,
            message: 'A maximum of 4 Coordinators are allowed per college'
          });
        }
      } else if (role === 'student' && studentId) {
        const existingStudentId = await prisma.user.findFirst({
          where: { collegeId: finalCollegeId, studentId: studentId.trim() }
        });
        if (existingStudentId) {
          return res.status(400).json({
            success: false,
            message: 'A student with this Student ID is already registered under this college'
          });
        }
      }
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
          isVerified: role === 'student', // Students verified by default; coordinators/admins need approval
          studentId: role === 'student' && studentId ? studentId.trim() : null
        }
      });

      // If student and any job profile details are provided, create the Job Profile record
      let jobProfile = null;
      const hasJobProfileInfo = resumeUrl || businessName || description || contactPhone || websiteUrl || instagramUrl || linkedinUrl || branch || passingYear;
      if ((role === 'student' || !role) && hasJobProfileInfo) {
        jobProfile = await tx.jobProfile.create({
          data: {
            userId: newUser.id,
            resumeUrl: resumeUrl || 'No resume link provided',
            businessName: businessName || null,
            description: description || null,
            contactPhone: contactPhone || null,
            websiteUrl: websiteUrl || null,
            instagramUrl: instagramUrl || null,
            linkedinUrl: linkedinUrl || null,
            branch: branch || null,
            passingYear: passingYear ? parseInt(passingYear) : null
          }
        });
      }

      return { newUser, jobProfile };
    });

    // 5. Send registration notification alerts (Email & WhatsApp)
    const welcomeSubject = 'Welcome to BookmyFest!';
    const welcomeMsg = `Welcome to BookmyFest! Hello ${fullName}, you have successfully registered to bookmyfest.in app.`;

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
        OR: [
          { isVerified: false },
          { isPendingDeletion: true }
        ],
        collegeId: actor.role === 'super_admin' ? undefined : actor.collegeId
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        department: true,
        idProofUrl: true,
        isPendingDeletion: true,
        isVerified: true,
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
      data: { 
        isVerified: true,
        isPendingDeletion: false
      }
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

// Get pending faculty admins (for Super Admin)
export const getPendingFaculties = async (req, res, next) => {
  try {
    const actor = req.user;
    if (actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only super admins can view pending faculties' });
    }

    const pending = await prisma.user.findMany({
      where: {
        role: 'faculty_admin',
        isVerified: false
      },
      include: {
        college: {
          select: { name: true }
        }
      },
      orderBy: {
        createdAt: 'desc'
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

// Approve faculty admin verification (for Super Admin)
export const verifyFaculty = async (req, res, next) => {
  const { userId } = req.params;
  try {
    const actor = req.user;
    if (actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only super admins can verify faculty' });
    }

    const targetUser = await prisma.user.findUnique({ where: { id: userId } });
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'Faculty admin not found' });
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { isVerified: true }
    });

    res.status(200).json({
      success: true,
      message: 'Faculty admin verified successfully',
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

// Delete/reject a coordinator (for Faculty Admin of the same college, or Super Admin, or self-deletion)
export const deleteCoordinator = async (req, res, next) => {
  const { userId } = req.params;
  try {
    const actor = req.user;
    const isSelf = actor.id === userId;
    const isCoordinatorSelf = isSelf && actor.role === 'coordinator';

    if (!isCoordinatorSelf && actor.role !== 'faculty_admin' && actor.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied: Insufficient permissions' });
    }

    const targetUser = await prisma.user.findUnique({ where: { id: userId } });
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'Coordinator not found' });
    }

    if (!isCoordinatorSelf && actor.role !== 'super_admin' && targetUser.collegeId !== actor.collegeId) {
      return res.status(403).json({ success: false, message: 'Cannot manage coordinators for other colleges' });
    }

    if (isCoordinatorSelf) {
      await prisma.user.update({
        where: { id: userId },
        data: { isPendingDeletion: true }
      });
      return res.status(200).json({
        success: true,
        message: 'Account deletion request submitted and is pending Faculty Admin approval'
      });
    }

    // Delete user from database
    await prisma.user.delete({ where: { id: userId } });

    res.status(200).json({
      success: true,
      message: 'Coordinator deleted successfully'
    });
  } catch (error) {
    next(error);
  }
};

// Update user profile (Student/User editing their own profile details)
export const updateProfile = async (req, res, next) => {
  const userId = req.user.id;
  const {
    fullName,
    phone,
    department,
    studentId,
    // Job Profile details:
    resumeUrl,
    businessName,
    description,
    contactPhone,
    websiteUrl,
    instagramUrl,
    linkedinUrl,
    branch,
    passingYear
  } = req.body;

  try {
    const currentUser = await prisma.user.findUnique({ where: { id: userId } });
    if (!currentUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Validate unique studentId per college if modified and is student
    if (studentId && studentId.trim() !== currentUser.studentId && currentUser.role === 'student') {
      const existingStudentId = await prisma.user.findFirst({
        where: {
          collegeId: currentUser.collegeId,
          studentId: studentId.trim(),
          id: { not: userId }
        }
      });
      if (existingStudentId) {
        return res.status(400).json({
          success: false,
          message: 'A student with this Student ID is already registered under this college'
        });
      }
    }

    // Update user details
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        fullName: fullName || undefined,
        phone: phone || null,
        department: department || null,
        studentId: currentUser.role === 'student' && studentId ? studentId.trim() : currentUser.studentId
      }
    });

    // Upsert JobProfile if any fields are provided
    const hasJobProfileInfo = resumeUrl || businessName || description || contactPhone || websiteUrl || instagramUrl || linkedinUrl || branch || passingYear;
    let updatedJobProfile = null;

    if (hasJobProfileInfo) {
      updatedJobProfile = await prisma.jobProfile.upsert({
        where: { userId },
        create: {
          userId,
          resumeUrl: resumeUrl || 'No resume link provided',
          businessName: businessName || null,
          description: description || null,
          contactPhone: contactPhone || null,
          websiteUrl: websiteUrl || null,
          instagramUrl: instagramUrl || null,
          linkedinUrl: linkedinUrl || null,
          branch: branch || null,
          passingYear: passingYear ? parseInt(passingYear) : null
        },
        update: {
          resumeUrl: resumeUrl !== undefined ? resumeUrl : undefined,
          businessName: businessName !== undefined ? businessName : undefined,
          description: description !== undefined ? description : undefined,
          contactPhone: contactPhone !== undefined ? contactPhone : undefined,
          websiteUrl: websiteUrl !== undefined ? websiteUrl : undefined,
          instagramUrl: instagramUrl !== undefined ? instagramUrl : undefined,
          linkedinUrl: linkedinUrl !== undefined ? linkedinUrl : undefined,
          branch: branch !== undefined ? branch : undefined,
          passingYear: passingYear !== undefined ? (passingYear ? parseInt(passingYear) : null) : undefined
        }
      });
    }

    const { passwordHash: _, ...userWithoutPassword } = updatedUser;
    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        user: userWithoutPassword,
        jobProfile: updatedJobProfile
      }
    });
  } catch (error) {
    next(error);
  }
};


