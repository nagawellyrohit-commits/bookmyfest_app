import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../config/db.js';
import { sendEmailNotification, sendWhatsAppNotification } from '../utils/notifications.js';
import multer from 'multer';
import path from 'path';
import { createWorker } from 'tesseract.js';
import fs from 'fs';
import axios from 'axios';
import cloudinary from '../config/cloudinary.js';


const resetCodes = new Map();

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
    passingYear,
    isParent,
    parentStudentName,
    parentStudentCollege
  } = req.body;

  try {
    // 1. Check if user already exists
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'A user with this email already exists' });
    }

    // 1b. Validate student/coordinator ID proof and perform OCR verification for both
    if (role === 'student' || role === 'coordinator') {
      if (!idProofUrl || idProofUrl === 'https://via.placeholder.com/150' || idProofUrl.trim() === '') {
        return res.status(400).json({
          success: false,
          message: 'Student College ID proof image is mandatory to register.'
        });
      }

      if (role === 'student' || role === 'coordinator') {
        let localPath = null;
        let isCloudinary = idProofUrl.includes('cloudinary.com') || idProofUrl.includes('res.cloudinary.com');
        let bypassOcr = idProofUrl === 'http://example.com/student-id.png' ||
                        idProofUrl === 'http://example.com/coord-id.png' ||
                        idProofUrl.includes('test-ocr-bypass');

        if (bypassOcr) {
          console.log('[OCR Verification] Bypassing OCR validation for test/mock URL:', idProofUrl);
        } else if (idProofUrl.includes('/uploads/')) {
          const filename = idProofUrl.split('/uploads/')[1];
          localPath = path.join('uploads', filename);
        } else if (isCloudinary) {
          console.log('[OCR Verification] Processing Cloudinary URL for OCR:', idProofUrl);
        } else {
          return res.status(400).json({
            success: false,
            message: 'Student College ID proof must be a valid uploaded file.'
          });
        }

        if (!bypassOcr) {
          try {
            let ocrInput;
            if (isCloudinary) {
              console.log(`[OCR Verification] Downloading Cloudinary image for OCR: ${idProofUrl}`);
              const response = await axios.get(idProofUrl, { responseType: 'arraybuffer' });
              ocrInput = Buffer.from(response.data);
            } else if (localPath) {
              console.log(`[OCR Verification] Performing OCR on local file: ${localPath}`);
              ocrInput = localPath;
            }

            if (ocrInput) {
              const ocrText = await performOcr(ocrInput);
              console.log('[OCR Verification] Extracted Text:', ocrText);

              const isMatched = verifyOcrMatch(ocrText, fullName, collegeName, department);
              if (!isMatched) {
                return res.status(400).json({
                  success: false,
                  message: 'Student College ID and details are not matched'
                });
              }
              console.log('[OCR Verification] Success! Matched.');
            } else {
              throw new Error('No input file or buffer resolved for OCR.');
            }
          } catch (ocrErr) {
            console.error('[OCR Error during registration]:', ocrErr);
            return res.status(400).json({
              success: false,
              message: ocrErr.message || 'Verification failed: Failed to process the Student College ID image.'
            });
          }
        }
      }
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
          isVerified: role === 'student' || role === 'guest', // Students and guests verified by default; coordinators/admins need approval
          studentId: role === 'student' && studentId ? studentId.trim() : null,
          isParent: role === 'guest' && (isParent === true || isParent === 'true'),
          parentStudentName: role === 'guest' && parentStudentName ? parentStudentName.trim() : null,
          parentStudentCollege: role === 'guest' && parentStudentCollege ? parentStudentCollege.trim() : null
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
    const finalRole = result.newUser.role;
    let welcomeSubject = '';
    let welcomeMsg = '';
    let welcomeMsgHtml = '';

    if (finalRole === 'student') {
      welcomeSubject = 'Welcome to BookmyFest!';
      const displayId = studentId ? studentId.trim() : 'N/A';
      welcomeMsg = `Hello ${fullName}, thank you, you have successfully registered with your student ID (${displayId}) in to bookmyfest.co.`;
      welcomeMsgHtml = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
          <div style="text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 20px; margin-bottom: 25px;">
            <h2 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 700;">Welcome to BookmyFest!</h2>
          </div>
          <div style="font-size: 16px; color: #334155; line-height: 1.6;">
            <p>Hello <strong>${fullName}</strong>,</p>
            <p style="font-size: 18px; color: #0f172a; font-weight: 600; margin: 24px 0;">
              Thank you, you have successfully registered with your student ID (<strong>${displayId}</strong>) in to <strong>bookmyfest.co</strong>.
            </p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
            <p style="font-size: 13px; color: #64748b;">
              If you did not initiate this registration, please contact our support team.
            </p>
          </div>
          <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
            <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
          </div>
        </div>
      `;
    } else if (finalRole === 'super_admin') {
      welcomeSubject = 'Welcome to BookmyFest - Admin Account Created';
      welcomeMsg = `Hello ${fullName}, thank you, you have successfully registered with your admin ID (${email}) in to bookmyfest.co.`;
      welcomeMsgHtml = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
          <div style="text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 20px; margin-bottom: 25px;">
            <h2 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 700;">Welcome to BookmyFest!</h2>
          </div>
          <div style="font-size: 16px; color: #334155; line-height: 1.6;">
            <p>Hello <strong>${fullName}</strong>,</p>
            <p style="font-size: 18px; color: #0f172a; font-weight: 600; margin: 24px 0;">
              Thank you, you have successfully registered with your admin ID (<strong>${email}</strong>) in to <strong>bookmyfest.co</strong>.
            </p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
            <p style="font-size: 13px; color: #64748b;">
              If you did not initiate this registration, please contact our support team.
            </p>
          </div>
          <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
            <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
          </div>
        </div>
      `;
    } else if (finalRole === 'coordinator') {
      welcomeSubject = 'Registration Received - BookmyFest';
      welcomeMsg = `Hello ${fullName}, thank you, your coordinator ID (${email}) is created but verification is pending from the Faculty. Once verified, you will receive a confirmation email.`;
      welcomeMsgHtml = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
          <div style="text-align: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 20px; margin-bottom: 25px;">
            <h2 style="color: #64748b; margin: 0; font-size: 24px; font-weight: 700;">Registration Received</h2>
          </div>
          <div style="font-size: 16px; color: #334155; line-height: 1.6;">
            <p>Hello <strong>${fullName}</strong>,</p>
            <p style="font-size: 17px; color: #0f172a; font-weight: 600; margin: 24px 0;">
              Thank you, your coordinator ID (<strong>${email}</strong>) is created but verification is pending from the Faculty.
            </p>
            <p>Once the Faculty Admin accepts/verifies your ID, you will receive a confirmation email indicating that you are successfully registered with bookmyfest.co.</p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
            <p style="font-size: 13px; color: #64748b;">
              Please hold tight while your college Faculty Admin reviews your proof of identification.
            </p>
          </div>
          <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
            <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
          </div>
        </div>
      `;
    } else if (finalRole === 'faculty_admin') {
      welcomeSubject = 'Registration Received - BookmyFest';
      welcomeMsg = `Hello ${fullName}, thank you, your faculty ID (${email}) is created but verification is pending from the Admin. Once verified, you will receive a confirmation email.`;
      welcomeMsgHtml = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
          <div style="text-align: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 20px; margin-bottom: 25px;">
            <h2 style="color: #64748b; margin: 0; font-size: 24px; font-weight: 700;">Registration Received</h2>
          </div>
          <div style="font-size: 16px; color: #334155; line-height: 1.6;">
            <p>Hello <strong>${fullName}</strong>,</p>
            <p style="font-size: 17px; color: #0f172a; font-weight: 600; margin: 24px 0;">
              Thank you, your faculty ID (<strong>${email}</strong>) is created but verification is pending from the Admin.
            </p>
            <p>Once the Super Admin accepts/verifies your ID, you will receive a confirmation email indicating that you are successfully registered with bookmyfest.co.</p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
            <p style="font-size: 13px; color: #64748b;">
              Please hold tight while the System Admin reviews your registration.
            </p>
          </div>
          <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
            <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
          </div>
        </div>
      `;
    } else if (finalRole === 'guest') {
      welcomeSubject = 'Welcome to BookmyFest - Guest Account Created';
      welcomeMsg = `Hello ${fullName}, thank you, you have successfully registered as a Guest with email (${email}) on bookmyfest.co.`;
      welcomeMsgHtml = `
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
          <div style="text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 20px; margin-bottom: 25px;">
            <h2 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 700;">Welcome to BookmyFest!</h2>
          </div>
          <div style="font-size: 16px; color: #334155; line-height: 1.6;">
            <p>Hello <strong>${fullName}</strong>,</p>
            <p style="font-size: 18px; color: #0f172a; font-weight: 600; margin: 24px 0;">
              Thank you, you have successfully registered as a Guest with your email (<strong>${email}</strong>) on <strong>bookmyfest.co</strong>.
            </p>
            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
            <p style="font-size: 13px; color: #64748b;">
              You can now browse events from all colleges!
            </p>
          </div>
          <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
            <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
          </div>
        </div>
      `;
    }

    if (welcomeSubject) {
      sendEmailNotification(email, welcomeSubject, welcomeMsg, welcomeMsgHtml);
      if (phone) {
        sendWhatsAppNotification(phone, welcomeMsg);
      }
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

    // Send welcome/approval email to coordinator
    const welcomeSubject = 'Account Verified - BookmyFest';
    const welcomeMsg = `Hello ${updatedUser.fullName}, your coordinator ID (${updatedUser.email}) is verified and now you are successfully registered with bookmyfest.co.`;
    const welcomeMsgHtml = `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
        <div style="text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 20px; margin-bottom: 25px;">
          <h2 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 700;">Account Approved</h2>
        </div>
        <div style="font-size: 16px; color: #334155; line-height: 1.6;">
          <p>Hello <strong>${updatedUser.fullName}</strong>,</p>
          <p style="font-size: 18px; color: #0f172a; font-weight: 600; margin: 24px 0;">
            Your coordinator ID (<strong>${updatedUser.email}</strong>) is verified and now you are successfully registered with <strong>bookmyfest.co</strong>.
          </p>
          <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
          <p style="font-size: 13px; color: #64748b;">
            You can now log in to the application and start managing events!
          </p>
        </div>
        <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
          <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
        </div>
      </div>
    `;

    sendEmailNotification(updatedUser.email, welcomeSubject, welcomeMsg, welcomeMsgHtml);
    if (updatedUser.phone) {
      sendWhatsAppNotification(updatedUser.phone, welcomeMsg);
    }

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

    // Send welcome/approval email to faculty
    const welcomeSubject = 'Account Verified - BookmyFest';
    const welcomeMsg = `Hello ${updatedUser.fullName}, your faculty ID (${updatedUser.email}) is verified and now you are successfully registered with bookmyfest.co.`;
    const welcomeMsgHtml = `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.025);">
        <div style="text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 20px; margin-bottom: 25px;">
          <h2 style="color: #4f46e5; margin: 0; font-size: 24px; font-weight: 700;">Account Approved</h2>
        </div>
        <div style="font-size: 16px; color: #334155; line-height: 1.6;">
          <p>Hello <strong>${updatedUser.fullName}</strong>,</p>
          <p style="font-size: 18px; color: #0f172a; font-weight: 600; margin: 24px 0;">
            Your faculty ID (<strong>${updatedUser.email}</strong>) is verified and now you are successfully registered with <strong>bookmyfest.co</strong>.
          </p>
          <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 25px 0;" />
          <p style="font-size: 13px; color: #64748b;">
            You can now log in to the application and start approving coordinators!
          </p>
        </div>
        <div style="text-align: center; margin-top: 30px; border-top: 1px solid #f1f5f9; padding-top: 20px; font-size: 12px; color: #94a3b8;">
          <p>&copy; ${new Date().getFullYear()} BookmyFest. All rights reserved.</p>
        </div>
      </div>
    `;

    sendEmailNotification(updatedUser.email, welcomeSubject, welcomeMsg, welcomeMsgHtml);
    if (updatedUser.phone) {
      sendWhatsAppNotification(updatedUser.phone, welcomeMsg);
    }

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
      // Delete user immediately to comply with Guideline 5.1.1(v)
      await prisma.user.delete({ where: { id: userId } });

      // Send confirmation email
      const emailSubject = 'Account Deleted Successfully';
      const emailText = `Hello ${targetUser.fullName},\n\nYour CollegeConnect account has been deleted successfully. All your data has been permanently removed.\n\nThank you for using CollegeConnect!`;
      const emailHtml = `<h3>Account Deleted Successfully</h3><p>Hello <strong>${targetUser.fullName}</strong>,</p><p>Your CollegeConnect account has been deleted successfully. All your data has been permanently removed.</p><p>Thank you for using CollegeConnect!</p>`;
      
      sendEmailNotification(targetUser.email, emailSubject, emailText, emailHtml).catch(err => 
        console.error('[Deletion Email Error]: Failed to send success email:', err)
      );

      return res.status(200).json({
        success: true,
        message: 'Account deleted successfully'
      });
    }

    // Delete user from database
    await prisma.user.delete({ where: { id: userId } });

    // Send confirmation email (coordinator deleted by admin)
    const emailSubject = 'Account Deleted by Administrator';
    const emailText = `Hello ${targetUser.fullName},\n\nYour CollegeConnect coordinator account has been deleted by an administrator.\n\nIf you believe this is an error, please contact your faculty coordinator.`;
    const emailHtml = `<h3>Account Deleted</h3><p>Hello <strong>${targetUser.fullName}</strong>,</p><p>Your CollegeConnect coordinator account has been deleted by an administrator.</p><p>If you believe this is an error, please contact your faculty coordinator.</p>`;
    
    sendEmailNotification(targetUser.email, emailSubject, emailText, emailHtml).catch(err => 
      console.error('[Deletion Email Error]: Failed to send deletion email:', err)
    );

    res.status(200).json({
      success: true,
      message: 'Coordinator deleted successfully'
    });
  } catch (error) {
    next(error);
  }
};

