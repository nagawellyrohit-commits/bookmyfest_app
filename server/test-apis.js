import axios from 'axios';

const PORT = 5001;
const API_URL = `http://localhost:${PORT}/api`;

const logSuccess = (msg) => console.log(`\x1b[32m✔ [SUCCESS]: ${msg}\x1b[0m`);
const logFail = (msg, err) => console.error(`\x1b[31m✘ [FAILED]: ${msg}\x1b[0m`, err?.response?.data || err.message);

async function runTests() {
  console.log('--- STARTING COLLEGE_CONNECT API SYSTEM TESTS ---');
  
  const timestamp = Date.now();
  const collegeName = `Tech University ${timestamp}`;
  const studentEmail = `student_${timestamp}@test.com`;
  const coordEmail = `coordinator_${timestamp}@test.com`;
  const facultyEmail = `faculty_${timestamp}@test.com`;
  const superEmail = `super_${timestamp}@test.com`;
  const password = 'Password123';

  let studentToken, coordToken, facultyToken, superToken;
  let studentId, coordId;
  let eventId, regId, attendanceId;

  // 1. Register Student
  try {
    const res = await axios.post(`${API_URL}/auth/register`, {
      fullName: 'John Student',
      email: studentEmail,
      password: password,
      phone: '+919999999991',
      role: 'student',
      collegeName: collegeName,
      department: 'Computer Science',
      idProofUrl: 'http://example.com/student-id.png',
      isFinalYear: true,
      resumeUrl: 'http://example.com/john-resume.pdf'
    });
    studentId = res.data.data.user.id;
    logSuccess('Registered student user');
  } catch (e) {
    return logFail('Student registration', e);
  }

  // 2. Register Coordinator
  try {
    const res = await axios.post(`${API_URL}/auth/register`, {
      fullName: 'Emma Coordinator',
      email: coordEmail,
      password: password,
      phone: '+919999999992',
      role: 'coordinator',
      collegeName: collegeName,
      department: 'Information Technology',
      idProofUrl: 'http://example.com/coord-id.png',
      isFinalYear: false
    });
    coordId = res.data.data.user.id;
    logSuccess('Registered coordinator user (requires verification)');
  } catch (e) {
    return logFail('Coordinator registration', e);
  }

  // 3. Register Faculty Admin
  try {
    const res = await axios.post(`${API_URL}/auth/register`, {
      fullName: 'Dr. Arthur Faculty',
      email: facultyEmail,
      password: password,
      phone: '+919999999993',
      role: 'faculty_admin',
      collegeName: collegeName,
      department: 'Computer Science',
      idProofUrl: 'http://example.com/faculty-id.png',
      isFinalYear: false
    });
    logSuccess('Registered faculty admin user (requires verification)');
  } catch (e) {
    return logFail('Faculty registration', e);
  }

  // 4. Register Super Admin
  try {
    const res = await axios.post(`${API_URL}/auth/register`, {
      fullName: 'Client Owner',
      email: superEmail,
      password: password,
      phone: '+919999999994',
      role: 'super_admin',
      collegeName: 'System Corp',
      department: 'HQ',
      idProofUrl: 'http://example.com/super-id.png',
      isFinalYear: false
    });
    logSuccess('Registered super admin user');
  } catch (e) {
    return logFail('Super admin registration', e);
  }

  // 5. Login Super Admin to approve Faculty and Coordinator
  try {
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: superEmail,
      password: password
    });
    superToken = loginRes.data.data.token;
    logSuccess('Logged in Super Admin');
  } catch (e) {
    return logFail('Super Admin login', e);
  }

  // 6. Super Admin verifies Coordinator directly
  try {
    await axios.post(`${API_URL}/auth/coordinators/${coordId}/verify`, {}, {
      headers: { Authorization: `Bearer ${superToken}` }
    });
    logSuccess('Super Admin verified Coordinator account');
  } catch (e) {
    return logFail('Direct coordinator verification', e);
  }

  // 7. Login Coordinator
  try {
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: coordEmail,
      password: password
    });
    coordToken = loginRes.data.data.token;
    logSuccess('Logged in Coordinator');
  } catch (e) {
    return logFail('Coordinator login', e);
  }

  // 8. Coordinator publishes Event
  let qrCode;
  try {
    const eventRes = await axios.post(`${API_URL}/events`, {
      title: 'Global AI Summit 2026',
      description: 'Annual flagship event exploring Artificial Intelligence, Neural Nets, and Agentic workflows.',
      eventDate: new Date(Date.now() + 7 * 86400 * 1000).toISOString(),
      registrationDeadline: new Date(Date.now() + 5 * 86400 * 1000).toISOString(),
      isPaid: true,
      entryFee: 150.00,
      upiId: 'organizer@paytm'
    }, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    eventId = eventRes.data.data.id;
    qrCode = eventRes.data.data.qrAttendanceCode;
    logSuccess(`Coordinator created Event. ID: ${eventId} | QR Code: ${qrCode}`);
  } catch (e) {
    return logFail('Event creation', e);
  }

  // 9. Login Student
  try {
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: studentEmail,
      password: password
    });
    studentToken = loginRes.data.data.token;
    logSuccess('Logged in Student');
  } catch (e) {
    return logFail('Student login', e);
  }

  // 10. Student registers for Event (Paid, status: pending)
  try {
    const regRes = await axios.post(`${API_URL}/events/${eventId}/register`, {
      registrationType: 'individual',
      paymentReference: 'UPI_REF_987654321'
    }, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    regId = regRes.data.data.id;
    logSuccess(`Student registered for Paid event (pending payment confirmation). Reg ID: ${regId}`);
  } catch (e) {
    return logFail('Event registration', e);
  }

  // 11. Coordinator approves payment (converts registration status: completed)
  try {
    await axios.post(`${API_URL}/events/${eventId}/registrations/${regId}/confirm`, {}, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    logSuccess('Coordinator approved registration payment');
  } catch (e) {
    return logFail('Registration approval', e);
  }

  // 12. Student scans QR code to mark attendance
  try {
    const scanRes = await axios.post(`${API_URL}/events/${eventId}/scan`, {
      qrCode: qrCode
    }, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    attendanceId = scanRes.data.data.id;
    logSuccess('Student scanned QR code and marked attendance');
  } catch (e) {
    return logFail('QR attendance scan', e);
  }

  // 13. Coordinator reviews AI suggestions for certificates
  try {
    const suggestionsRes = await axios.get(`${API_URL}/events/${eventId}/certificates/suggestions`, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    const selectedTemplate = suggestionsRes.data.data[0];
    logSuccess(`Fetched AI suggested templates. Total themes: ${suggestionsRes.data.data.length}. Chosen: "${selectedTemplate.templateName}"`);

    // Approve the template choice
    await axios.post(`${API_URL}/events/${eventId}/certificates/approve`, selectedTemplate, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    logSuccess('Coordinator approved certificate template style');
  } catch (e) {
    return logFail('AI certificate suggestions or approval', e);
  }

  // 14. Student downloads completed certificate (format: HTML)
  try {
    const certRes = await axios.get(`${API_URL}/events/${eventId}/certificates/download?format=html`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    if (certRes.data.includes('Certificate of Participation')) {
      logSuccess('Student certificate HTML pre-render download verified');
    } else {
      throw new Error('HTML response did not contain standard certificate headings');
    }
  } catch (e) {
    return logFail('Certificate download', e);
  }

  // 15. Super Admin audits Job Profiles
  try {
    const profilesRes = await axios.get(`${API_URL}/admin/job-profiles`, {
      headers: { Authorization: `Bearer ${superToken}` }
    });
    const match = profilesRes.data.data.find(p => p.id === studentId);
    if (match && match.jobProfile.resumeUrl === 'http://example.com/john-resume.pdf') {
      logSuccess('Super Admin job profile audit verified (Correct resume link found)');
    } else {
      throw new Error('Student job profile mismatch or missing');
    }
  } catch (e) {
    return logFail('Super Admin job profiles list audit', e);
  }

  console.log('--- ALL COLLEGE_CONNECT BACKEND INTEGRATION TESTS PASSED ---');
}

runTests();
