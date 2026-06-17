import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';
import 'qr_scanner_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String? eventId;
  final bool isCreateMode;

  const EventDetailScreen({
    super.key,
    this.eventId,
    required this.isCreateMode,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  final _eventService = EventService();
  bool _isLoading = false;
  Map<String, dynamic>? _event;

  // Tabs for Coordinator View
  TabController? _tabController;

  // Creation Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _feeController = TextEditingController();
  final _upiController = TextEditingController();
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  DateTime _deadline = DateTime.now().add(const Duration(days: 5));
  bool _isPaid = false;

  // New Event Fields
  final _branchController = TextEditingController(text: "Open");
  final _brochureUrlController = TextEditingController();
  final _brochurePagesController = TextEditingController(text: "0");
  final _posterUrl1Controller = TextEditingController();
  final _posterUrl2Controller = TextEditingController();
  final _posterUrl3Controller = TextEditingController();
  final _posterUrl4Controller = TextEditingController();
  final _whatsAppGroupLinkController = TextEditingController();
  String _eventType = "individual";
  final _minMembersController = TextEditingController(text: "1");
  final _maxMembersController = TextEditingController(text: "1");
  bool _isEditing = false;

  // Student Registration Controllers
  final _payRefController = TextEditingController();
  final _groupSizeController = TextEditingController(text: "1");
  String _regType = 'individual';

  // Live countdown timer
  Timer? _ticker;

  // Coordinator Lists
  List<dynamic> _registrations = [];
  List<dynamic> _attendance = [];
  List<dynamic> _aiTemplates = [];
  Map<String, dynamic>? _approvedTemplate;

  @override
  void initState() {
    super.initState();
    if (!widget.isCreateMode) {
      _fetchDetails();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController?.dispose();
    _titleController.dispose();
    _descController.dispose();
    _feeController.dispose();
    _upiController.dispose();
    _branchController.dispose();
    _brochureUrlController.dispose();
    _brochurePagesController.dispose();
    _posterUrl1Controller.dispose();
    _posterUrl2Controller.dispose();
    _posterUrl3Controller.dispose();
    _posterUrl4Controller.dispose();
    _whatsAppGroupLinkController.dispose();
    _minMembersController.dispose();
    _maxMembersController.dispose();
    _payRefController.dispose();
    _groupSizeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    if (widget.eventId == null) return;

    setState(() => _isLoading = true);
    try {
      final token = user.token!;
      final data = await _eventService.getEventDetails(token, widget.eventId!);

      // Load coordinator details if applicable
      if (user.role == 'coordinator' ||
          user.role == 'faculty_admin' ||
          user.role == 'super_admin') {
        _registrations = await _eventService.getEventRegistrations(
          token,
          widget.eventId!,
        );
        _attendance = await _eventService.getEventAttendance(
          token,
          widget.eventId!,
        );

        try {
          _aiTemplates = await _eventService.getCertificateSuggestions(
            token,
            widget.eventId!,
          );
        } catch (_) {
          // Fallback handled gracefully by service
        }

        _tabController ??= TabController(length: 4, vsync: this);
      }

      setState(() {
        _event = data;
        _approvedTemplate = data['certificateTemplate'];
        if (!widget.isCreateMode) {
          _titleController.text = data['title'] ?? '';
          _descController.text = data['description'] ?? '';
          _isPaid = data['isPaid'] ?? false;
          _feeController.text = (data['entryFee'] ?? 0.00).toString();
          _upiController.text = data['upiId'] ?? '';
          _eventDate = DateTime.parse(data['eventDate']);
          _deadline = DateTime.parse(data['registrationDeadline']);
          _branchController.text = data['branch'] ?? 'Open';
          _brochureUrlController.text = data['brochureUrl'] ?? '';
          _brochurePagesController.text = (data['brochurePages'] ?? 0)
              .toString();
          _posterUrl1Controller.text = data['posterUrl1'] ?? '';
          _posterUrl2Controller.text = data['posterUrl2'] ?? '';
          _posterUrl3Controller.text = data['posterUrl3'] ?? '';
          _posterUrl4Controller.text = data['posterUrl4'] ?? '';
          _whatsAppGroupLinkController.text = data['whatsAppGroupLink'] ?? '';
          _eventType = data['eventType'] ?? 'individual';
          _minMembersController.text = (data['minMembers'] ?? 1).toString();
          _maxMembersController.text = (data['maxMembers'] ?? 1).toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Live Timer text
  String _getCountdown() {
    if (_event == null) return "";
    final dl = DateTime.parse(_event!['registrationDeadline']);
    final diff = dl.difference(DateTime.now());
    if (diff.isNegative) return "REGISTRATION CLOSED";
    return "${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s left";
  }

  void _updateEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final brochurePages = int.tryParse(_brochurePagesController.text) ?? 0;
    if (brochurePages > 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Brochure page count cannot exceed 150 pages"),
        ),
      );
      return;
    }

    final minMembers = int.tryParse(_minMembersController.text) ?? 1;
    final maxMembers = int.tryParse(_maxMembersController.text) ?? 1;
    if (_eventType == 'group' || _eventType == 'both') {
      if (minMembers < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Minimum members must be at least 1")),
        );
        return;
      }
      if (maxMembers < minMembers) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Maximum members must be greater than or equal to minimum members",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final payload = {
        "title": _titleController.text.trim(),
        "description": _descController.text.trim(),
        "eventDate": _eventDate.toIso8601String(),
        "registrationDeadline": _deadline.toIso8601String(),
        "isPaid": _isPaid,
        "entryFee": _isPaid
            ? double.tryParse(_feeController.text) ?? 0.00
            : 0.00,
        "upiId": _isPaid ? _upiController.text.trim() : null,
        "branch": _branchController.text.trim().isEmpty
            ? "Open"
            : _branchController.text.trim(),
        "brochureUrl": _brochureUrlController.text.trim().isEmpty
            ? null
            : _brochureUrlController.text.trim(),
        "brochurePages": brochurePages,
        "posterUrl1": _posterUrl1Controller.text.trim().isEmpty
            ? null
            : _posterUrl1Controller.text.trim(),
        "posterUrl2": _posterUrl2Controller.text.trim().isEmpty
            ? null
            : _posterUrl2Controller.text.trim(),
        "posterUrl3": _posterUrl3Controller.text.trim().isEmpty
            ? null
            : _posterUrl3Controller.text.trim(),
        "posterUrl4": _posterUrl4Controller.text.trim().isEmpty
            ? null
            : _posterUrl4Controller.text.trim(),
        "whatsAppGroupLink": _whatsAppGroupLinkController.text.trim().isEmpty
            ? null
            : _whatsAppGroupLinkController.text.trim(),
        "eventType": _eventType,
        "minMembers": _eventType == 'individual' ? 1 : minMembers,
        "maxMembers": _eventType == 'individual' ? 1 : maxMembers,
      };

      await _eventService.updateEvent(user.token!, _event!['id'], payload);
      setState(() {
        _isEditing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.role == 'coordinator'
                ? "Event updates submitted and pending Faculty Admin approval"
                : "Event updated successfully!",
          ),
          backgroundColor: Colors.green,
        ),
      );
      _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteEvent() async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event"),
        content: const Text("Are you sure you want to delete this event?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _eventService.deleteEvent(user.token!, _event!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.role == 'coordinator'
                  ? "Event deletion request submitted and pending Faculty Admin approval"
                  : "Event deleted successfully!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Create Event Action
  void _createEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }

    final brochurePages = int.tryParse(_brochurePagesController.text) ?? 0;
    if (brochurePages > 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Brochure page count cannot exceed 150 pages"),
        ),
      );
      return;
    }

    final minMembers = int.tryParse(_minMembersController.text) ?? 1;
    final maxMembers = int.tryParse(_maxMembersController.text) ?? 1;
    if (_eventType == 'group' || _eventType == 'both') {
      if (minMembers < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Minimum members must be at least 1")),
        );
        return;
      }
      if (maxMembers < minMembers) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Maximum members must be greater than or equal to minimum members",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      final payload = {
        "title": _titleController.text.trim(),
        "description": _descController.text.trim(),
        "eventDate": _eventDate.toIso8601String(),
        "registrationDeadline": _deadline.toIso8601String(),
        "isPaid": _isPaid,
        "entryFee": _isPaid
            ? double.tryParse(_feeController.text) ?? 0.00
            : 0.00,
        "upiId": _isPaid ? _upiController.text.trim() : null,
        "branch": _branchController.text.trim().isEmpty
            ? "Open"
            : _branchController.text.trim(),
        "brochureUrl": _brochureUrlController.text.trim().isEmpty
            ? null
            : _brochureUrlController.text.trim(),
        "brochurePages": brochurePages,
        "posterUrl1": _posterUrl1Controller.text.trim().isEmpty
            ? null
            : _posterUrl1Controller.text.trim(),
        "posterUrl2": _posterUrl2Controller.text.trim().isEmpty
            ? null
            : _posterUrl2Controller.text.trim(),
        "posterUrl3": _posterUrl3Controller.text.trim().isEmpty
            ? null
            : _posterUrl3Controller.text.trim(),
        "posterUrl4": _posterUrl4Controller.text.trim().isEmpty
            ? null
            : _posterUrl4Controller.text.trim(),
        "whatsAppGroupLink": _whatsAppGroupLinkController.text.trim().isEmpty
            ? null
            : _whatsAppGroupLinkController.text.trim(),
        "eventType": _eventType,
        "minMembers": _eventType == 'individual' ? 1 : minMembers,
        "maxMembers": _eventType == 'individual' ? 1 : maxMembers,
      };

      await _eventService.createEvent(user.token!, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Event published successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Register Action
  void _registerForEvent() async {
    if (_event == null) return;
    if (_event!['isPaid'] && _payRefController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter UPI reference transaction ID"),
        ),
      );
      return;
    }

    int? groupSize;
    if (_regType == 'group') {
      groupSize = int.tryParse(_groupSizeController.text);
      if (groupSize == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid group size")),
        );
        return;
      }
      final minSize = _event!['minMembers'] ?? 1;
      final maxSize = _event!['maxMembers'] ?? 1;
      if (groupSize < minSize || groupSize > maxSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Group size must be between $minSize and $maxSize"),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      await _eventService.registerForEvent(
        user.token!,
        _event!['id'],
        registrationType: _regType,
        paymentReference: _event!['isPaid']
            ? _payRefController.text.trim()
            : null,
        groupSize: groupSize,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration submitted!"),
          backgroundColor: Colors.green,
        ),
      );
      _fetchDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.accent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    final isCoordinator =
        user.role == 'coordinator' ||
        user.role == 'faculty_admin' ||
        user.role == 'super_admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCreateMode
              ? "Publish New Event"
              : (_event?['title'] ?? "Loading..."),
        ),
        actions: [
          if (!widget.isCreateMode &&
              _event != null &&
              isCoordinator &&
              !_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: "Edit Event",
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.white),
              tooltip: "Delete Event",
              onPressed: _deleteEvent,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgorund.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : widget.isCreateMode
                    ? _buildEventForm(isEditMode: false)
                    : _isEditing
                        ? _buildEventForm(isEditMode: true)
                        : _buildEventDetails(user),
          ),
        ],
      ),
    );
  }

  Widget _buildEventForm({required bool isEditMode}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditMode ? "Edit Event Details" : "Event Details",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Event Title",
                    prefixIcon: Icons.title,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Description",
                    prefixIcon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _branchController,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Branch Focus (e.g. CSE, ECE, Open)",
                    prefixIcon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _whatsAppGroupLinkController,
                  decoration: AppTheme.inputDecoration(
                    labelText: "WhatsApp Group Link",
                    prefixIcon: Icons.chat_bubble_outline,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _brochureUrlController,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Brochure PDF URL",
                    prefixIcon: Icons.picture_as_pdf_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _brochurePagesController,
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Brochure Page Count (Max 150)",
                    prefixIcon: Icons.pages_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _eventType,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: AppTheme.inputDecoration(
                    labelText: "Event Type",
                    prefixIcon: Icons.group_work_outlined,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'individual',
                      child: Text("Individual Entry Only"),
                    ),
                    DropdownMenuItem(
                      value: 'group',
                      child: Text("Group Entry Only"),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text("Individual or Group Entry"),
                    ),
                  ],
                  onChanged: (val) => setState(() => _eventType = val!),
                ),
                if (_eventType == 'group' || _eventType == 'both') ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minMembersController,
                          keyboardType: TextInputType.number,
                          decoration: AppTheme.inputDecoration(
                            labelText: "Min Members",
                            prefixIcon: Icons.person_outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _maxMembersController,
                          keyboardType: TextInputType.number,
                          decoration: AppTheme.inputDecoration(
                            labelText: "Max Members",
                            prefixIcon: Icons.groups_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  "Poster URLs (Up to 4)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _posterUrl1Controller,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Poster URL 1",
                    prefixIcon: Icons.image_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _posterUrl2Controller,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Poster URL 2",
                    prefixIcon: Icons.image_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _posterUrl3Controller,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Poster URL 3",
                    prefixIcon: Icons.image_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _posterUrl4Controller,
                  decoration: AppTheme.inputDecoration(
                    labelText: "Poster URL 4",
                    prefixIcon: Icons.image_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // Date Selectors
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppTheme.primary,
                  ),
                  title: const Text("Event Date & Time"),
                  subtitle: Text(
                    _eventDate.toLocal().toString().substring(0, 16),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _eventDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(
                          () => _eventDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _eventDate.hour,
                            _eventDate.minute,
                          ),
                        );
                      }
                    },
                    child: const Text("Select"),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.accent,
                  ),
                  title: const Text("Registration Deadline"),
                  subtitle: Text(
                    _deadline.toLocal().toString().substring(0, 16),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _deadline,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: _eventDate,
                      );
                      if (date != null) {
                        setState(
                          () => _deadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _deadline.hour,
                            _deadline.minute,
                          ),
                        );
                      }
                    },
                    child: const Text("Select"),
                  ),
                ),
                const SizedBox(height: 10),

                // Free vs Paid Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Is this a Paid Event?",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _isPaid,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (val) => setState(() => _isPaid = val),
                    ),
                  ],
                ),
                if (_isPaid) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    decoration: AppTheme.inputDecoration(
                      labelText: "Entry Fee (INR)",
                      prefixIcon: Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _upiController,
                    decoration: AppTheme.inputDecoration(
                      labelText: "Organizer UPI ID",
                      prefixIcon: Icons.qr_code,
                    ),
                  ),
                ],
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isEditMode ? _updateEvent : _createEvent,
                        child: Text(
                          isEditMode ? "Save Changes" : "Publish Event",
                        ),
                      ),
                    ),
                    if (isEditMode) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                          ),
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text("Cancel"),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. View Mode Layout
  Widget _buildEventDetails(UserProvider user) {
    if (_event == null) {
      return const Center(child: Text("Event details unavailable."));
    }

    // If Coordinator or Admin, show tabs
    final isCoordinator =
        user.role == 'coordinator' ||
        user.role == 'faculty_admin' ||
        user.role == 'super_admin';

    if (isCoordinator && _tabController != null) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: "Details"),
              Tab(text: "Passes & Payments"),
              Tab(text: "Attendance Log"),
              Tab(text: "AI Certificate Theme"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildInfoCard(user),
                ),
                _buildPassesTab(user),
                _buildAttendanceTab(user),
                _buildAiTemplatesTab(user),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildInfoCard(user),
    );
  }

  // Standard details card (Students & general details)
  Widget _buildInfoCard(UserProvider user) {
    final ev = _event!;
    final dl = DateTime.parse(ev['registrationDeadline']);
    final isClosed = dl.isBefore(DateTime.now());

    final posters = [
      ev['posterUrl1'],
      ev['posterUrl2'],
      ev['posterUrl3'],
      ev['posterUrl4'],
    ].where((url) => url != null && url.toString().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (posters.isNotEmpty) ...[
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: posters.length,
              itemBuilder: (context, idx) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      posters[idx],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.surface,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.all(24),
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
                      color: ev['isPaid']
                          ? AppTheme.accent.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ev['isPaid'] ? "PAID: ₹${ev['entryFee']}" : "FREE EVENT",
                      style: TextStyle(
                        color: ev['isPaid']
                            ? AppTheme.accent
                            : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    ev['college']?['name'] ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                ev['title'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ev['description'] ?? 'No description provided.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              const SizedBox(height: 20),
              _detailRow(
                Icons.calendar_today,
                "Event Date",
                DateTime.parse(
                  ev['eventDate'],
                ).toLocal().toString().substring(0, 16),
              ),
              _detailRow(
                Icons.timer_outlined,
                "Countdown",
                _getCountdown(),
                color: isClosed ? AppTheme.accent : AppTheme.primary,
              ),
              _detailRow(
                Icons.school_outlined,
                "Branch Focus",
                ev['branch'] ?? 'Open',
              ),
              _detailRow(
                Icons.group_work_outlined,
                "Event Type",
                ev['eventType']?.toString().toUpperCase() ?? 'INDIVIDUAL',
              ),
              if (ev['eventType'] == 'group' || ev['eventType'] == 'both')
                _detailRow(
                  Icons.groups_outlined,
                  "Group Size Limits",
                  "Min: ${ev['minMembers']} - Max: ${ev['maxMembers']}",
                ),
              _detailRow(
                Icons.person_pin_outlined,
                "Coordinator",
                ev['creator']?['fullName'] ?? 'Faculty Board',
              ),

              if (ev['whatsAppGroupLink'] != null &&
                  ev['whatsAppGroupLink'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Join Official WhatsApp Group"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text("WhatsApp Group"),
                        content: SelectableText(
                          "Join the group at: ${ev['whatsAppGroupLink']}",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              if (ev['brochureUrl'] != null &&
                  ev['brochureUrl'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    "Download Brochure (${ev['brochurePages'] ?? 0} Pages)",
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text("Event Brochure"),
                        content: SelectableText(
                          "View brochure PDF at: ${ev['brochureUrl']}",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Registration controls for Student
        if (user.role == 'student') _buildStudentRegistrationBox(user),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Student ticket / registration module
  Widget _buildStudentRegistrationBox(UserProvider user) {
    final ev = _event!;

    final myReg =
        (ev['registrations'] != null &&
            (ev['registrations'] as List).isNotEmpty)
        ? ev['registrations'][0]
        : null;

    if (myReg != null) {
      final status = myReg['paymentStatus'];
      final isVerifiedPass = status == 'free_event' || status == 'completed';
      final dl = DateTime.parse(ev['registrationDeadline']);
      final isBeforeDeadline = dl.isAfter(DateTime.now());

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isVerifiedPass
              ? Colors.green.withValues(alpha: 0.1)
              : AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isVerifiedPass
                ? Colors.green.withValues(alpha: 0.4)
                : AppTheme.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isVerifiedPass ? Icons.verified : Icons.hourglass_empty,
                  color: isVerifiedPass ? Colors.green : Colors.amber,
                ),
                const SizedBox(width: 12),
                Text(
                  isVerifiedPass
                      ? "YOUR TICKET IS CONFIRMED"
                      : "PAYMENT PENDING APPROVAL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isVerifiedPass ? Colors.green : Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Pass ID: ${myReg['id']}",
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              "Pass Type: ${myReg['registrationType'].toString().toUpperCase()}",
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            if (myReg['groupSize'] != null)
              Text(
                "Group Size: ${myReg['groupSize']}",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            if (myReg['paymentReference'] != null)
              Text(
                "UPI Reference: ${myReg['paymentReference']}",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            const SizedBox(height: 20),

            // Scan QR or Certificate buttons
            if (isVerifiedPass) ...[
              // Check if attended
              FutureBuilder<List<dynamic>>(
                // Check event attendance logs
                future: _eventService.getEventAttendance(user.token!, ev['id']),
                builder: (context, attendanceSnapshot) {
                  final list = attendanceSnapshot.data ?? [];
                  final isAttended = list.any(
                    (a) => a['userId'] == user.userId,
                  );

                  if (isAttended) {
                    if (_approvedTemplate != null) {
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.card_membership_rounded),
                        label: const Text("Download Participation Certificate"),
                        onPressed: () {
                          final url =
                              "${EventService.baseUrl}/events/${ev['id']}/certificates/download?format=html";
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: const Text("My Certificate"),
                              content: Text(
                                "Certificate generated! Code details are ready. Open standard link to view: \n\n$url",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Done"),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(
                        child: Text(
                          "Attendance logged. Awaiting coordinator template approval to unlock certificate.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                  }

                  // Not attended yet, show scan QR code button
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan Venue QR Code"),
                    onPressed: () async {
                      final scanned = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QrScannerScreen(
                            eventId: ev['id'],
                            actualCode: ev['qrAttendanceCode'],
                          ),
                        ),
                      );
                      if (scanned == true) {
                        _fetchDetails();
                      }
                    },
                  );
                },
              ),
            ],

            if (isBeforeDeadline) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Cancel Registration"),
                      content: const Text(
                        "Are you sure you want to cancel your registration for this event?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("No"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Yes, Cancel"),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() => _isLoading = true);
                    try {
                      await _eventService.unregisterFromEvent(
                        user.token!,
                        ev['id'],
                        myReg['id'],
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Registration cancelled successfully!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchDetails();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: AppTheme.accent,
                        ),
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child: const Text("Cancel Registration"),
              ),
            ],
          ],
        ),
      );
    }

    final minSize = ev['minMembers'] ?? 1;
    final maxSize = ev['maxMembers'] ?? 1;
    final eventType = ev['eventType'] ?? 'individual';

    final allowedTypes = <DropdownMenuItem<String>>[];
    if (eventType == 'individual' || eventType == 'both') {
      allowedTypes.add(
        const DropdownMenuItem(
          value: 'individual',
          child: Text("Individual Entry"),
        ),
      );
    }
    if (eventType == 'group' || eventType == 'both') {
      allowedTypes.add(
        const DropdownMenuItem(
          value: 'group',
          child: Text("Group Entry (Delegate Pass)"),
        ),
      );
    }

    if (eventType == 'group' && _regType == 'individual') {
      _regType = 'group';
    } else if (eventType == 'individual' && _regType == 'group') {
      _regType = 'individual';
    }

    // Register button and inputs
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Event Registration Pass",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _regType,
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(
              labelText: "Registration Type",
              prefixIcon: Icons.group_add_outlined,
            ),
            items: allowedTypes,
            onChanged: (val) => setState(() => _regType = val!),
          ),

          if (_regType == 'group') ...[
            const SizedBox(height: 20),
            TextField(
              controller: _groupSizeController,
              keyboardType: TextInputType.number,
              decoration: AppTheme.inputDecoration(
                labelText: "Group Size (Between $minSize and $maxSize)",
                prefixIcon: Icons.groups_outlined,
              ),
            ),
          ],

          if (ev['isPaid']) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    "UPI Payment Required",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Pay entry fee: ₹${ev['entryFee']}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "UPI Address: ${ev['upiId']}",
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Simulated QR Image
                  Image.network(
                    "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=${ev['upiId']}&pn=CollegeConnect&am=${ev['entryFee']}&cu=INR",
                    height: 120,
                    width: 120,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.qr_code, size: 80),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Scan QR & enter transaction reference below:",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _payRefController,
              decoration: AppTheme.inputDecoration(
                labelText: "UPI Transaction Reference ID",
                prefixIcon: Icons.receipt_long,
              ),
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _registerForEvent,
            child: const Text("Register for Event"),
          ),
        ],
      ),
    );
  }

  // 3. Coordinator Passes Tab
  Widget _buildPassesTab(UserProvider user) {
    if (_registrations.isEmpty) {
      return const Center(child: Text("No registrations recorded."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _registrations.length,
      itemBuilder: (_, index) {
        final reg = _registrations[index];
        final studentName = reg['user']?['fullName'] ?? 'N/A';
        final status = reg['paymentStatus'];
        final isPending = status == 'pending';

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
                    Text(
                      "Type: ${reg['registrationType']}",
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (reg['user']?['college']?['name'] != null)
                      Text(
                        "College: ${reg['user']['college']['name']}",
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
                    if (user.role != 'coordinator') ...[
                      if (reg['user']?['email'] != null)
                        Text(
                          "Email: ${reg['user']['email']}",
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      if (reg['user']?['department'] != null)
                        Text(
                          "Dept: ${reg['user']['department']}",
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                    if (reg['paymentReference'] != null)
                      Text(
                        "Ref: ${reg['paymentReference']}",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: TextStyle(
                        color: isPending ? Colors.amber : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _eventService.confirmPayment(
                            user.token!,
                            _event!['id'],
                            reg['id'],
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Payment confirmed!")),
                          );
                          _fetchDetails();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      },
                      child: const Text(
                        "Approve",
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Coordinator Attendance Log Tab
  Widget _buildAttendanceTab(UserProvider user) {
    return Column(
      children: [
        // QR Code box
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            children: [
              const Text(
                "Attendance QR Code Pass",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Display at venue for student check-ins",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Event QR server loader
              Image.network(
                "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${_event!['qrAttendanceCode']}",
                height: 180,
                width: 180,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.qr_code, size: 100),
              ),
              const SizedBox(height: 12),
              Text(
                "Code Payload: ${_event!['qrAttendanceCode']}",
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontFamily: 'Fira Code',
                ),
              ),
            ],
          ),
        ),

        // Logs Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Attendee Log",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),

        // List
        Expanded(
          child: _attendance.isEmpty
              ? const Center(child: Text("No check-ins logged yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _attendance.length,
                  itemBuilder: (_, index) {
                    final att = _attendance[index];
                    final isVerified = att['verifiedBy'] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                att['user']?['fullName'] ?? 'N/A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Marked: ${DateTime.parse(att['markedAt']).toLocal().toString().substring(11, 16)}",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          isVerified
                              ? const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                )
                              : TextButton(
                                  onPressed: () async {
                                    try {
                                      await _eventService.verifyAttendance(
                                        user.token!,
                                        _event!['id'],
                                        att['id'],
                                      );
                                      _fetchDetails();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text("Error: $e")),
                                      );
                                    }
                                  },
                                  child: const Text("Verify"),
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

  // 5. Coordinator Certificate Designer Tab
  Widget _buildAiTemplatesTab(UserProvider user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Suggested Designs",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Suggestions were generated dynamically using OpenRouter AI based on event topic.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (_approvedTemplate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          "Approved Theme: ${_approvedTemplate!['templateName']}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_aiTemplates.isEmpty)
            const Center(
              child: Text("Generating dynamic certificate themes..."),
            )
          else
            ..._aiTemplates.map((tpl) {
              final isApprovedThis =
                  _approvedTemplate?['templateName'] == tpl['templateName'];

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isApprovedThis
                        ? AppTheme.primary
                        : const Color(0xFF1E293B),
                    width: isApprovedThis ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tpl['templateName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (isApprovedThis)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Justification: ${tpl['aiJustification']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Design Swatch
                    Row(
                      children: [
                        _swatch("Primary", tpl['primaryColor']),
                        const SizedBox(width: 12),
                        _swatch("Secondary", tpl['secondaryColor']),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Font Family",
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              tpl['fontFamily'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Details: ${tpl['layoutDescription']}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApprovedThis
                            ? Colors.grey[800]
                            : AppTheme.primary,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: isApprovedThis
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await _eventService.approveCertificateTemplate(
                                  user.token!,
                                  _event!['id'],
                                  tpl,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Design approved and set! Certificate is live for attendees.",
                                    ),
                                  ),
                                );
                                _fetchDetails();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                      child: Text(
                        isApprovedThis
                            ? "Currently Selected"
                            : "Approve & Apply Layout",
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _swatch(String label, String hex) {
    Color parsedColor = Colors.grey;
    try {
      parsedColor = Color(int.parse(hex.replaceAll("#", "0xFF")));
    } catch (_) {}

    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: parsedColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              hex,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