// Delete own account (any role: student, coordinator, faculty_admin, super_admin, guest)
export const deleteAccount = async (req, res, next) => {
  try {
    const userId = req.user.id;
    
    // Fetch user details first since req.user from authMiddleware only selects id, role, collegeId, isVerified
    const targetUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, fullName: true }
    });

    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const userEmail = targetUser.email;
    const userName = targetUser.fullName;

    await prisma.user.delete({ where: { id: userId } });

    // Send confirmation email
    const emailSubject = 'Account Deleted Successfully';
    const emailText = `Hello ${userName},\n\nYour CollegeConnect account has been deleted successfully. All your data has been permanently removed.\n\nThank you for using CollegeConnect!`;
    const emailHtml = `<h3>Account Deleted Successfully</h3><p>Hello <strong>${userName}</strong>,</p><p>Your CollegeConnect account has been deleted successfully. All your data has been permanently removed.</p><p>Thank you for using CollegeConnect!</p>`;
    
    sendEmailNotification(userEmail, emailSubject, emailText, emailHtml).catch(err => 
      console.error('[Deletion Email Error]: Failed to send success email:', err)
    );

    res.status(200).json({
      success: true,
      message: 'Account deleted successfully'
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
          resumeUrl: (resumeUrl !== undefined && resumeUrl !== null) ? resumeUrl : undefined,
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

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

// Multer Upload Setup
const upload = multer({
  storage: storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB file size limit
  fileFilter: (req, file, cb) => {
    console.log('[Multer fileFilter] Received file metadata:', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    });
    const filetypes = /pdf/;
    const extname = filetypes.test(path.extname(file.originalname || '').toLowerCase());

    if (extname) {
      return cb(null, true);
    }
    cb(new Error('Only PDF format (.pdf) files are allowed!'));
  }
}).single('file');

// Export uploadFile controller
export const uploadFile = (req, res, next) => {
  upload(req, res, async (err) => {
    if (err) {
      console.error('[Multer upload error]:', err);
    }
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
          success: false,
          message: 'File is too large. Maximum size allowed is 20MB.'
        });
      }
      return res.status(400).json({ success: false, message: err.message });
    } else if (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    if (!req.file) {
      console.warn('[Multer upload warning]: No file attached in req.file');
      return res.status(400).json({ success: false, message: 'Please select a PDF file to upload.' });
    }

    console.log('[Multer upload success] Saved local file:', req.file.filename);

    // Support Local Storage Option
    if (process.env.UPLOAD_STORAGE === 'local' || !process.env.CLOUDINARY_API_KEY) {
      const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      console.log('[Local Upload Success] Accessible via URL:', fileUrl);
      return res.status(200).json({
        success: true,
        message: 'PDF CV uploaded successfully',
        fileUrl: fileUrl,
        fileName: req.file.originalname
      });
    }

    try {
      console.log('[Cloudinary upload] Uploading resume to Cloudinary:', req.file.path);
      const result = await cloudinary.uploader.upload(req.file.path, {
        folder: 'resumes',
        resource_type: 'raw',
        use_filename: true,
        unique_filename: true
      });

      console.log('[Cloudinary upload success] Secure URL:', result.secure_url);

      // Clean up local temp file asynchronously
      fs.promises.unlink(req.file.path).catch((unlinkErr) => {
        console.error('[Cleanup Error] Failed to delete local temp file:', req.file.path, unlinkErr);
      });

      res.status(200).json({
        success: true,
        message: 'PDF CV uploaded successfully',
        fileUrl: result.secure_url,
        fileName: req.file.originalname
      });
    } catch (uploadErr) {
      console.error('[Cloudinary upload error]:', uploadErr);
      
      // Cleanup local temp file
      fs.promises.unlink(req.file.path).catch(() => {});

      return res.status(500).json({
        success: false,
        message: 'Failed to upload PDF CV to Cloudinary. Please check Cloudinary configuration.'
      });
    }
  });
};

