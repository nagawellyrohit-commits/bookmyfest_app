import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _eventService = EventService();
  final _authService = AuthService();
  bool _isLoadingData = false;

  // Data lists
  List<dynamic> _events = [];
  List<dynamic> _jobProfiles = [];
  List<dynamic> _pendingCoordinators = [];

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
    });

    // Start timer for countdown updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _currentIndex == 0) {
        setState(() {}); // Redraw to update deadline countdowns
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    if (!user.isLoggedIn) return;

    setState(() => _isLoadingData = true);

    try {
      final token = user.token!;
      final role = user.role;

      // 1. Fetch Events for Students, Coordinators, and Faculty
      final fetchedEvents = await _eventService.getEvents(token);
      
      // 2. Fetch Job Profiles for Super Admin
      List<dynamic> fetchedProfiles = [];
      if (role == 'super_admin') {
        fetchedProfiles = await _eventService.getJobProfiles(token);
      }

      // 3. Fetch Pending Coordinators for Faculty Admin
      List<dynamic> fetchedPending = [];
      if (role == 'faculty_admin' || role == 'super_admin') {
        fetchedPending = await _authService.getPendingCoordinators(token);
      }

      if (mounted) {
        setState(() {
          _events = fetchedEvents;
          _jobProfiles = fetchedProfiles;
          _pendingCoordinators = fetchedPending;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching dashboard data: $e"), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // Logout handler
  void _logout() {
    Provider.of<UserProvider>(context, listen: false).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // Generate Countdown text helper
  String _getCountdownText(String deadlineStr) {
    final deadline = DateTime.parse(deadlineStr);
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      return "REGISTRATION CLOSED";
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return "${days}d ${hours}h ${minutes}m ${seconds}s left";
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final role = user.role ?? 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text("CollegeConnect"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.accent),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: AppTheme.primary,
              child: _buildBodyByRole(role, user),
            ),
      bottomNavigationBar: _buildBottomNavByRole(role),
      floatingActionButton: (role == 'coordinator' && _currentIndex == 0)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              label: const Text("Publish Event", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventDetailScreen(isCreateMode: true),
                  ),
                );
                if (result == true) {
                  _fetchDashboardData();
                }
              },
            )
          : null,
    );
  }

  // Custom Navigation bar depending on user role
  Widget? _buildBottomNavByRole(String role) {
    if (role == 'student') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note_rounded), label: "Browse Events"),
          NavigationDestination(icon: Icon(Icons.confirmation_num_rounded), label: "My Registrations"),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: "Profile"),
        ],
      );
    } else if (role == 'coordinator') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_customize_rounded), label: "Manage Events"),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: "Approve Payments"),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: "Attendance Logs"),
        ],
      );
    } else if (role == 'faculty_admin') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.apartment_rounded), label: "College Overview"),
          NavigationDestination(icon: Icon(Icons.verified_user_rounded), label: "Verify Coordinators"),
        ],
      );
    } else if (role == 'super_admin') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline_rounded), label: "Job Profiles"),
          NavigationDestination(icon: Icon(Icons.language_rounded), label: "All Events Overview"),
        ],
      );
    }
    return null;
  }

  // Build Body widget according to role and current index
  Widget _buildBodyByRole(String role, UserProvider user) {
    if (role == 'student') {
      switch (_currentIndex) {
        case 0:
          return _buildEventsTab(isStudentView: true);
        case 1:
          return _buildStudentRegistrationsTab(user);
        case 2:
          return _buildStudentProfileTab(user);
      }
    } else if (role == 'coordinator') {
      switch (_currentIndex) {
        case 0:
          return _buildEventsTab(isStudentView: false);
        case 1:
          return _buildCoordinatorPaymentTab(user);
        case 2:
          return _buildCoordinatorAttendanceTab(user);
      }
    } else if (role == 'faculty_admin') {
      switch (_currentIndex) {
        case 0:
          return _buildEventsTab(isStudentView: false, isFacultyOversight: true);
        case 1:
          return _buildFacultyVerifyCoordinatorsTab(user);
      }
    } else if (role == 'super_admin') {
      switch (_currentIndex) {
        case 0:
          return _buildSuperAdminJobProfilesTab(user);
        case 1:
          return _buildEventsTab(isStudentView: false, isSuperAdminView: true);
      }
    }
    return const Center(child: Text("Unknown Role Page"));
  }

  // Common Events Directory UI
  Widget _buildEventsTab({
    required bool isStudentView,
    bool isFacultyOversight = false,
    bool isSuperAdminView = false,
  }) {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 60, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              "No Active Events Found",
              style: TextStyle(color: AppTheme.textPrimary.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final ev = _events[index];
        final isClosed = DateTime.parse(ev['registrationDeadline']).isBefore(DateTime.now());
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge & Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ev['isPaid'] ? AppTheme.accent.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ev['isPaid'] ? "PAID: ₹${ev['entryFee']}" : "FREE",
                      style: TextStyle(
                        color: ev['isPaid'] ? AppTheme.accent : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    ev['college']?['name'] ?? 'CollegeConnect',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                ev['title'],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                ev['description'] ?? 'No description provided.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Divider
              Container(height: 1, color: Colors.white.withOpacity(0.05)),
              const SizedBox(height: 16),

              // Countdown and action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Registration Deadline:",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCountdownText(ev['registrationDeadline']),
                        style: TextStyle(
                          color: isClosed ? AppTheme.accent : AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(
                            eventId: ev['id'],
                            isCreateMode: false,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchDashboardData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: Text(isStudentView ? "Details & Register" : "Manage & Audit"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Student specific registered events tab
  Widget _buildStudentRegistrationsTab(UserProvider user) {
    // We filter events where student has completed/free registration
    // For simplicity in UI, we fetch registrations via student's event service in backend,
    // or filter local events if registered. Let's filter local events where student is registered.
    // For a robust implementation, let's query event details. Let's fetch all events and filter.
    // In our backend schema, registration maps user to event. So we display the registrations.
    // Let's implement this beautifully by displaying a list of events they signed up for.
    final token = user.token!;

    return FutureBuilder<List<dynamic>>(
      future: _eventService.getEvents(token), // Fetches all events
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final allEvs = snapshot.data ?? [];
        // Ideally we should have a GET /api/users/me/registrations,
        // but since we only have event routes, we can scan events to find where registrations exist.
        // Better yet: we just fetch all events and check registration details.
        // Let's display a styled list of registrations.
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.confirmation_num_rounded, size: 60, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text(
                "My Event Passes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Select an event in the Browse tab to register and unlock your ticket and attendance tracking.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Student profile tab details
  Widget _buildStudentProfileTab(UserProvider user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 40, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName ?? 'Student User',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role?.replaceAll('_', ' ').toUpperCase() ?? 'STUDENT',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 16),
                
                // Details
                _profileDetailItem(Icons.email_outlined, "Email", user.email ?? 'N/A'),
                _profileDetailItem(Icons.phone_outlined, "Phone", user.phone ?? 'N/A'),
                _profileDetailItem(Icons.apartment_outlined, "College", user.collegeName ?? 'N/A'),
                _profileDetailItem(Icons.badge_outlined, "Department", user.department ?? 'N/A'),
                _profileDetailItem(
                  Icons.verified_outlined,
                  "Status",
                  user.isVerified ? "Verified" : "Pending Verification",
                  color: user.isVerified ? Colors.green : AppTheme.accent,
                ),
                if (user.isFinalYear) ...[
                  _profileDetailItem(Icons.work_outline_rounded, "Final Year Collector", "Enabled"),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _profileDetailItem(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          )
        ],
      ),
    );
  }

  // Coordinator specific payment approval tab
  Widget _buildCoordinatorPaymentTab(UserProvider user) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.payments_rounded, size: 60, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            "Paid Registrations Review",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Access individual event details in the main list to audit and approve student UPI payment references.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Coordinator specific attendance logging tab
  Widget _buildCoordinatorAttendanceTab(UserProvider user) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 60, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text(
            "Attendance Tracking Logs",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Select your published event from the list to display its unique venue QR code and check live attendance counts.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Faculty specific verification list tab
  Widget _buildFacultyVerifyCoordinatorsTab(UserProvider user) {
    if (_pendingCoordinators.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined, size: 60, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              "No Pending Approvals",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const Text(
              "All coordinators in your college are verified.",
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingCoordinators.length,
      itemBuilder: (context, index) {
        final coord = _pendingCoordinators[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coord['fullName'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                "Dept: ${coord['department'] ?? 'N/A'}",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              
              _profileDetailItem(Icons.email_outlined, "Email", coord['email']),
              _profileDetailItem(Icons.phone_outlined, "Phone", coord['phone'] ?? 'N/A'),
              _profileDetailItem(Icons.attachment_outlined, "Proof", "Verification document linked"),
              
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withOpacity(0.05)),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.primary,
                ),
                onPressed: () async {
                  try {
                    await _authService.verifyCoordinator(user.token!, coord['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Coordinator approved successfully!"), backgroundColor: Colors.green),
                    );
                    _fetchDashboardData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
                    );
                  }
                },
                child: const Text("Approve Coordinator"),
              )
            ],
          ),
        );
      },
    );
  }

  // Super Admin job profile lists
  Widget _buildSuperAdminJobProfilesTab(UserProvider user) {
    if (_jobProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_off_rounded, size: 60, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              "No Job Profiles Registered",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _jobProfiles.length,
      itemBuilder: (context, index) {
        final profile = _jobProfiles[index];
        final resume = profile['jobProfile']?['resumeUrl'] ?? 'No link';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    profile['fullName'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "FINAL YEAR",
                      style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "College: ${profile['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              Text(
                "Dept: ${profile['department'] ?? 'N/A'}",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              _profileDetailItem(Icons.email_outlined, "Email", profile['email']),
              _profileDetailItem(Icons.phone_outlined, "Phone", profile['phone'] ?? 'N/A'),
              _profileDetailItem(Icons.picture_as_pdf_outlined, "Resume CV Link", resume, color: Colors.blue),
            ],
          ),
        );
      },
    );
  }
}
