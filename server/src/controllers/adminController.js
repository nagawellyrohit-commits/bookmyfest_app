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