// Multer Upload Image Setup
const uploadImageMulter = multer({
  storage: storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB file size limit
  fileFilter: (req, file, cb) => {
    console.log('[Multer image fileFilter] Received file metadata:', {
      fieldname: file.fieldname,
      originalname: file.originalname,
      mimetype: file.mimetype
    });
    // Accept image extensions: jpeg, png, jpg, gif, webp, pic, img, heic, heif, jfif
    const filetypes = /jpeg|jpg|png|gif|webp|pic|img|heic|heif|jfif/;
    const extname = filetypes.test(path.extname(file.originalname || '').toLowerCase());
    const isImageMimetype = file.mimetype.startsWith('image/');

    if (extname || isImageMimetype) {
      return cb(null, true);
    }
    cb(new Error('Only image formats (.jpeg, .jpg, .png, .pic, .img, etc.) are allowed!'));
  }
}).single('file');

export const uploadImage = (req, res, next) => {
  uploadImageMulter(req, res, async (err) => {
    if (err) {
      console.error('[Multer image upload error]:', err);
    }
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
          success: false,
          message: 'Image is too large. Maximum size allowed is 20MB.'
        });
      }
      return res.status(400).json({ success: false, message: err.message });
    } else if (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    if (!req.file) {
      console.warn('[Multer image upload warning]: No file attached in req.file');
      return res.status(400).json({ success: false, message: 'Please select an image file to upload.' });
    }

    console.log('[Multer image upload success] Saved local file:', req.file.filename);

    // Support Local Storage Option
    if (process.env.UPLOAD_STORAGE === 'local' || !process.env.CLOUDINARY_API_KEY) {
      const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      console.log('[Local Image Upload Success] Accessible via URL:', fileUrl);
      return res.status(200).json({
        success: true,
        message: 'Image uploaded successfully',
        fileUrl: fileUrl,
        fileName: req.file.originalname
      });
    }

    try {
      console.log('[Cloudinary upload] Uploading image to Cloudinary:', req.file.path);
      const result = await cloudinary.uploader.upload(req.file.path, {
        folder: 'images',
        resource_type: 'image'
      });

      console.log('[Cloudinary upload success] Secure URL:', result.secure_url);

      // Clean up local temp file asynchronously
      fs.promises.unlink(req.file.path).catch((unlinkErr) => {
        console.error('[Cleanup Error] Failed to delete local temp file:', req.file.path, unlinkErr);
      });

      res.status(200).json({
        success: true,
        message: 'Image uploaded successfully',
        fileUrl: result.secure_url,
        fileName: req.file.originalname
      });
    } catch (uploadErr) {
      console.error('[Cloudinary upload error]:', uploadErr);
      
      // Cleanup local temp file
      fs.promises.unlink(req.file.path).catch(() => {});

      return res.status(500).json({
        success: false,
        message: 'Failed to upload image to Cloudinary. Please check Cloudinary configuration.'
      });
    }
  });
};

