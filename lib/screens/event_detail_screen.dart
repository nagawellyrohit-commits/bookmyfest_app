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

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
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

  // Student Registration Controllers
  final _payRefController = TextEditingController();
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
    _payRefController.dispose();
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
      if (user.role == 'coordinator' || user.role == 'faculty_admin' || user.role == 'super_admin') {
        _registrations = await _eventService.getEventRegistrations(token, widget.eventId!);
        _attendance = await _eventService.getEventAttendance(token, widget.eventId!);
        
        try {
          _aiTemplates = await _eventService.getCertificateSuggestions(token, widget.eventId!);
        } catch (_) {
          // Fallback handled gracefully by service
        }

        if (_tabController == null) {
          _tabController = TabController(length: 4, vsync: this);
        }
      }

      setState(() {
        _event = data;
        _approvedTemplate = data['certificateTemplate'];
      });
    } catch (e) {
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

  // Create Event Action
  void _createEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
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
        "entryFee": _isPaid ? double.tryParse(_feeController.text) ?? 0.00 : 0.00,
        "upiId": _isPaid ? _upiController.text.trim() : null,
      };

      await _eventService.createEvent(user.token!, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event published successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter UPI reference transaction ID")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      await _eventService.registerForEvent(
        user.token!,
        _event!['id'],
        registrationType: _regType,
        paymentReference: _event!['isPaid'] ? _payRefController.text.trim() : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration submitted!"), backgroundColor: Colors.green),
      );
      _fetchDetails();
    } catch (e) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreateMode ? "Publish New Event" : (_event?['title'] ?? "Loading...")),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : widget.isCreateMode
              ? _buildCreateForm()
              : _buildEventDetails(user),
    );
  }

  // 1. Creator Publish Form Layout
  Widget _buildCreateForm() {
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
                const Text("Event Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: AppTheme.inputDecoration(labelText: "Event Title", prefixIcon: Icons.title),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: AppTheme.inputDecoration(labelText: "Description", prefixIcon: Icons.description_outlined),
                ),
                const SizedBox(height: 20),

                // Date Selectors
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: AppTheme.primary),
                  title: const Text("Event Date & Time"),
                  subtitle: Text(_eventDate.toLocal().toString().substring(0, 16)),
                  trailing: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _eventDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _eventDate = DateTime(date.year, date.month, date.day, _eventDate.hour, _eventDate.minute));
                      }
                    },
                    child: const Text("Select"),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined, color: AppTheme.accent),
                  title: const Text("Registration Deadline"),
                  subtitle: Text(_deadline.toLocal().toString().substring(0, 16)),
                  trailing: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _deadline,
                        firstDate: DateTime.now(),
                        lastDate: _eventDate,
                      );
                      if (date != null) {
                        setState(() => _deadline = DateTime(date.year, date.month, date.day, _deadline.hour, _deadline.minute));
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
                    const Text("Is this a Paid Event?", style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isPaid,
                      activeColor: AppTheme.primary,
                      onChanged: (val) => setState(() => _isPaid = val),
                    ),
                  ],
                ),
                if (_isPaid) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    decoration: AppTheme.inputDecoration(labelText: "Entry Fee (INR)", prefixIcon: Icons.currency_rupee),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _upiController,
                    decoration: AppTheme.inputDecoration(labelText: "Organizer UPI ID", prefixIcon: Icons.qr_code),
                  ),
                ],
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _createEvent,
                  child: const Text("Publish Event"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 2. View Mode Layout
  Widget _buildEventDetails(UserProvider user) {
    if (_event == null) return const Center(child: Text("Event details unavailable."));

    // If Coordinator or Admin, show tabs
    final isCoordinator = user.role == 'coordinator' || user.role == 'faculty_admin' || user.role == 'super_admin';

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
                SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildInfoCard(user)),
                _buildPassesTab(user),
                _buildAttendanceTab(user),
                _buildAiTemplatesTab(user),
              ],
            ),
          )
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ev['isPaid'] ? AppTheme.accent.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ev['isPaid'] ? "PAID: ₹${ev['entryFee']}" : "FREE EVENT",
                      style: TextStyle(
                        color: ev['isPaid'] ? AppTheme.accent : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(ev['college']?['name'] ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                ev['title'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                ev['description'] ?? 'No description provided.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withOpacity(0.05)),
              const SizedBox(height: 20),
              _detailRow(Icons.calendar_today, "Event Date", DateTime.parse(ev['eventDate']).toLocal().toString().substring(0, 16)),
              _detailRow(Icons.timer_outlined, "Countdown", _getCountdown(), color: isClosed ? AppTheme.accent : AppTheme.primary),
              _detailRow(Icons.person_pin_outlined, "Coordinator", ev['creator']?['fullName'] ?? 'Faculty Board'),
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
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  // Student ticket / registration module
  Widget _buildStudentRegistrationBox(UserProvider user) {
    // Check if user is registered by querying local state if it matches their ID.
    // For local checks, if the student successfully registered, we show their pass.
    // In our backend flow, registrations list is available.
    // Let's check if there is an active registration.
    // We can simulate registration status based on registration reference state or fetch registrations list.
    // Let's implement registration box dynamically.
    final ev = _event!;

    // For testing registration states, we can fetch all event registrations and see if the user ID is in it.
    // We will do a fast check inside the _registrations list (which student can fetch if they want, but we should make sure student can see their own status).
    // Let's fetch registrations for the student.
    final myReg = _registrations.firstWhere(
      (r) => r['userId'] == user.userId,
      orElse: () => null,
    );

    if (myReg != null) {
      final status = myReg['paymentStatus'];
      final isVerifiedPass = status == 'free_event' || status == 'completed';

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isVerifiedPass ? Colors.green.withOpacity(0.1) : AppTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isVerifiedPass ? Colors.green.withOpacity(0.4) : AppTheme.accent.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(isVerifiedPass ? Icons.verified : Icons.hourglass_empty, color: isVerifiedPass ? Colors.green : Colors.amber),
                const SizedBox(width: 12),
                Text(
                  isVerifiedPass ? "YOUR TICKET IS CONFIRMED" : "PAYMENT PENDING APPROVAL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isVerifiedPass ? Colors.green : Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text("Pass ID: ${myReg['id']}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text("Pass Type: ${myReg['registrationType'].toString().toUpperCase()}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (myReg['paymentReference'] != null)
              Text("UPI Reference: ${myReg['paymentReference']}", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),

            // Scan QR or Certificate buttons
            if (isVerifiedPass) ...[
              // Check if attended
              FutureBuilder<List<dynamic>>(
                // Check event attendance logs
                future: _eventService.getEventAttendance(user.token!, ev['id']),
                builder: (context, attendanceSnapshot) {
                  final list = attendanceSnapshot.data ?? [];
                  final isAttended = list.any((a) => a['userId'] == user.userId);

                  if (isAttended) {
                    if (_approvedTemplate != null) {
                      return ElevatedButton.icon(
                        icon: const Icon(Icons.card_membership_rounded),
                        label: const Text("Download Participation Certificate"),
                        onPressed: () {
                          // Launch custom HTML certificate template download
                          final url = "${EventService.baseUrl}/events/${ev['id']}/certificates/download?format=html";
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: const Text("My Certificate"),
                              content: Text("Certificate generated! Code details are ready. Open standard link to view: \n\n$url"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
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
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                  }

                  // Not attended yet, show scan QR code button
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
              )
            ]
          ],
        ),
      );
    }

    // Register button and inputs
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Event Registration Pass", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _regType,
            dropdownColor: AppTheme.surface,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: AppTheme.inputDecoration(labelText: "Registration Type", prefixIcon: Icons.group_add_outlined),
            items: const [
              DropdownMenuItem(value: 'individual', child: Text("Individual Entry")),
              DropdownMenuItem(value: 'group', child: Text("Group Entry (Delegate Pass)")),
            ],
            onChanged: (val) => setState(() => _regType = val!),
          ),
          
          if (ev['isPaid']) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text("UPI Payment Required", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
                  const SizedBox(height: 6),
                  Text("Pay entry fee: ₹${ev['entryFee']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text("UPI Address: ${ev['upiId']}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  
                  // Simulated QR Image
                  Image.network(
                    "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=${ev['upiId']}&pn=CollegeConnect&am=${ev['entryFee']}&cu=INR",
                    height: 120,
                    width: 120,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code, size: 80),
                  ),
                  const SizedBox(height: 12),
                  const Text("Scan QR & enter transaction reference below:", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _payRefController,
              decoration: AppTheme.inputDecoration(labelText: "UPI Transaction Reference ID", prefixIcon: Icons.receipt_long),
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
      itemBuilder: (context, index) {
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
                    Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Type: ${reg['registrationType']}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (reg['paymentReference'] != null)
                      Text("Ref: ${reg['paymentReference']}", style: const TextStyle(color: Colors.blue, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.amber.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: TextStyle(color: isPending ? Colors.amber : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _eventService.confirmPayment(user.token!, _event!['id'], reg['id']);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment confirmed!")));
                          _fetchDetails();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      },
                      child: const Text("Approve", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              )
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
              const Text("Attendance QR Code Pass", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text("Display at venue for student check-ins", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              
              // Event QR server loader
              Image.network(
                "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${_event!['qrAttendanceCode']}",
                height: 180,
                width: 180,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code, size: 100),
              ),
              const SizedBox(height: 12),
              Text(
                "Code Payload: ${_event!['qrAttendanceCode']}",
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontFamily: 'Fira Code'),
              ),
            ],
          ),
        ),

        // Logs Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("Attendee Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),

        // List
        Expanded(
          child: _attendance.isEmpty
              ? const Center(child: Text("No check-ins logged yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _attendance.length,
                  itemBuilder: (context, index) {
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
                              Text(att['user']?['fullName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("Marked: ${DateTime.parse(att['markedAt']).toLocal().toString().substring(11, 16)}",
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                          isVerified
                              ? const Icon(Icons.check_circle_outline, color: Colors.green)
                              : TextButton(
                                  onPressed: () async {
                                    try {
                                      await _eventService.verifyAttendance(user.token!, _event!['id'], att['id']);
                                      _fetchDetails();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                    }
                                  },
                                  child: const Text("Verify"),
                                ),
                        ],
                      ),
                    );
                  },
                ),
        )
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
                const Text("AI Suggested Designs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                const Text(
                  "Suggestions were generated dynamically using OpenRouter AI based on event topic.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (_approvedTemplate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          "Approved Theme: ${_approvedTemplate!['templateName']}",
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_aiTemplates.isEmpty)
            const Center(child: Text("Generating dynamic certificate themes..."))
          else
            ..._aiTemplates.map((tpl) {
              final isApprovedThis = _approvedTemplate?['templateName'] == tpl['templateName'];

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isApprovedThis ? AppTheme.primary : const Color(0xFF1E293B),
                    width: isApprovedThis ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tpl['templateName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (isApprovedThis)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Justification: ${tpl['aiJustification']}",
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
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
                            const Text("Font Family", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(tpl['fontFamily'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text("Details: ${tpl['layoutDescription']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApprovedThis ? Colors.grey[800] : AppTheme.primary,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: isApprovedThis
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await _eventService.approveCertificateTemplate(user.token!, _event!['id'], tpl);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Design approved and set! Certificate is live for attendees.")),
                                );
                                _fetchDetails();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                      child: Text(isApprovedThis ? "Currently Selected" : "Approve & Apply Layout"),
                    ),
                  ],
                ),
              );
            }).toList()
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
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            Text(hex, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}
