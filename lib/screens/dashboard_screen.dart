import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import 'event_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';
import 'sponsor_management_screen.dart';

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
  List<dynamic> _pendingPayments = [];
  List<dynamic> _allStudents = [];
  List<dynamic> _allFaculties = [];
  List<dynamic> _allCoordinators = [];

  // Inline action tracking for quick/instant feedback
  final Set<String> _approvedIds = {};
  final Set<String> _processingIds = {};

  // Search and Filters
  String _searchQuery = "";
  String? _selectedCollegeFilter;
  String? _selectedCategoryFilter;

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

  Future<void> _fetchDashboardData({bool silent = false}) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    if (!user.isLoggedIn) return;

    if (!silent) {
      setState(() => _isLoadingData = true);
    }

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
      List<dynamic> fetchedAllStudents = [];
      List<dynamic> fetchedAllFaculties = [];
      List<dynamic> fetchedAllCoordinators = [];
      if (role == 'super_admin') {
        fetchedProfiles = await _eventService.getAllJobProfiles(token);
        fetchedAllStudents = await _eventService.getAllStudents(token);
        fetchedAllFaculties = await _eventService.getAllFaculties(token);
        fetchedAllCoordinators = await _eventService.getAllCoordinators(token);
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

      // 5. Fetch Pending Payments for Coordinators
      List<dynamic> fetchedPendingPayments = [];
      if (role == 'coordinator') {
        fetchedPendingPayments = await _eventService.getPendingPayments(token);
      }

      if (mounted) {
        setState(() {
          _events = fetchedEvents;
          _jobProfiles = fetchedProfiles;
          _pendingCoordinators = fetchedPending;
          _pendingEventApprovals = fetchedEventApprovals;
          _pendingPayments = fetchedPendingPayments;
          _allStudents = fetchedAllStudents;
          _allFaculties = fetchedAllFaculties;
          _allCoordinators = fetchedAllCoordinators;
          _processingIds.clear();
          _approvedIds.clear();
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
      if (mounted && !silent) setState(() => _isLoadingData = false);
    }
  }

  // Logout handler
  void _logout() {
    Provider.of<UserProvider>(context, listen: false).logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
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

  String _formatEventDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec"
      ];
      return "${months[dt.month - 1]} ${dt.day}";
    } catch (_) {
      return "TBD";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final role = user.role ?? 'student';
    final isUnverified =
        (role == 'faculty_admin' || role == 'coordinator') && !user.isVerified;

    // Clamping index to prevent out-of-bounds errors on role transitions/hot-reload
    final expectedLength = role == 'super_admin' ? 5 : (role == 'guest' ? 2 : 3);
    if (_currentIndex >= expectedLength) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "bookmyfest",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (role == 'super_admin')
            IconButton(
              icon: const Icon(
                Icons.business_rounded,
                color: Colors.white,
              ),
              tooltip: "Manage Sponsors",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SponsorManagementScreen(),
                  ),
                );
              },
            ),
          if (role == 'coordinator')
            IconButton(
              icon: const Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white,
              ),
              tooltip: "Account Settings",
              onPressed: () => _showCoordinatorSettings(context, user),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgorund.png',
              fit: BoxFit.cover,
            ),
          ),
          // Content layer
          Positioned.fill(
            child: isUnverified
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
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
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
          ),
        ],
      ),
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

  void _changeTab(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _fetchDashboardData(silent: true);
  }

  Widget _buildEmptyStatePlaceholder({
    required IconData icon,
    required String message,
    String? description,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 60,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Custom Navigation bar depending on user role
  Widget? _buildBottomNavByRole(String role) {
    if (role == 'student') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
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
        onDestinationSelected: _changeTab,
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
        onDestinationSelected: _changeTab,
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
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: "Students",
          ),
          NavigationDestination(
            icon: Icon(Icons.group_work_outlined),
            label: "Coordinators",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_pin_outlined),
            label: "Faculty",
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            label: "Events",
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            label: "Job Profiles",
          ),
        ],
      );
    } else if (role == 'guest') {
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_rounded),
            label: "Browse Events",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: "Profile",
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
          return _buildSuperAdminStudentsTab(user);
        case 1:
          return _buildSuperAdminCoordinatorsTab(user);
        case 2:
          return _buildSuperAdminFacultiesTab(user);
        case 3:
          return _buildEventsTab(isStudentView: false, isSuperAdminView: true);
        case 4:
          return _buildSuperAdminJobProfilesTab(user);
      }
    } else if (role == 'guest') {
      switch (_currentIndex) {
        case 0:
          return _buildEventsTab(isStudentView: true);
        case 1:
          return _buildStudentProfileTab(user);
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
    final role = Provider.of<UserProvider>(context, listen: false).role;
    final colleges = _events
        .map((e) => e['college']?['name']?.toString())
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final categories = _events
        .map((e) => e['category']?.toString())
        .where((cat) => cat != null && cat.isNotEmpty)
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
      if (_selectedCategoryFilter != null &&
          ev['category'] != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    if (_events.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.calendar_today_rounded,
        message: "No Active Events Found",
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
                    isExpanded: true,
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
                    isExpanded: true,
                    initialValue: _selectedCategoryFilter,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                    decoration:
                        AppTheme.inputDecoration(
                          labelText: "Event",
                          prefixIcon: Icons.category_outlined,
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
                          "All Events",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCategoryFilter = val),
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

                    final String imageUrl = (() {
                      final url = ev['posterUrl1'];
                      if (url != null && url.toString().isNotEmpty) {
                        return url.toString();
                      }
                      return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800';
                    })();

                    final category = ev['category']?.toString() ?? 'General';
                    final title = ev['title']?.toString() ?? 'Event';
                    final college = ev['college']?['name']?.toString() ?? 'Campus';
                    final eventDateStr = ev['eventDate'] != null ? _formatEventDate(ev['eventDate'].toString()) : 'TBD';
                    final isPaid = ev['isPaid'] ?? false;
                    final entryFeeDouble = double.tryParse(ev['entryFee']?.toString() ?? '') ?? 0.0;

                    return GestureDetector(
                      onTap: () async {
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
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Image Section with Category Badge and Favorite Button
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Image.network(
                                        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                // Category Badge (floating top-left)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                // Favorite Button or Pending Approval Badge
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: ev['isApproved'] == false
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.hourglass_empty_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Pending Approval",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const IconButton(
                                            icon: Icon(
                                              Icons.favorite_border_rounded,
                                              color: Color(0xFF64748B),
                                              size: 20,
                                            ),
                                            onPressed: null,
                                          ),
                                        ),
                                  ),
                              ],
                            ),
                            // Details Section
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Location & Date Row
                                  Row(
                                    children: [
                                      // Location
                                      const Icon(
                                        Icons.location_on_outlined,
                                        color: Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          college,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Date
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        color: Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        eventDateStr,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Countdown / Registrations Status
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people_outline_rounded,
                                        color: Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${ev['_count']?['registrations'] ?? 0} registered",
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.hourglass_empty_rounded,
                                        color: Color(0xFF64748B),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _getCountdownText(ev['registrationDeadline']),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isClosed ? AppTheme.accent : AppTheme.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Bottom Row with Price and Book Now button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Price
                                      Text(
                                        isPaid ? "₹${entryFeeDouble.toStringAsFixed(0)}" : "Free",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: isPaid ? AppTheme.accent : const Color(0xFF10B981),
                                        ),
                                      ),
                                      // Book Now / Register button
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
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          isStudentView
                                              ? (role == 'guest' ? "View Details" : "Book Now")
                                              : "Manage & Audit",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
      return _buildEmptyStatePlaceholder(
        icon: Icons.confirmation_num_rounded,
        message: "My Event Passes",
        description: "Select an event in the Browse tab to register and unlock your ticket and attendance tracking.",
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
                if (user.role == 'guest') ...[
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
                    Icons.family_restroom_rounded,
                    "Parent of Student?",
                    user.isParent ? "Yes" : "No",
                    color: user.isParent ? Colors.green : Colors.grey,
                  ),
                  if (user.isParent) ...[
                    _profileDetailItem(
                      Icons.person_outline,
                      "Student Name",
                      user.parentStudentName ?? 'N/A',
                    ),
                    _profileDetailItem(
                      Icons.apartment_outlined,
                      "Student College",
                      user.parentStudentCollege ?? 'N/A',
                    ),
                  ],
                ] else ...[
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
                ],
                const SizedBox(height: 24),
                if (user.role != 'guest')
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
    VoidCallback? onTap,
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
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Coordinator specific payment approval tab
  Widget _buildCoordinatorPaymentTab(UserProvider user) {
    if (_pendingPayments.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.payments_rounded,
        message: "No Pending Payments",
        description: "All payments for your college events have been verified and confirmed.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingPayments.length,
      itemBuilder: (context, index) {
        final reg = _pendingPayments[index];
        final eventTitle = reg['event']?['title'] ?? 'Unknown Event';
        final studentName = reg['user']?['fullName'] ?? 'Unknown Student';
        final paymentRef = reg['paymentReference'] ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Event: $eventTitle",
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (reg['user']?['phone'] != null)
                      Text(
                        "Phone: ${reg['user']['phone']}",
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      "UPI Reference: $paymentRef",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              (() {
                final String regId = reg['id'];
                final bool isApproved = _approvedIds.contains(regId);
                final bool isProcessing = _processingIds.contains(regId);

                if (isApproved) {
                  return const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 4),
                      Text(
                        "Approved",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                } else if (isProcessing) {
                  return const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  );
                } else {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () async {
                      setState(() {
                        _processingIds.add(regId);
                      });
                      try {
                        await _eventService.confirmPayment(
                          user.token!,
                          reg['eventId'],
                          regId,
                        );
                        if (mounted) {
                          setState(() {
                            _processingIds.remove(regId);
                            _approvedIds.add(regId);
                          });
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text("Payment confirmed successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        _fetchDashboardData(silent: true);
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _processingIds.remove(regId);
                          });
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text("Approve"),
                  );
                }
              })(),
            ],
          ),
        );
      },
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
      return _buildEmptyStatePlaceholder(
        icon: Icons.verified_user_outlined,
        message: "No Pending Approvals",
        description: "All coordinators in your college are verified.",
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

              (() {
                final String coordId = coord['id'];
                final bool isApproved = _approvedIds.contains(coordId);
                final bool isProcessing = _processingIds.contains(coordId);

                if (isApproved) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isDeletionPending ? "Deletion Approved" : "Approved",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (isProcessing) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            setState(() {
                              _processingIds.add(coordId);
                            });
                            try {
                              await _authService.verifyCoordinator(
                                user.token!,
                                coordId,
                              );
                              if (mounted) {
                                setState(() {
                                  _processingIds.remove(coordId);
                                  _approvedIds.add(coordId);
                                });
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
                              }
                              _fetchDashboardData(silent: true);
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _processingIds.remove(coordId);
                                });
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
                            if (confirm == true && mounted) {
                              setState(() {
                                _processingIds.add(coordId);
                              });
                              try {
                                await _authService.deleteCoordinator(
                                  user.token!,
                                  coordId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(coordId);
                                    _approvedIds.add(coordId);
                                  });
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
                                }
                                _fetchDashboardData(silent: true);
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(coordId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                }
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
                  );
                }
              })(),
            ],
          ),
        );
      },
    );
  }

  // Super Admin view ALL job profiles (regardless of passing/final year status)
  Widget _buildSuperAdminJobProfilesTab(UserProvider user) {
    if (_jobProfiles.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.work_off_rounded,
        message: "No Job Profiles Registered",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _jobProfiles.length,
      itemBuilder: (context, index) {
        final jp = _jobProfiles[index];
        final student = jp['user'] ?? {};
        final resume = jp['resumeUrl'] ?? 'No link';
        final branch = jp['branch'] ?? 'N/A';
        final passingYear = jp['passingYear']?.toString() ?? 'N/A';
        final businessName = jp['businessName'];
        final description = jp['description'];
        final contactPhone = jp['contactPhone'];
        final websiteUrl = jp['websiteUrl'];
        final instagramUrl = jp['instagramUrl'];
        final linkedinUrl = jp['linkedinUrl'];

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
                      student['fullName'] ?? 'Unknown Student',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (student['isFinalYear'] == true)
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
                "College: ${student['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                "Dept: ${student['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              _profileDetailItem(
                Icons.email_outlined,
                "Email",
                student['email'] ?? 'N/A',
              ),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                student['phone'] ?? 'N/A',
              ),
              _profileDetailItem(
                Icons.school_outlined,
                "Branch / Field",
                branch,
              ),
              _profileDetailItem(
                Icons.calendar_today_outlined,
                "Passing Out Year",
                passingYear,
              ),

              const SizedBox(height: 8),
              const Text(
                "Startup / Company Info",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              _profileDetailItem(
                Icons.business_center_outlined,
                "Company Name",
                (businessName != null && businessName.toString().trim().isNotEmpty)
                    ? businessName.toString().trim()
                    : 'N/A',
              ),
              _profileDetailItem(
                Icons.description_outlined,
                "Description",
                (description != null && description.toString().trim().isNotEmpty)
                    ? description.toString().trim()
                    : 'N/A',
              ),
              _profileDetailItem(
                Icons.phone_android_outlined,
                "Business Phone",
                (contactPhone != null && contactPhone.toString().trim().isNotEmpty)
                    ? contactPhone.toString().trim()
                    : 'N/A',
              ),

              const SizedBox(height: 8),
              const Text(
                "Professional Links",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              _profileDetailItem(
                Icons.web_outlined,
                "Website",
                (websiteUrl != null && websiteUrl.toString().trim().isNotEmpty)
                    ? websiteUrl.toString().trim()
                    : 'N/A',
                color: (websiteUrl != null && websiteUrl.toString().trim().isNotEmpty)
                    ? Colors.blue
                    : AppTheme.textSecondary,
                onTap: (websiteUrl != null && websiteUrl.toString().trim().isNotEmpty)
                    ? () async {
                        final url = Uri.parse(websiteUrl.toString().trim());
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    : null,
              ),
              _profileDetailItem(
                Icons.camera_alt_outlined,
                "Instagram",
                (instagramUrl != null && instagramUrl.toString().trim().isNotEmpty)
                    ? instagramUrl.toString().trim()
                    : 'N/A',
                color: (instagramUrl != null && instagramUrl.toString().trim().isNotEmpty)
                    ? Colors.pinkAccent
                    : AppTheme.textSecondary,
                onTap: (instagramUrl != null && instagramUrl.toString().trim().isNotEmpty)
                    ? () async {
                        final url = Uri.parse(instagramUrl.toString().trim());
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    : null,
              ),
              _profileDetailItem(
                Icons.link_outlined,
                "LinkedIn",
                (linkedinUrl != null && linkedinUrl.toString().trim().isNotEmpty)
                    ? linkedinUrl.toString().trim()
                    : 'N/A',
                color: (linkedinUrl != null && linkedinUrl.toString().trim().isNotEmpty)
                    ? Colors.blueAccent
                    : AppTheme.textSecondary,
                onTap: (linkedinUrl != null && linkedinUrl.toString().trim().isNotEmpty)
                    ? () async {
                        final url = Uri.parse(linkedinUrl.toString().trim());
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    : null,
              ),

              const SizedBox(height: 8),
              _profileDetailItem(
                Icons.picture_as_pdf_outlined,
                "Resume CV PDF",
                resume != 'No link' && resume != 'No resume link provided'
                    ? "Click to view PDF CV"
                    : "No resume uploaded",
                color:
                    resume != 'No link' && resume != 'No resume link provided'
                    ? Colors.blue
                    : AppTheme.textSecondary,
                onTap:
                    resume != 'No link' && resume != 'No resume link provided'
                    ? () async {
                        final url = Uri.parse(resume);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    : null,
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
      return _buildEmptyStatePlaceholder(
        icon: Icons.pending_actions_outlined,
        message: "No Pending Event Approvals",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingEventApprovals.length,
      itemBuilder: (_, index) {
        final ev = _pendingEventApprovals[index];
        final isDeletion = ev['isPendingDeletion'] == true;
        final isNewCreation = ev['isApproved'] == false;
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
                          : (isNewCreation
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDeletion 
                          ? "PENDING DELETE" 
                          : (isNewCreation ? "PENDING CREATION" : "PENDING UPDATE"),
                      style: TextStyle(
                        color: isDeletion 
                            ? Colors.red 
                            : (isNewCreation ? Colors.blue : Colors.orange),
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
              const SizedBox(height: 16),
              _buildApprovalForm(ev, updates),
              const SizedBox(height: 16),
              (() {
                final String evId = ev['id'];
                final bool isApproved = _approvedIds.contains(evId);
                final bool isProcessing = _processingIds.contains(evId);

                if (isApproved) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isDeletion 
                                ? "Deletion Approved" 
                                : (isNewCreation ? "Creation Approved" : "Updates Approved"),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (isProcessing) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            setState(() {
                              _processingIds.add(evId);
                            });
                            try {
                              if (isDeletion) {
                                await _eventService.approveEventDelete(
                                  user.token!,
                                  evId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(evId);
                                    _approvedIds.add(evId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Event deletion approved!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                await _eventService.approveEventUpdate(
                                  user.token!,
                                  evId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(evId);
                                    _approvedIds.add(evId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isNewCreation
                                            ? "Event creation approved!"
                                            : "Event updates approved!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                              _fetchDashboardData(silent: true);
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _processingIds.remove(evId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: AppTheme.accent,
                                  ),
                                );
                              }
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
                            setState(() {
                              _processingIds.add(evId);
                            });
                            try {
                              if (isDeletion) {
                                await _eventService.rejectEventDelete(
                                  user.token!,
                                  evId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(evId);
                                    _approvedIds.add(evId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Event deletion request rejected!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                await _eventService.rejectEventUpdate(
                                  user.token!,
                                  evId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _processingIds.remove(evId);
                                    _approvedIds.add(evId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isNewCreation
                                            ? "Event creation request rejected!"
                                            : "Event updates rejected!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                              _fetchDashboardData(silent: true);
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _processingIds.remove(evId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: AppTheme.accent,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text("Reject"),
                        ),
                      ),
                    ],
                  );
                }
              })(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalField({
    required String label,
    required IconData icon,
    required String originalValue,
    required String? proposedValue,
  }) {
    final hasEdits = proposedValue != null && proposedValue != originalValue;
    final displayValue = hasEdits ? proposedValue : originalValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: hasEdits ? AppTheme.accent : AppTheme.textSecondary,
            fontWeight: hasEdits ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: hasEdits ? AppTheme.accent : AppTheme.primary,
            size: 18,
          ),
          suffixIcon: hasEdits
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "(edited)",
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: hasEdits 
              ? AppTheme.accent.withValues(alpha: 0.02) 
              : Colors.grey.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasEdits ? AppTheme.accent : const Color(0xFFE2E8F0),
              width: hasEdits ? 1.5 : 1.0,
            ),
          ),
        ),
        child: Text(
          displayValue.isEmpty ? "N/A" : displayValue,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: hasEdits ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalForm(Map<String, dynamic> ev, Map<String, dynamic>? updates) {
    final originalEventDate = ev['eventDate'] != null 
        ? DateTime.parse(ev['eventDate'].toString()).toLocal().toString().substring(0, 16) 
        : 'N/A';
    final proposedEventDate = updates?['eventDate'] != null 
        ? DateTime.parse(updates!['eventDate'].toString()).toLocal().toString().substring(0, 16) 
        : null;

    final originalDeadline = ev['registrationDeadline'] != null 
        ? DateTime.parse(ev['registrationDeadline'].toString()).toLocal().toString().substring(0, 16) 
        : 'N/A';
    final proposedDeadline = updates?['registrationDeadline'] != null 
        ? DateTime.parse(updates!['registrationDeadline'].toString()).toLocal().toString().substring(0, 16) 
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildApprovalField(
          label: "Event Title",
          icon: Icons.title,
          originalValue: ev['title']?.toString() ?? '',
          proposedValue: updates?['title']?.toString(),
        ),
        _buildApprovalField(
          label: "Description",
          icon: Icons.description_outlined,
          originalValue: ev['description']?.toString() ?? '',
          proposedValue: updates?['description']?.toString(),
        ),
        _buildApprovalField(
          label: "Branch Focus",
          icon: Icons.school_outlined,
          originalValue: ev['branch']?.toString() ?? 'Open',
          proposedValue: updates?['branch']?.toString(),
        ),
        _buildApprovalField(
          label: "Event Category",
          icon: Icons.category_outlined,
          originalValue: ev['category']?.toString() ?? 'Other',
          proposedValue: updates?['category']?.toString(),
        ),
        _buildApprovalField(
          label: "WhatsApp Group Link",
          icon: Icons.chat_bubble_outline,
          originalValue: ev['whatsAppGroupLink']?.toString() ?? '',
          proposedValue: updates?['whatsAppGroupLink']?.toString(),
        ),
        _buildApprovalField(
          label: "Brochure PDF URL",
          icon: Icons.picture_as_pdf_outlined,
          originalValue: ev['brochureUrl']?.toString() ?? '',
          proposedValue: updates?['brochureUrl']?.toString(),
        ),
        _buildApprovalField(
          label: "Brochure Page Count",
          icon: Icons.pages_outlined,
          originalValue: ev['brochurePages']?.toString() ?? '0',
          proposedValue: updates?['brochurePages']?.toString(),
        ),
        _buildApprovalField(
          label: "Event Type",
          icon: Icons.group_work_outlined,
          originalValue: ev['eventType']?.toString().toUpperCase() ?? 'INDIVIDUAL',
          proposedValue: updates?['eventType']?.toString().toUpperCase(),
        ),
        if (ev['eventType'] == 'group' || ev['eventType'] == 'both' || updates?['eventType'] == 'group' || updates?['eventType'] == 'both') ...[
          _buildApprovalField(
            label: "Min Members",
            icon: Icons.person_outline,
            originalValue: ev['minMembers']?.toString() ?? '1',
            proposedValue: updates?['minMembers']?.toString(),
          ),
          _buildApprovalField(
            label: "Max Members",
            icon: Icons.groups_outlined,
            originalValue: ev['maxMembers']?.toString() ?? '1',
            proposedValue: updates?['maxMembers']?.toString(),
          ),
        ],
        _buildApprovalField(
          label: "Event Date",
          icon: Icons.calendar_today,
          originalValue: originalEventDate,
          proposedValue: proposedEventDate,
        ),
        _buildApprovalField(
          label: "Registration Deadline",
          icon: Icons.hourglass_empty,
          originalValue: originalDeadline,
          proposedValue: proposedDeadline,
        ),
        _buildApprovalField(
          label: "Payment Status",
          icon: Icons.currency_rupee,
          originalValue: ev['isPaid'] == true ? 'Paid' : 'Free',
          proposedValue: updates?['isPaid'] != null ? (updates!['isPaid'] == true ? 'Paid' : 'Free') : null,
        ),
        if (ev['isPaid'] == true || updates?['isPaid'] == true) ...[
          _buildApprovalField(
            label: "Entry Fee",
            icon: Icons.attach_money,
            originalValue: ev['entryFee']?.toString() ?? '0.00',
            proposedValue: updates?['entryFee']?.toString(),
          ),
          _buildApprovalField(
            label: "UPI ID",
            icon: Icons.qr_code,
            originalValue: ev['upiId']?.toString() ?? '',
            proposedValue: updates?['upiId']?.toString(),
          ),
        ],
        _buildApprovalField(
          label: "Poster URL 1",
          icon: Icons.image_outlined,
          originalValue: ev['posterUrl1']?.toString() ?? '',
          proposedValue: updates?['posterUrl1']?.toString(),
        ),
      ],
    );
  }

  // Super Admin view all student accounts
  Widget _buildSuperAdminStudentsTab(UserProvider user) {
    if (_allStudents.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.people_outline,
        message: "No Students Registered",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allStudents.length,
      itemBuilder: (context, index) {
        final student = _allStudents[index];
        final isVerified =
            student['isVerified'] ?? student['is_verified'] ?? false;
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
                      student['fullName'] ?? 'Unknown Student',
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
                      color: isVerified
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVerified ? "VERIFIED" : "PENDING",
                      style: TextStyle(
                        color: isVerified ? Colors.green : Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "College: ${student['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                "Dept: ${student['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _profileDetailItem(
                Icons.email_outlined,
                "Email",
                student['email'],
              ),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                student['phone'] ?? 'N/A',
              ),
              if (student['studentId'] != null)
                _profileDetailItem(
                  Icons.card_membership,
                  "Student ID",
                  student['studentId'],
                ),
            ],
          ),
        );
      },
    );
  }

  // Super Admin view all coordinator accounts
  Widget _buildSuperAdminCoordinatorsTab(UserProvider user) {
    if (_allCoordinators.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.group_work_outlined,
        message: "No Coordinators Registered",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allCoordinators.length,
      itemBuilder: (context, index) {
        final coordinator = _allCoordinators[index];
        final isVerified =
            coordinator['isVerified'] ?? coordinator['is_verified'] ?? false;
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
                      coordinator['fullName'] ?? 'Unknown Coordinator',
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
                      color: isVerified
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVerified ? "VERIFIED" : "PENDING",
                      style: TextStyle(
                        color: isVerified ? Colors.green : Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "College: ${coordinator['college']?['name'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                "Dept: ${coordinator['department'] ?? 'N/A'}",
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _profileDetailItem(
                Icons.email_outlined,
                "Email",
                coordinator['email'],
              ),
              _profileDetailItem(
                Icons.phone_outlined,
                "Phone",
                coordinator['phone'] ?? 'N/A',
              ),
            ],
          ),
        );
      },
    );
  }

  // Super Admin view all faculty accounts
  Widget _buildSuperAdminFacultiesTab(UserProvider user) {
    if (_allFaculties.isEmpty) {
      return _buildEmptyStatePlaceholder(
        icon: Icons.person_pin_outlined,
        message: "No Faculty Registered",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allFaculties.length,
      itemBuilder: (context, index) {
        final faculty = _allFaculties[index];
        final isVerified =
            faculty['isVerified'] ?? faculty['is_verified'] ?? false;
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
                      faculty['fullName'] ?? 'Unknown Faculty',
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
                      color: isVerified
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isVerified ? "VERIFIED" : "PENDING",
                      style: TextStyle(
                        color: isVerified ? Colors.green : Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
              if (!isVerified) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(45),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _authService.verifyFaculty(
                        user.token!,
                        faculty['id'],
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Faculty Admin approved successfully!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchDashboardData();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
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
            ],
          ),
        );
      },
    );
  }
}