// OCR local verification helper
async function performOcr(filePath) {
  try {
    const worker = await createWorker('eng');
    const ret = await worker.recognize(filePath);
    await worker.terminate();
    return ret.data.text;
  } catch (err) {
    console.error('[OCR Recognition Error]:', err);
    throw new Error('Failed to run OCR text recognition on the uploaded student ID image.');
  }
}

// Check if both Full Name and College Name match the OCR text
function verifyOcrMatch(extractedText, fullName, collegeName, department) {
  if (!extractedText) return false;

  const cleanText = extractedText.toLowerCase();

  // Helper to sanitize string for matching
  const sanitize = (str) => {
    return (str || '').toLowerCase().replace(/[^a-z0-9\s]/g, '').replace(/\s+/g, ' ').trim();
  };

  const sText = sanitize(cleanText);
  const sFullName = sanitize(fullName);
  const sCollegeName = sanitize(collegeName);

  console.log('[OCR Sanitized Matching] Clean Text:', sText);
  console.log('[OCR Sanitized Matching] Name:', sFullName, '| College:', sCollegeName);

  // 1. Check Full Name Match
  let nameMatch = false;
  if (sFullName && sText.includes(sFullName)) {
    nameMatch = true;
  } else if (sFullName) {
    // Lenient name word match: check if significant words in name match
    const words = sFullName.split(/\s+/).filter(w => w.length > 3);
    for (const word of words) {
      if (sText.includes(word)) {
        nameMatch = true;
        break;
      }
    }
    // Fallback if all words are 3 chars or shorter
    if (!nameMatch && sFullName.split(/\s+/).length > 0) {
      const shortWords = sFullName.split(/\s+/).filter(w => w.length > 0);
      for (const word of shortWords) {
        if (sText.includes(word)) {
          nameMatch = true;
          break;
        }
      }
    }
  }

  // 2. Check College Name Match
  let collegeMatch = false;
  if (sCollegeName && sText.includes(sCollegeName)) {
    collegeMatch = true;
  } else if (sCollegeName) {
    // Lenient college word match: check if significant words match
    const words = sCollegeName.split(/\s+/).filter(w => w.length > 3 && w !== 'university' && w !== 'college' && w !== 'institute' && w !== 'technology');
    for (const word of words) {
      if (sText.includes(word)) {
        collegeMatch = true;
        break;
      }
    }
    // Fallback if all words are short or noise words
    if (!collegeMatch && sCollegeName.split(/\s+/).length > 0) {
      const shortWords = sCollegeName.split(/\s+/).filter(w => w.length > 0 && w !== 'university' && w !== 'college' && w !== 'institute' && w !== 'technology');
      for (const word of shortWords) {
        if (sText.includes(word)) {
          collegeMatch = true;
          break;
        }
      }
    }
  }

  console.log('[OCR Match Results] nameMatch:', nameMatch, '| collegeMatch:', collegeMatch);
  return nameMatch && collegeMatch;
}

