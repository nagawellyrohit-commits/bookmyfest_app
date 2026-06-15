import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

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
  List<dynamic> _pendingEventApprovals = [];
  List<dynamic> _pendingFaculties = [];

  // Search and Filters
  String _searchQuery = "";
  String? _selectedCollegeFilter;
  String? _selectedBranchFilter;

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

      // 0. Fetch latest user profile to ensure account still exists and sync state
      try {
        final freshUser = await _authService.getMe(token);
        freshUser['college'] = {"name": user.collegeName};
        user.setSession(token, freshUser);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains("404") ||
            errStr.contains("401") ||
            errStr.contains("not found")) {
          _logout();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Your account has been deleted or is no longer active.",
                ),
                backgroundColor: AppTheme.accent,
              ),
            );
          }
          return;
        }
        rethrow;
      }

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

      // 4. Fetch Pending Event Approvals for Faculty Admin
      List<dynamic> fetchedEventApprovals = [];
      if (role == 'faculty_admin' || role == 'super_admin') {
        fetchedEventApprovals = await _eventService.getPendingEventApprovals(
          token,
        );
      }

      // 5. Fetch Pending Faculty Admins for Super Admin
      List<dynamic> fetchedFaculties = [];
      if (role == 'super_admin') {
        fetchedFaculties = await _authService.getPendingFaculties(token);
      }

      if (mounted) {
        setState(() {
          _events = fetchedEvents;
          _jobProfiles = fetchedProfiles;
          _pendingCoordinators = fetchedPending;
          _pendingEventApprovals = fetchedEventApprovals;
          _pendingFaculties = fetchedFaculties;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching dashboard data: $e"),
            backgroundColor: AppTheme.accent,
          ),
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

  void _showCoordinatorSettings(BuildContext context, UserProvider user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Account Settings",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Name: ${user.fullName}",
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              "Email: ${user.email}",
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              "Role: Coordinator",
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            if (user.isPendingDeletion)
              const Text(
                "Your account deletion request has been submitted and is pending Faculty Coordinator approval. You will remain active until approved.",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                "Warning: Requesting account deletion requires approval from your college's Faculty Coordinator. You will remain active until approved.",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          if (!user.isPendingDeletion)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () async {
                Navigator.pop(context); // close dialog
                setState(() => _isLoadingData = true);
                try {
                  await _authService.deleteCoordinator(
                    user.token!,
                    user.userId!,
                  );

                  // Reload the profile data to update user.isPendingDeletion
                  final freshProfile = await _authService.getMe(user.token!);
                  freshProfile['college'] = {"name": user.collegeName};
                  user.setSession(user.token!, freshProfile);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Account deletion request submitted. Pending Faculty Admin approval.",
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                } finally {
                  setState(() => _isLoadingData = false);
                }
              },
              child: const Text(
                "Delete Account",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
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
    final isUnverified =
        (role == 'faculty_admin' || role == 'coordinator') && !user.isVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CollegeConnect"),
        actions: [
          if (role == 'coordinator')
            IconButton(
              icon: const Icon(
                Icons.manage_accounts_rounded,
                color: AppTheme.accent,
              ),
              tooltip: "Account Settings",
              onPressed: () => _showCoordinatorSettings(context, user),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.accent),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: isUnverified
          ? Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      size: 80,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Verification Pending",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      role == 'faculty_admin'
                          ? "Your Faculty Admin account is pending approval from the Super Admin. You will gain access to verify coordinators and manage events once approved."
                          : "Your Coordinator account is pending approval from the Faculty Admin. You will gain access once approved.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _fetchDashboardData,
                      child: const Text("Check Verification Status"),
                    ),
                  ],
                ),
              ),
            )
          : (_isLoadingData
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : Column(
                    children: [
                      if (role == 'coordinator' && user.isPendingDeletion)
                        Container(
                          color: AppTheme.accent.withValues(alpha: 0.9),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Your request to delete this account is pending Faculty Coordinator approval. You will remain active until approved.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchDashboardData,
                          color: AppTheme.primary,
                          child: _buildBodyByRole(role, user),
                        ),
                      ),
                    ],
                  )),
      bottomNavigationBar: isUnverified ? null : _buildBottomNavByRole(role),
      floatingActionButton: (role == 'coordinator' && _currentIndex == 0)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              label: const Text(
                "Publish Event",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EventDetailScreen(isCreateMode: true),
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
          NavigationDestination(
            icon: Icon(Icons.event_note_rounded),
            label: "Browse Events",
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_num_rounded),
            label: "My Registrations",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: "Profile",
          ),
        ],
      );
    } else if (role == 'coordinator') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: "Manage Events",
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: "Approve Payments",
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: "Attendance Logs",
          ),
        ],
      );
    } else if (role == 'faculty_admin') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apartment_rounded),
            label: "College Overview",
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_rounded),
            label: "Verify Coordinators",
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions_rounded),
            label: "Event Approvals",
          ),
        ],
      );
    } else if (role == 'super_admin') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            label: "Job Profiles",
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_rounded),
            label: "Verify Faculty",
          ),
          NavigationDestination(
            icon: Icon(Icons.language_rounded),
            label: "All Events Overview",
          ),
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
          return _buildEventsTab(
            isStudentView: false,
            isFacultyOversight: true,
          );
        case 1:
          return _buildFacultyVerifyCoordinatorsTab(user);
        case 2:
          return _buildFacultyPendingEventApprovalsTab(user);
      }
    } else if (role == 'super_admin') {
      switch (_currentIndex) {
        case 0:
          return _buildSuperAdminJobProfilesTab(user);
        case 1:
          return _buildSuperAdminVerifyFacultiesTab(user);
        case 2:
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
    final colleges = _events
        .map((e) => e['college']?['name']?.toString())
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final branches = _events
        .map((e) => e['branch']?.toString())
        .where((branch) => branch != null && branch.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final filteredEvents = _events.where((ev) {
      final title = (ev['title'] ?? '').toString().toLowerCase();
      final desc = (ev['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty && !title.contains(query) && !desc.contains(query)) {
        return false;
      }
      if (_selectedCollegeFilter != null &&
          ev['college']?['name'] != _selectedCollegeFilter) {
        return false;
      }
      if (_selectedBranchFilter != null &&
          ev['branch'] != _selectedBranchFilter) {
        return false;
      }
      return true;
    }).toList();

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              "No Active Events Found",
              style: TextStyle(
                color: AppTheme.textPrimary.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (isStudentView) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: AppTheme.inputDecoration(
                labelText: "Search Events by Title / Desc",
                prefixIcon: Icons.search,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCollegeFilter,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                    decoration:
                        AppTheme.inputDecoration(
                          labelText: "College",
                          prefixIcon: Icons.apartment_outlined,
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          "All Colleges",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...colleges.map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCollegeFilter = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBranchFilter,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                    decoration:
                        AppTheme.inputDecoration(
                          labelText: "Branch",
                          prefixIcon: Icons.school_outlined,
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          "All Branches",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...branches.map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(b, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedBranchFilter = val),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: filteredEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 60,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No Events Match Your Search",
                        style: TextStyle(
                          color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final ev = filteredEvents[index];
                    final isClosed = DateTime.parse(
                      ev['registrationDeadline'],
                    ).isBefore(DateTime.now());

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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ev['isPaid']
                                      ? AppTheme.accent.withValues(alpha: 0.15)
                                      : AppTheme.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ev['isPaid']
                                      ? "PAID: ₹${ev['entryFee']}"
                                      : "FREE",
                                  style: TextStyle(
                                    color: ev['isPaid']
                                        ? AppTheme.accent
                                        : AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (ev['branch'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ev['branch'],
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    ev['college']?['name'] ?? 'CollegeConnect',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            ev['title'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          Text(
                            ev['description'] ?? 'No description provided.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
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
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getCountdownText(
                                      ev['registrationDeadline'],
                                    ),
                                    style: TextStyle(
                                      color: isClosed
                                          ? AppTheme.accent
                                          : AppTheme.primary,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: Text(
                                  isStudentView
                                      ? "Details & Register"
                                      : "Manage & Audit",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Student specific registered events tab
  Widget _buildStudentRegistrationsTab(UserProvider user) {
    final registeredEvents = _events.where((ev) {
      return ev['registrations'] != null &&
          (ev['registrations'] as List).isNotEmpty;
    }).toList();

    if (registeredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.confirmation_num_rounded,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "My Event Passes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
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
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: registeredEvents.length,
      itemBuilder: (context, index) {
        final ev = registeredEvents[index];
        final myReg = ev['registrations'][0];
        final isVerifiedPass =
            myReg['paymentStatus'] == 'free_event' ||
            myReg['paymentStatus'] == 'completed';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isVerifiedPass
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isVerifiedPass ? "CONFIRMED" : "PENDING",
                      style: TextStyle(
                        color: isVerifiedPass ? Colors.green : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    ev['college']?['name'] ?? '',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ev['title'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Pass ID: ${myReg['id']}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(
                        eventId: ev['id'],
                        isCreateMode: false,
                      ),
                    ),
                  );
                  _fetchDashboardData();
                },
                child: const Text("View Ticket Pass & QR Code"),
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
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName ?? 'Student User',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role?.replaceAll('_', ' ').toUpperCase() ?? 'STUDENT',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 16),

                // Details
                _profileDetailItem(
                  Icons.email_outlined,
                  "Email",
                  user.email ?? 'N/A',
                ),
                _profileDetailItem(
                  Icons.phone_outlined,
                  "Phone",
                  user.phone ?? 'N/A',
                ),
                _profileDetailItem(
                  Icons.apartment_outlined,
                  "College",
                  user.collegeName ?? 'N/A',
                ),
                _profileDetailItem(
                  Icons.badge_outlined,
                  "Department",
                  user.department ?? 'N/A',
                ),
                _profileDetailItem(
                  Icons.verified_outlined,
                  "Status",
                  user.isVerified ? "Verified" : "Pending Verification",
                  color: user.isVerified ? Colors.green : AppTheme.accent,
                ),
                if (user.isFinalYear) ...[
                  _profileDetailItem(
                    Icons.work_outline_rounded,
                    "Final Year Collector",
                    "Enabled",
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  label: const Text(
                    "Edit Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                    if (updated == true) {
                      _fetchDashboardData();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDetailItem(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
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
          ),
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
          const Icon(
            Icons.payments_rounded,
            size: 60,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            "Paid Registrations Review",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
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
          const Icon(
            Icons.qr_code_2_rounded,
            size: 60,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            "Attendance Tracking Logs",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
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
            const Icon(
              Icons.verified_user_outlined,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Pending Approvals",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
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
      itemBuilder: (_, index) {
        final coord = _pendingCoordinators[index];
        final isDeletionPending = coord['isPendingDeletion'] == true;

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
                  Expanded(
                    child: Text(
                      coord['fullName'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isDeletionPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        "PENDING DELETION",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (coord['isVerified'] == false)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        "PENDING VERIFICATION",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Dept: ${coord['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              _profileDetailItem(Icons.email_outlined, "Email", coord['email']),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                coord['phone'] ?? 'N/A',
              ),
              _profileDetailItem(
                Icons.attachment_outlined,
                "Proof",
                "Verification document linked",
              ),

              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        try {
                          await _authService.verifyCoordinator(
                            user.token!,
                            coord['id'],
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isDeletionPending
                                    ? "Coordinator deletion request rejected. Coordinator kept active."
                                    : "Coordinator approved successfully!",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _fetchDashboardData();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      },
                      child: Text(
                        isDeletionPending ? "Keep Coordinator" : "Approve",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              isDeletionPending
                                  ? "Confirm Account Deletion"
                                  : "Reject/Delete Coordinator",
                            ),
                            content: Text(
                              isDeletionPending
                                  ? "Are you sure you want to permanently delete this coordinator account? This action cannot be undone."
                                  : "Are you sure you want to delete and reject this coordinator registration?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  isDeletionPending
                                      ? "Delete Account"
                                      : "Delete",
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await _authService.deleteCoordinator(
                              user.token!,
                              coord['id'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isDeletionPending
                                      ? "Coordinator account permanently deleted!"
                                      : "Coordinator deleted successfully!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchDashboardData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: AppTheme.accent,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        isDeletionPending
                            ? "Approve Deletion"
                            : "Reject/Delete",
                      ),
                    ),
                  ),
                ],
              ),
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
            const Icon(
              Icons.work_off_rounded,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Job Profiles Registered",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "FINAL YEAR",
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "College: ${profile['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                "Dept: ${profile['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              _profileDetailItem(
                Icons.email_outlined,
                "Email",
                profile['email'],
              ),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                profile['phone'] ?? 'N/A',
              ),
              _profileDetailItem(
                Icons.picture_as_pdf_outlined,
                "Resume CV Link",
                resume,
                color: Colors.blue,
              ),
            ],
          ),
        );
      },
    );
  }

  // Faculty tab for approving coordinator event updates and deletions
  Widget _buildFacultyPendingEventApprovalsTab(UserProvider user) {
    if (_pendingEventApprovals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pending_actions_outlined,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Pending Event Approvals",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingEventApprovals.length,
      itemBuilder: (_, index) {
        final ev = _pendingEventApprovals[index];
        final isDeletion = ev['isPendingDeletion'] == true;
        final Map<String, dynamic>? updates = ev['pendingUpdates'] != null
            ? Map<String, dynamic>.from(ev['pendingUpdates'])
            : null;

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
                  Expanded(
                    child: Text(
                      ev['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDeletion
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDeletion ? "PENDING DELETE" : "PENDING UPDATE",
                      style: TextStyle(
                        color: isDeletion ? Colors.red : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Created by: ${ev['creator']?['fullName'] ?? 'Coordinator'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (updates != null) ...[
                const SizedBox(height: 8),
                const Text(
                  "Proposed Changes:",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...updates.entries.map<Widget>((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      "- ${entry.key}: ${entry.value}",
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        try {
                          if (isDeletion) {
                            await _eventService.approveEventDelete(
                              user.token!,
                              ev['id'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Event deletion approved!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            await _eventService.approveEventUpdate(
                              user.token!,
                              ev['id'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Event updates approved!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          _fetchDashboardData();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      },
                      child: const Text("Approve"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        try {
                          if (isDeletion) {
                            await _eventService.rejectEventDelete(
                              user.token!,
                              ev['id'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Event deletion request rejected!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            await _eventService.rejectEventUpdate(
                              user.token!,
                              ev['id'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Event updates rejected!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          _fetchDashboardData();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      },
                      child: const Text("Reject"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Super Admin view to approve pending Faculty Admin accounts
  Widget _buildSuperAdminVerifyFacultiesTab(UserProvider user) {
    if (_pendingFaculties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 60,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              "No Pending Faculty Approvals",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingFaculties.length,
      itemBuilder: (_, index) {
        final faculty = _pendingFaculties[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                faculty['fullName'] ?? 'Unknown Faculty',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "College: ${faculty['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                "Dept: ${faculty['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _profileDetailItem(
                Icons.email_outlined,
                "Email",
                faculty['email'],
              ),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                faculty['phone'] ?? 'N/A',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.primary,
                ),
                onPressed: () async {
                  try {
                    await _authService.verifyFaculty(
                      user.token!,
                      faculty['id'],
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Faculty Admin approved successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchDashboardData();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                },
                child: const Text("Approve Faculty Admin"),
              ),
            ],
          ),
        );
      },
    );
  }
}
