import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';

class QrScannerScreen extends StatefulWidget {
  final String eventId;
  final String actualCode; // Used for easy simulation/testing

  const QrScannerScreen({
    super.key,
    required this.eventId,
    required this.actualCode,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _eventService = EventService();
  bool _isLoading = false;
  bool _isSuccess = false;
  String _errorMsg = "";

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _submitScan(String code) async {
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final user = Provider.of<UserProvider>(context, listen: false);
      await _eventService.scanQrCode(user.token!, widget.eventId, code.trim());

      setState(() {
        _isSuccess = true;
      });

      // Close automatically after 2s showing success
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgorund.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSuccess) ...[
                          // Success View
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: AppTheme.cardDecoration(),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, size: 60, color: Colors.white),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "Check-In Confirmed!",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Your attendance has been marked. Returning to event details...",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        ] else ...[
                          // Scanner Simulator View
                          const Text(
                            "Scan Event Check-In QR",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Position the venue QR code inside the viewport box.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 30),

                          // Viewport Border Frame
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 240,
                                width: 240,
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  border: Border.all(color: AppTheme.primary, width: 3),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 50,
                                  color: Colors.white24,
                                ),
                              ),
                              // Moving Scan Line Animation
                              AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  return Positioned(
                                    top: 10 + (_animController.value * 210),
                                    child: Container(
                                      width: 220,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(alpha: 0.8),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Testing Utilities Form
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Testing Simulator Helper",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 12),
                                
                                // Auto simulate button
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                                        icon: const Icon(Icons.rocket_launch),
                                        label: const Text("AUTO SIMULATE SCAN"),
                                        onPressed: () => _submitScan(widget.actualCode),
                                      ),
                                const SizedBox(height: 12),
                                
                                const Center(child: Text("OR ENTER MANUAL CODE PAYLOAD", style: TextStyle(fontSize: 10, color: AppTheme.textSecondary))),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _inputController,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  decoration: AppTheme.inputDecoration(
                                    labelText: "QR Payload Value",
                                    prefixIcon: Icons.qr_code,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, side: const BorderSide(color: Colors.white24)),
                                    onPressed: () => _submitScan(_inputController.text),
                                    child: const Text("Submit Code String"),
                                  ),
                              ],
                            ),
                          ),
                          
                          if (_errorMsg.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              _errorMsg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ]
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
