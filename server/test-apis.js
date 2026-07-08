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
  let studentId, coordId, facultyId;
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
    facultyId = res.data.data.user.id;
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

  // 6. Super Admin verifies Faculty directly
  try {
    await axios.post(`${API_URL}/auth/faculties/${facultyId}/verify`, {}, {
      headers: { Authorization: `Bearer ${superToken}` }
    });
    logSuccess('Super Admin verified Faculty account');
  } catch (e) {
    return logFail('Direct faculty verification', e);
  }

  // 6b. Login Faculty Admin
  try {
    const loginRes = await axios.post(`${API_URL}/auth/login`, {
      email: facultyEmail,
      password: password
    });
    facultyToken = loginRes.data.data.token;
    logSuccess('Logged in Faculty Admin');
  } catch (e) {
    return logFail('Faculty Admin login', e);
  }

  // 6c. Faculty Admin verifies Coordinator directly
  try {
    await axios.post(`${API_URL}/auth/coordinators/${coordId}/verify`, {}, {
      headers: { Authorization: `Bearer ${facultyToken}` }
    });
    logSuccess('Faculty Admin verified Coordinator account');
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

  // 8b. Faculty Admin approves the created event
  try {
    await axios.post(`${API_URL}/events/${eventId}/approve-update`, {}, {
      headers: { Authorization: `Bearer ${facultyToken}` }
    });
    logSuccess('Faculty Admin approved the Event');
  } catch (e) {
    return logFail('Event approval', e);
  }

  // 8c. Coordinator edits the approved event (proposes a title change)
  try {
    const updateRes = await axios.put(`${API_URL}/events/${eventId}`, {
      title: 'Global AI Summit 2026 - Modified Title'
    }, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    if (updateRes.data.data.pendingUpdates && updateRes.data.data.pendingUpdates.title === 'Global AI Summit 2026 - Modified Title') {
      logSuccess('Coordinator proposed event edit (stored in pendingUpdates)');
    } else {
      throw new Error('Proposed edit was not saved to pendingUpdates correctly');
    }
  } catch (e) {
    return logFail('Coordinator event edit proposal', e);
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

  // 9b. Student fetches event and verifies the old title is still shown (edit is pending)
  try {
    const eventRes = await axios.get(`${API_URL}/events/${eventId}`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    if (eventRes.data.data.title === 'Global AI Summit 2026') {
      logSuccess('Verified: Student still sees the old title (pending edit is hidden)');
    } else {
      throw new Error(`Student saw the unapproved title: ${eventRes.data.data.title}`);
    }
  } catch (e) {
    return logFail('Verify pending edit hidden from student', e);
  }

  // 9c. Faculty Admin approves the pending updates
  try {
    await axios.post(`${API_URL}/events/${eventId}/approve-update`, {}, {
      headers: { Authorization: `Bearer ${facultyToken}` }
    });
    logSuccess('Faculty Admin approved the pending event edits');
  } catch (e) {
    return logFail('Faculty Admin approve pending updates', e);
  }

  // 9d. Student fetches event again and verifies the new title is now visible
  try {
    const eventRes = await axios.get(`${API_URL}/events/${eventId}`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    if (eventRes.data.data.title === 'Global AI Summit 2026 - Modified Title') {
      logSuccess('Verified: Student now sees the approved modified title');
    } else {
      throw new Error(`Student did not see the approved title: ${eventRes.data.data.title}`);
    }
  } catch (e) {
    return logFail('Verify approved edit visible to student', e);
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

  // 10b. Verify pending-payments endpoint returns this registration
  try {
    const pendingRes = await axios.get(`${API_URL}/events/pending-payments`, {
      headers: { Authorization: `Bearer ${coordToken}` }
    });
    const match = pendingRes.data.data.find(r => r.id === regId);
    if (match && match.paymentReference === 'UPI_REF_987654321') {
      logSuccess('Verified /pending-payments endpoint returns the correct pending registration');
    } else {
      throw new Error('Pending registration not found in pending-payments list');
    }
  } catch (e) {
    return logFail('Pending payments list verification', e);
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

  // 15b. Register Student without a phone number (should succeed)
  try {
    const res = await axios.post(`${API_URL}/auth/register`, {
      fullName: 'No Phone Student',
      email: `nophone_${timestamp}@test.com`,
      password: password,
      role: 'student',
      collegeName: collegeName,
      department: 'Computer Science',
      idProofUrl: 'http://example.com/student-id.png',
      isFinalYear: false
    });
    logSuccess('Registered student without phone number (succeeded)');
  } catch (e) {
    return logFail('Registration without phone number', e);
  }

  // 15c. Student deletes their own account directly
  try {
    await axios.delete(`${API_URL}/auth/me`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    logSuccess('Student deleted their own account directly via DELETE /auth/me');
    
    // Verify login fails now
    try {
      await axios.post(`${API_URL}/auth/login`, {
        email: studentEmail,
        password: password
      });
      throw new Error('Login succeeded for deleted user');
    } catch (loginErr) {
      if (loginErr.response?.status === 401 || loginErr.response?.status === 400) {
        logSuccess('Verified: Login correctly failed for deleted user');
      } else {
        throw loginErr;
      }
    }
  } catch (e) {
    return logFail('Self-deletion of account', e);
  }

  console.log('--- ALL COLLEGE_CONNECT BACKEND INTEGRATION TESTS PASSED ---');
}

runTests();