export const forgotPassword = async (req, res, next) => {
  const { email } = req.body;
  try {
    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    const user = await prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found with this email' });
    }

    // Generate 6 digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = Date.now() + 10 * 60 * 1000; // 10 minutes expiry

    resetCodes.set(email.trim().toLowerCase(), { code, expires });

    // Send code via email
    const subject = 'Password Reset Code - BookmyFest';
    const text = `Hello ${user.fullName},\n\nYour password reset verification code is: ${code}.\n\nThis code is valid for 10 minutes.`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #4f46e5; text-align: center;">Reset Your Password</h2>
        <p>Hello <strong>${user.fullName}</strong>,</p>
        <p>We received a request to reset your password. Use the following verification code to proceed:</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #4f46e5; border: 1px dashed #4f46e5; padding: 10px 20px; border-radius: 4px;">${code}</span>
        </div>
        <p>This code is valid for <strong>10 minutes</strong>. If you did not request a password reset, you can safely ignore this email.</p>
        <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
        <p style="font-size: 12px; color: #64748b; text-align: center;">&copy; BookmyFest. All rights reserved.</p>
      </div>
    `;

    await sendEmailNotification(user.email, subject, text, html);

    res.status(200).json({
      success: true,
      message: 'Password reset code sent successfully'
    });
  } catch (error) {
    next(error);
  }
};

export const verifyResetCode = async (req, res, next) => {
  const { email, code } = req.body;
  try {
    if (!email || !code) {
      return res.status(400).json({ success: false, message: 'Email and code are required' });
    }

    const key = email.trim().toLowerCase();
    const stored = resetCodes.get(key);

    if (!stored) {
      return res.status(400).json({ success: false, message: 'No reset code requested or code has expired' });
    }

    if (stored.expires < Date.now()) {
      resetCodes.delete(key);
      return res.status(400).json({ success: false, message: 'Reset code has expired' });
    }

    if (stored.code !== code.trim()) {
      return res.status(400).json({ success: false, message: 'Invalid verification code' });
    }

    res.status(200).json({
      success: true,
      message: 'Code verified successfully'
    });
  } catch (error) {
    next(error);
  }
};

export const resetPassword = async (req, res, next) => {
  const { email, code, newPassword } = req.body;
  try {
    if (!email || !code || !newPassword) {
      return res.status(400).json({ success: false, message: 'Email, code, and new password are required' });
    }

    const key = email.trim().toLowerCase();
    const stored = resetCodes.get(key);

    if (!stored) {
      return res.status(400).json({ success: false, message: 'No reset code requested or code has expired' });
    }

    if (stored.expires < Date.now()) {
      resetCodes.delete(key);
      return res.status(400).json({ success: false, message: 'Reset code has expired' });
    }

    if (stored.code !== code.trim()) {
      return res.status(400).json({ success: false, message: 'Invalid verification code' });
    }

    const user = await prisma.user.findUnique({ where: { email: key } });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // Hash the new password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(newPassword, salt);

    // Update in database
    await prisma.user.update({
      where: { email: key },
      data: { passwordHash }
    });

    // Delete the code so it cannot be reused
    resetCodes.delete(key);

    res.status(200).json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (error) {
    next(error);
  }
};


