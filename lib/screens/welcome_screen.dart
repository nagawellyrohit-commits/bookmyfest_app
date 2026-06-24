import 'dart:async';
import 'package:flutter/material.dart';
import 'select_login_screen.dart';
import '../services/sponsor_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final String _instituteName = "bookmyfest";
  final String _title = "Your Campus Events \nAll in One Place.";
  final String _subtitle = "Discover • Book • Celebrate";
  final Color _brandColor = const Color(0xff9708AA);

  late final AnimationController _controller;
  late final AnimationController _shakeController;
  late final AnimationController _zoomController;

  late final Animation<double> _buttonScaleAnimation;
  late final Animation<int> _textCharCountAnimation;
  late final Animation<double> _iconPopAnimation;
  late final Animation<double> _shakeAnimation;
  late final Animation<double> _zoomScaleAnimation;
  late final Animation<double> _zoomOpacityAnimation;

  bool _isNavigating = false;
  bool _isImageLoaded = false;
  bool _isPreloading = false;
  final SponsorService _sponsorService = SponsorService();
  List<dynamic> _sponsors = [];

  @override
  void initState() {
    super.initState();

    // 1. Entry Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Button scales up in place with a bounce
    _buttonScaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );

    // Text characters reveal one by one
    _textCharCountAnimation = IntTween(begin: 0, end: 11).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
      ),
    );

    // Pop the icon elastically after the text is fully typed
    _iconPopAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.elasticOut),
    );

    // 2. Shake Animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: -1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_shakeController);

    // Start shaking after the entry animation finishes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isNavigating) {
        _shakeController.repeat();
      }
    });

    // 3. Zoom Animation
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _zoomScaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );

    _zoomOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    try {
      final data = await _sponsorService.fetchSponsors();
      if (mounted) {
        setState(() {
          _sponsors = data;
        });
      }
    } catch (e) {
      debugPrint("Failed to load sponsors: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadImages();
  }

  Future<void> _preloadImages() async {
    if (_isPreloading) return;
    _isPreloading = true;
    try {
      await Future.wait([
        precacheImage(const AssetImage('assets/images/welcome.png'), context),
        precacheImage(const AssetImage('assets/images/logo.png'), context),
      ]);
    } catch (e) {
      // Ignore image preloading failures to prevent freezing the app
    }
    if (mounted) {
      setState(() {
        _isImageLoaded = true;
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset('assets/images/welcome.png', fit: BoxFit.cover),
          ),

          // 2. Main content area
          if (_isImageLoaded)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxHeight < 620;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            // 1. Top branding and scrollable info section
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 20),
                                  // Logo from assets
                                  Image.asset(
                                    'assets/images/logo.png',
                                    width: isSmallScreen ? 110 : 140,
                                    height: isSmallScreen ? 110 : 140,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 2),

                                  // Institute Name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text.rich(
                                      const TextSpan(
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "bookmy",
                                            style: TextStyle(
                                              color: Color(0xffED1383),
                                            ),
                                          ),
                                          TextSpan(
                                            text: "fest",
                                            style: TextStyle(
                                              color: Color(0xff9708AA),
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Title
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      _title,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 24 : 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(
                                          255,
                                          13,
                                          13,
                                          13,
                                        ),
                                        height: 1.25,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Subtitle
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      _subtitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFE5A93B),
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  SizedBox(height: isSmallScreen ? 60 : 100),

                                  // 2. Action Button area (placed higher up)
                                  AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _controller,
                                      _shakeController,
                                      _zoomController,
                                    ]),
                                    builder: (context, child) {
                                      final val = _buttonScaleAnimation.value;
                                      final zoomScale =
                                          _zoomScaleAnimation.value;
                                      final zoomOpacity =
                                          _zoomOpacityAnimation.value;
                                      final shakeVal = _shakeAnimation.value;

                                      return Transform.scale(
                                        scale: val * zoomScale,
                                        child: Opacity(
                                          opacity:
                                              (val.clamp(0.0, 1.0) *
                                                      zoomOpacity)
                                                  .clamp(0.0, 1.0),
                                          child: Transform.translate(
                                            offset: Offset(shakeVal * 5.0, 0.0),
                                            child: Transform.rotate(
                                              angle: shakeVal * 0.02,
                                              child: child,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: isSmallScreen ? 12 : 18,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _brandColor,
                                              _brandColor.withValues(
                                                alpha: 0.8,
                                              ),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _brandColor.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 15,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          onPressed: () async {
                                            if (_isNavigating ||
                                                !_controller.isCompleted) {
                                              return;
                                            }

                                            setState(() {
                                              _isNavigating = true;
                                            });

                                            // Stop shake immediately and reset to center
                                            _shakeController.stop();
                                            _shakeController.reset();

                                            // Play zoom scale-up and fade-out animation
                                            await _zoomController.forward();

                                            if (!context.mounted) return;

                                            // Navigate to SelectLoginScreen
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SelectLoginScreen(
                                                      brandColor: _brandColor,
                                                      instituteName:
                                                          _instituteName,
                                                    ),
                                              ),
                                            );

                                            // Once returned from SelectLoginScreen:
                                            // Reset zoom, reset navigation state, and restart shake
                                            _zoomController.reset();
                                            setState(() {
                                              _isNavigating = false;
                                            });
                                            _shakeController.repeat();
                                          },
                                          child: AnimatedBuilder(
                                            animation: _textCharCountAnimation,
                                            builder: (context, child) {
                                              final count =
                                                  _textCharCountAnimation.value;
                                              final visibleText = "Get Started"
                                                  .substring(0, count);
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    visibleText,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ScaleTransition(
                                                    scale: _iconPopAnimation,
                                                    child: const Icon(
                                                      Icons.arrow_forward,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),

                            if (_sponsors.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "Sponsored by",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _SponsorshipMarquee(sponsors: _sponsors),
                            ],

                            // Bottom spacer to ensure the sponsor marquee sits cleanly above the background icons
                            SizedBox(height: isSmallScreen ? 90 : 125),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SponsorshipMarquee extends StatefulWidget {
  final List<dynamic> sponsors;
  const _SponsorshipMarquee({required this.sponsors});

  @override
  State<_SponsorshipMarquee> createState() => _SponsorshipMarqueeState();
}

class _SponsorshipMarqueeState extends State<_SponsorshipMarquee> {
  late final ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final currentPosition = _scrollController.position.pixels;
        final double singleCycleWidth = widget.sponsors.length * 90.0;

        double nextPosition = currentPosition + 0.8;
        if (nextPosition >= singleCycleWidth) {
          nextPosition -= singleCycleWidth;
          _scrollController.jumpTo(nextPosition);
        } else {
          _scrollController.jumpTo(nextPosition);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double singleCycleWidth = widget.sponsors.length * 90.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetWidth = screenWidth + singleCycleWidth;
    final repeatCount =
        (targetWidth / (singleCycleWidth > 0 ? singleCycleWidth : 1)).ceil() +
        1;

    final displayList = <dynamic>[];
    for (int i = 0; i < repeatCount; i++) {
      displayList.addAll(widget.sponsors);
    }

    return Container(
      height: 70,
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      color: Colors.transparent,
      child: Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final sp = displayList[index];
              final logoUrl = sp['logoUrl']?.toString() ?? '';

              if (logoUrl.isEmpty) return const SizedBox.shrink();

              return Container(
                width: 90,
                alignment: Alignment.center,
                child: Image.network(
                  logoUrl,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.business_outlined,
                    size: 24,
                    color: Color(0xFF64748B),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Painter for drawing background diagonals chevron pattern
class BackgroundChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F5F9).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    // Chevron 1
    final path = Path();
    path.moveTo(0, size.height * 0.28);
    path.lineTo(size.width / 2, size.height * 0.40);
    path.lineTo(size.width, size.height * 0.28);
    path.lineTo(size.width, size.height * 0.40);
    path.lineTo(size.width / 2, size.height * 0.52);
    path.lineTo(0, size.height * 0.40);
    path.close();
    canvas.drawPath(path, paint);

    // Chevron 2
    final path2 = Path();
    path2.moveTo(0, size.height * 0.48);
    path2.lineTo(size.width / 2, size.height * 0.60);
    path2.lineTo(size.width, size.height * 0.48);
    path2.lineTo(size.width, size.height * 0.60);
    path2.lineTo(size.width / 2, size.height * 0.72);
    path2.lineTo(0, size.height * 0.60);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Painter for drawing the city buildings silhouette at the bottom
class BuildingSilhouettePainter extends CustomPainter {
  final Color tintColor;
  BuildingSilhouettePainter({this.tintColor = const Color(0xFFE2E8F0)});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = tintColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = tintColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Clouds
    final cloudPaint = Paint()
      ..color = tintColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Cloud Left
    canvas.drawCircle(Offset(width * 0.15, height * 0.3), 16, cloudPaint);
    canvas.drawCircle(Offset(width * 0.20, height * 0.32), 12, cloudPaint);
    canvas.drawCircle(Offset(width * 0.10, height * 0.33), 12, cloudPaint);

    // Cloud Right
    canvas.drawCircle(Offset(width * 0.82, height * 0.25), 20, cloudPaint);
    canvas.drawCircle(Offset(width * 0.87, height * 0.28), 15, cloudPaint);
    canvas.drawCircle(Offset(width * 0.78, height * 0.29), 14, cloudPaint);

    // 1. Central building
    final centerRect = Rect.fromLTRB(
      width * 0.36,
      height * 0.1,
      width * 0.64,
      height,
    );
    canvas.drawRect(centerRect, fillPaint);
    canvas.drawRect(centerRect, linePaint);

    // Antenna/Pillars on center building
    canvas.drawLine(
      Offset(width * 0.42, height * 0.05),
      Offset(width * 0.42, height * 0.1),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.50, height * 0.02),
      Offset(width * 0.50, height * 0.1),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.58, height * 0.05),
      Offset(width * 0.58, height * 0.1),
      linePaint,
    );

    // Windows central building (3 columns, 4 rows)
    double winW = width * 0.04;
    double winH = height * 0.08;
    double startY = height * 0.22;
    for (int r = 0; r < 4; r++) {
      double y = startY + r * (winH + 12);
      if (y + winH > height - 10) break;
      canvas.drawRect(Rect.fromLTWH(width * 0.40, y, winW, winH), windowPaint);
      canvas.drawRect(Rect.fromLTWH(width * 0.48, y, winW, winH), windowPaint);
      canvas.drawRect(Rect.fromLTWH(width * 0.56, y, winW, winH), windowPaint);
    }

    // 2. Left Building
    final leftRect = Rect.fromLTRB(
      width * 0.22,
      height * 0.38,
      width * 0.36,
      height,
    );
    canvas.drawRect(leftRect, fillPaint);
    canvas.drawRect(leftRect, linePaint);

    // Left building roof details
    canvas.drawLine(
      Offset(width * 0.25, height * 0.38),
      Offset(width * 0.25, height * 0.33),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.33, height * 0.38),
      Offset(width * 0.33, height * 0.33),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.25, height * 0.33),
      Offset(width * 0.33, height * 0.33),
      linePaint,
    );

    // Left building horizontal lines
    for (int i = 1; i <= 3; i++) {
      double y = height * 0.38 + i * (height * 0.14);
      if (y < height - 10) {
        canvas.drawRect(
          Rect.fromLTWH(width * 0.24, y, width * 0.09, 5),
          windowPaint,
        );
      }
    }

    // 3. Right Building
    final rightRect = Rect.fromLTRB(
      width * 0.64,
      height * 0.38,
      width * 0.78,
      height,
    );
    canvas.drawRect(rightRect, fillPaint);
    canvas.drawRect(rightRect, linePaint);

    // Right building roof details
    canvas.drawLine(
      Offset(width * 0.67, height * 0.38),
      Offset(width * 0.67, height * 0.33),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.75, height * 0.38),
      Offset(width * 0.75, height * 0.33),
      linePaint,
    );
    canvas.drawLine(
      Offset(width * 0.67, height * 0.33),
      Offset(width * 0.75, height * 0.33),
      linePaint,
    );

    // Right building horizontal lines
    for (int i = 1; i <= 3; i++) {
      double y = height * 0.38 + i * (height * 0.14);
      if (y < height - 10) {
        canvas.drawRect(
          Rect.fromLTWH(width * 0.67, y, width * 0.09, 5),
          windowPaint,
        );
      }
    }

    // 4. Stylized Trees on Left
    final leafPaint = Paint()
      ..color = tintColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    double lx1 = width * 0.12;
    double ly1 = height * 0.82;
    canvas.drawLine(Offset(lx1, ly1), Offset(lx1, height), linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx1 - 5, ly1 + 8), width: 5, height: 10),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx1 + 5, ly1 + 16), width: 5, height: 10),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx1, ly1), width: 7, height: 13),
      leafPaint,
    );

    double lx2 = width * 0.06;
    double ly2 = height * 0.88;
    canvas.drawLine(Offset(lx2, ly2), Offset(lx2, height), linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx2 - 4, ly2 + 6), width: 4, height: 8),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx2 + 4, ly2 + 12), width: 4, height: 8),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx2, ly2), width: 5, height: 10),
      leafPaint,
    );

    // 5. Stylized Trees on Right
    double rx1 = width * 0.88;
    double ry1 = height * 0.82;
    canvas.drawLine(Offset(rx1, ry1), Offset(rx1, height), linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx1 - 5, ry1 + 16), width: 5, height: 10),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx1 + 5, ry1 + 8), width: 5, height: 10),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx1, ry1), width: 7, height: 13),
      leafPaint,
    );

    double rx2 = width * 0.94;
    double ry2 = height * 0.88;
    canvas.drawLine(Offset(rx2, ry2), Offset(rx2, height), linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx2 - 4, ry2 + 12), width: 4, height: 8),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx2 + 4, ry2 + 6), width: 4, height: 8),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx2, ry2), width: 5, height: 10),
      leafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BuildingSilhouettePainter oldDelegate) => false;
}
