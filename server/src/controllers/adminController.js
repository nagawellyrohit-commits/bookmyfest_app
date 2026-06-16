import prisma from '../config/db.js';

/**
 * Fetch all final-year student job profiles.
 * Restricted to super_admin.
 */
export const getFinalYearJobProfiles = async (req, res, next) => {
  try {
    const students = await prisma.user.findMany({
      where: {
        isFinalYear: true,
        role: 'student'
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        department: true,
        isVerified: true,
        createdAt: true,
        college: {
          select: {
            id: true,
            name: true
          }
        },
        jobProfile: {
          select: {
            id: true,
            resumeUrl: true,
            businessName: true,
            description: true,
            contactPhone: true,
            websiteUrl: true,
            instagramUrl: true,
            linkedinUrl: true,
            branch: true,
            passingYear: true,
            createdAt: true
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    res.status(200).json({
      success: true,
      data: students
    });
  } catch (error) {
    next(error);
  }
};

// Fetch all students (Super Admin only)
export const getAllStudents = async (req, res, next) => {
  try {
    const students = await prisma.user.findMany({
      where: { role: 'student' },
      include: {
        college: { select: { id: true, name: true } },
        jobProfile: true
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: students });
  } catch (error) {
    next(error);
  }
};

// Fetch all faculties (Super Admin only)
export const getAllFaculties = async (req, res, next) => {
  try {
    const faculties = await prisma.user.findMany({
      where: { role: 'faculty_admin' },
      include: {
        college: { select: { id: true, name: true } }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: faculties });
  } catch (error) {
    next(error);
  }
};

// Fetch all coordinators (Super Admin only)
export const getAllCoordinators = async (req, res, next) => {
  try {
    const coordinators = await prisma.user.findMany({
      where: { role: 'coordinator' },
      include: {
        college: { select: { id: true, name: true } }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: coordinators });
  } catch (error) {
    next(error);
  }
};

// Fetch all job profiles (Super Admin only)
export const getAllJobProfiles = async (req, res, next) => {
  try {
    const profiles = await prisma.jobProfile.findMany({
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            department: true,
            college: { select: { id: true, name: true } }
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: profiles });
  } catch (error) {
    next(error);
  }
};
