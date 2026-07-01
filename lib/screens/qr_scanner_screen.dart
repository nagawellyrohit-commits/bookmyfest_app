import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/event_service.dart';

class QrScannerScreen extends StatefulWidget {
  final String eventId;
  final String actualCode; // The expected code payload for verification

  const QrScannerScreen({
    super.key,
    required this.eventId,
    required this.actualCode,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _eventService = EventService();
  final _cameraController = MobileScannerController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String _errorMsg = "";

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _cameraController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    } else {
      _cameraController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _cameraController.dispose();
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
                          // Scanner View
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
                          GestureDetector(
                            onTap: _isLoading ? null : () => _submitScan(widget.actualCode),
                            child: Stack(
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(21),
                                    child: MobileScanner(
                                      controller: _cameraController,
                                      onDetect: (BarcodeCapture capture) {
                                        if (_isLoading || _isSuccess) return;
                                        final List<Barcode> barcodes = capture.barcodes;
                                        if (barcodes.isNotEmpty) {
                                          final String? code = barcodes.first.rawValue;
                                          if (code != null) {
                                            _submitScan(code);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                // Moving Scan Line Animation
                                if (!_isLoading)
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
                                if (_isLoading)
                                  const CircularProgressIndicator(
                                    color: AppTheme.primary,
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: ValueListenableBuilder<MobileScannerState>(
                                  valueListenable: _cameraController,
                                  builder: (context, state, child) {
                                    switch (state.torchState) {
                                      case TorchState.off:
                                        return const Icon(Icons.flash_off, color: Colors.white70);
                                      case TorchState.on:
                                        return const Icon(Icons.flash_on, color: AppTheme.primary);
                                      default:
                                        return const Icon(Icons.flash_off, color: Colors.white70);
                                    }
                                  },
                                ),
                                iconSize: 28,
                                onPressed: () => _cameraController.toggleTorch(),
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                                iconSize: 28,
                                onPressed: () => _cameraController.switchCamera(),
                              ),
                            ],
                          ),
                          
                          if (_errorMsg.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              _errorMsg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap the scanner viewport to try again",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
