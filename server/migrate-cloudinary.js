import { PrismaClient } from '@prisma/client';
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();
const uploadsDir = path.join(process.cwd(), 'uploads');

// Ensure uploads folder exists
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Base URL for local server uploads
const BASE_URL = process.env.SERVER_BASE_URL || 'http://38.49.212.126:5001';

async function downloadFile(url) {
  try {
    console.log(`[Download] Fetching: ${url}`);
    const response = await axios.get(url, { responseType: 'arraybuffer' });
    const contentType = response.headers['content-type'] || '';
    
    // Extract base name and clean it
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;
    let baseName = path.basename(pathname);
    
    // Add extension if missing and can be inferred
    if (!path.extname(baseName)) {
      if (contentType.includes('pdf')) {
        baseName += '.pdf';
      } else if (contentType.includes('jpeg') || contentType.includes('jpg')) {
        baseName += '.jpg';
      } else if (contentType.includes('png')) {
        baseName += '.png';
      } else if (contentType.includes('gif')) {
        baseName += '.gif';
      } else if (contentType.includes('webp')) {
        baseName += '.webp';
      }
    }

    // Generate unique suffix
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(baseName);
    const nameWithoutExt = path.basename(baseName, ext);
    const finalFilename = `migrated-${nameWithoutExt}-${uniqueSuffix}${ext}`;
    
    const targetPath = path.join(uploadsDir, finalFilename);
    await fs.promises.writeFile(targetPath, Buffer.from(response.data));
    console.log(`[Saved] Successfully wrote file to: ${targetPath}`);
    
    return `${BASE_URL}/uploads/${finalFilename}`;
  } catch (error) {
    console.error(`[Error] Failed to download file from ${url}:`, error.message);
    return null;
  }
}

async function migrate() {
  console.log('--- Starting Cloudinary Migration ---');
  console.log(`Target Base URL: ${BASE_URL}`);
  
  let successCount = 0;
  let failureCount = 0;

  // Helper to check if URL is a Cloudinary URL
  const isCloudinary = (url) => {
    if (!url) return false;
    return url.includes('cloudinary.com') || url.includes('res.cloudinary.com');
  };

  try {
    // 1. User - idProofUrl
    console.log('\nScanning users...');
    const users = await prisma.user.findMany({
      where: {
        idProofUrl: {
          contains: 'cloudinary',
        },
      },
    });
    console.log(`Found ${users.length} users with Cloudinary idProofUrls.`);
    for (const user of users) {
      if (isCloudinary(user.idProofUrl)) {
        const localUrl = await downloadFile(user.idProofUrl);
        if (localUrl) {
          await prisma.user.update({
            where: { id: user.id },
            data: { idProofUrl: localUrl },
          });
          successCount++;
        } else {
          failureCount++;
        }
      }
    }

    // 2. JobProfile - resumeUrl
    console.log('\nScanning job profiles...');
    const profiles = await prisma.jobProfile.findMany({
      where: {
        resumeUrl: {
          contains: 'cloudinary',
        },
      },
    });
    console.log(`Found ${profiles.length} job profiles with Cloudinary resumeUrls.`);
    for (const profile of profiles) {
      if (isCloudinary(profile.resumeUrl)) {
        const localUrl = await downloadFile(profile.resumeUrl);
        if (localUrl) {
          await prisma.jobProfile.update({
            where: { id: profile.id },
            data: { resumeUrl: localUrl },
          });
          successCount++;
        } else {
          failureCount++;
        }
      }
    }

    // 3. Event - brochureUrl, posterUrl1, posterUrl2, posterUrl3, posterUrl4
    console.log('\nScanning events...');
    const events = await prisma.event.findMany({
      where: {
        OR: [
          { brochureUrl: { contains: 'cloudinary' } },
          { posterUrl1: { contains: 'cloudinary' } },
          { posterUrl2: { contains: 'cloudinary' } },
          { posterUrl3: { contains: 'cloudinary' } },
          { posterUrl4: { contains: 'cloudinary' } },
        ],
      },
    });
    console.log(`Found ${events.length} events with Cloudinary attachments.`);
    for (const event of events) {
      const updates = {};
      
      if (isCloudinary(event.brochureUrl)) {
        const localUrl = await downloadFile(event.brochureUrl);
        if (localUrl) { updates.brochureUrl = localUrl; successCount++; } else { failureCount++; }
      }
      if (isCloudinary(event.posterUrl1)) {
        const localUrl = await downloadFile(event.posterUrl1);
        if (localUrl) { updates.posterUrl1 = localUrl; successCount++; } else { failureCount++; }
      }
      if (isCloudinary(event.posterUrl2)) {
        const localUrl = await downloadFile(event.posterUrl2);
        if (localUrl) { updates.posterUrl2 = localUrl; successCount++; } else { failureCount++; }
      }
      if (isCloudinary(event.posterUrl3)) {
        const localUrl = await downloadFile(event.posterUrl3);
        if (localUrl) { updates.posterUrl3 = localUrl; successCount++; } else { failureCount++; }
      }
      if (isCloudinary(event.posterUrl4)) {
        const localUrl = await downloadFile(event.posterUrl4);
        if (localUrl) { updates.posterUrl4 = localUrl; successCount++; } else { failureCount++; }
      }

      if (Object.keys(updates).length > 0) {
        await prisma.event.update({
          where: { id: event.id },
          data: updates,
        });
      }
    }

    // 4. Sponsor - logoUrl
    console.log('\nScanning sponsors...');
    const sponsors = await prisma.sponsor.findMany({
      where: {
        logoUrl: {
          contains: 'cloudinary',
        },
      },
    });
    console.log(`Found ${sponsors.length} sponsors with Cloudinary logoUrls.`);
    for (const sponsor of sponsors) {
      if (isCloudinary(sponsor.logoUrl)) {
        const localUrl = await downloadFile(sponsor.logoUrl);
        if (localUrl) {
          await prisma.sponsor.update({
            where: { id: sponsor.id },
            data: { logoUrl: localUrl },
          });
          successCount++;
        } else {
          failureCount++;
        }
      }
    }

    console.log('\n--- Migration Summary ---');
    console.log(`Successfully migrated/backed up: ${successCount} files.`);
    console.log(`Failed to migrate: ${failureCount} files.`);
  } catch (error) {
    console.error('Migration crashed:', error);
  } finally {
    await prisma.$disconnect();
  }
}

migrate();
