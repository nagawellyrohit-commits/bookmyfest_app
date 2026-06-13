import prisma from './src/config/db.js';

async function diagnoseDatabase() {
  console.log('\n--- COLLEGE_CONNECT DATABASE DIAGNOSTIC TOOL ---');
  console.log('Connecting to database...');

  try {
    // 1. Test basic connection
    await prisma.$connect();
    console.log('\x1b[32m✔ Connection: SUCCESS (PostgreSQL is running and accessible)\x1b[0m');

    // 2. Query stats from key tables
    console.log('\nChecking table counts...');
    try {
      const collegeCount = await prisma.college.count();
      console.log(`- Colleges: ${collegeCount}`);
    } catch (e) {
      console.log('\x1b[31m✘ Table Error: Could not query "colleges" table.\x1b[0m');
      throw e;
    }

    try {
      const userCount = await prisma.user.count();
      console.log(`- Registered Users: ${userCount}`);
    } catch (e) {
      console.log('\x1b[31m✘ Table Error: Could not query "users" table.\x1b[0m');
      throw e;
    }

    try {
      const eventCount = await prisma.event.count();
      console.log(`- Published Events: ${eventCount}`);
    } catch (e) {
      console.log('\x1b[31m✘ Table Error: Could not query "events" table.\x1b[0m');
      throw e;
    }

    try {
      const logCount = await prisma.auditLog.count();
      console.log(`- Audit Logs recorded: ${logCount}`);
    } catch (e) {
      console.log('\x1b[31m✘ Table Error: Could not query "audit_logs" table.\x1b[0m');
      throw e;
    }

    console.log('\n\x1b[32m✔ DATABASE HEALTH: EXCELLENT (All standard models are queryable!)\x1b[0m\n');

  } catch (error) {
    console.log('\n\x1b[31m✘ DIAGNOSIS: DATABASE ERROR FOUND\x1b[0m');
    console.error('Error Details:', error.message);

    console.log('\n=========================================');
    console.log('      FUTURE TROUBLESHOOTING GUIDE       ');
    console.log('=========================================');
    
    if (error.message.includes('Can\'t reach database server')) {
      console.log('\n[1] CONNECTION REFUSED');
      console.log('Reason: The PostgreSQL service is stopped or port 5432 is blocked.');
      console.log('How to fix (macOS):');
      console.log('  -> Run: brew services start postgresql');
      console.log('  -> Or make sure pgAdmin / Postgres.app is running.');
    } 
    else if (error.message.includes('relation') && error.message.includes('does not exist')) {
      console.log('\n[2] MISSING DB TABLES / OUT-OF-SYNC');
      console.log('Reason: Database exists, but the migrations haven\'t been applied.');
      console.log('How to fix:');
      console.log('  -> Run: npx prisma migrate dev');
    } 
    else if (error.message.includes('Authentication failed') || error.message.includes('password authentication failed')) {
      console.log('\n[3] INVALID DB CREDENTIALS');
      console.log('Reason: DATABASE_URL in server/.env has wrong user, password, or DB name.');
      console.log('How to fix:');
      console.log('  -> Check server/.env line 2');
      console.log('  -> Verify the role "rohit" exists or change to: postgresql://postgres:password@localhost:5432/collegeconnect');
    } 
    else {
      console.log('\n[4] SYSTEM SYNC REQUIRED');
      console.log('How to reset / regenerate Client:');
      console.log('  -> Run: npx prisma generate');
      console.log('  -> Run: npx prisma migrate reset (Warning: This wipes and recreates db tables)');
    }
    console.log('=========================================\n');
  } finally {
    await prisma.$disconnect();
  }
}

diagnoseDatabase();
