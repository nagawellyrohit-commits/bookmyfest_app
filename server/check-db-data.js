import prisma from './src/config/db.js';

async function checkData() {
  try {
    const users = await prisma.user.findMany({
      include: {
        jobProfile: true
      }
    });

    console.log('\n--- ALL USERS AND JOB PROFILES ---');
    users.forEach(u => {
      console.log(`User: ${u.fullName} (${u.email}) [Role: ${u.role}]`);
      if (u.jobProfile) {
        console.log(`  -> Job Profile: Branch=${u.jobProfile.branch}, PassingYear=${u.jobProfile.passingYear}`);
        console.log(`  -> Resume URL: "${u.jobProfile.resumeUrl}"`);
      } else {
        console.log('  -> No Job Profile record found.');
      }
      console.log('-----------------------------------');
    });

  } catch (err) {
    console.error('Error checking db data:', err);
  } finally {
    await prisma.$disconnect();
  }
}

checkData();
