import 'package:flutter/material.dart';
import 'select_login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Hardcoded branding configuration for Bennett University as requested
  final String _instituteName = "Bennett University";
  final String _subtitle = "The College Intelligence App";
  final Color _brandColor = const Color(0xFFD30014); // Bennett Crimson Red

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Chevron background lines
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundChevronPainter(),
            ),
          ),

          // 2. City Silhouette at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.24,
            child: CustomPaint(
              painter: BuildingSilhouettePainter(),
            ),
          ),

          // 3. Main content area
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 150,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _brandColor.withOpacity(0.2),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: CustomPaint(
                          painter: CollegeLogoPainter(
                            logoColor: _brandColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title / Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _instituteName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A), // Slate 900
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), // Slate 500
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Button area (above building illustration)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_brandColor, _brandColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _brandColor.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        // Navigate to SelectLoginScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SelectLoginScreen(
                              brandColor: _brandColor,
                              instituteName: _instituteName,
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Get Started",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Offset padding to clear building heights
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painter for drawing background diagonals chevron pattern
class BackgroundChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F5F9).withOpacity(0.9)
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
      ..color = tintColor.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = tintColor.withOpacity(0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final windowPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Clouds
    final cloudPaint = Paint()
      ..color = tintColor.withOpacity(0.3)
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
    final centerRect = Rect.fromLTRB(width * 0.36, height * 0.1, width * 0.64, height);
    canvas.drawRect(centerRect, fillPaint);
    canvas.drawRect(centerRect, linePaint);

    // Antenna/Pillars on center building
    canvas.drawLine(Offset(width * 0.42, height * 0.05), Offset(width * 0.42, height * 0.1), linePaint);
    canvas.drawLine(Offset(width * 0.50, height * 0.02), Offset(width * 0.50, height * 0.1), linePaint);
    canvas.drawLine(Offset(width * 0.58, height * 0.05), Offset(width * 0.58, height * 0.1), linePaint);

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
    final leftRect = Rect.fromLTRB(width * 0.22, height * 0.38, width * 0.36, height);
    canvas.drawRect(leftRect, fillPaint);
    canvas.drawRect(leftRect, linePaint);

    // Left building roof details
    canvas.drawLine(Offset(width * 0.25, height * 0.38), Offset(width * 0.25, height * 0.33), linePaint);
    canvas.drawLine(Offset(width * 0.33, height * 0.38), Offset(width * 0.33, height * 0.33), linePaint);
    canvas.drawLine(Offset(width * 0.25, height * 0.33), Offset(width * 0.33, height * 0.33), linePaint);

    // Left building horizontal lines
    for (int i = 1; i <= 3; i++) {
      double y = height * 0.38 + i * (height * 0.14);
      if (y < height - 10) {
        canvas.drawRect(Rect.fromLTWH(width * 0.24, y, width * 0.09, 5), windowPaint);
      }
    }

    // 3. Right Building
    final rightRect = Rect.fromLTRB(width * 0.64, height * 0.38, width * 0.78, height);
    canvas.drawRect(rightRect, fillPaint);
    canvas.drawRect(rightRect, linePaint);

    // Right building roof details
    canvas.drawLine(Offset(width * 0.67, height * 0.38), Offset(width * 0.67, height * 0.33), linePaint);
    canvas.drawLine(Offset(width * 0.75, height * 0.38), Offset(width * 0.75, height * 0.33), linePaint);
    canvas.drawLine(Offset(width * 0.67, height * 0.33), Offset(width * 0.75, height * 0.33), linePaint);

    // Right building horizontal lines
    for (int i = 1; i <= 3; i++) {
      double y = height * 0.38 + i * (height * 0.14);
      if (y < height - 10) {
        canvas.drawRect(Rect.fromLTWH(width * 0.67, y, width * 0.09, 5), windowPaint);
      }
    }

    // 4. Stylized Trees on Left
    final leafPaint = Paint()
      ..color = tintColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    double lx1 = width * 0.12;
    double ly1 = height * 0.82;
    canvas.drawLine(Offset(lx1, ly1), Offset(lx1, height), linePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx1 - 5, ly1 + 8), width: 5, height: 10), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx1 + 5, ly1 + 16), width: 5, height: 10), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx1, ly1), width: 7, height: 13), leafPaint);

    double lx2 = width * 0.06;
    double ly2 = height * 0.88;
    canvas.drawLine(Offset(lx2, ly2), Offset(lx2, height), linePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx2 - 4, ly2 + 6), width: 4, height: 8), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx2 + 4, ly2 + 12), width: 4, height: 8), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(lx2, ly2), width: 5, height: 10), leafPaint);

    // 5. Stylized Trees on Right
    double rx1 = width * 0.88;
    double ry1 = height * 0.82;
    canvas.drawLine(Offset(rx1, ry1), Offset(rx1, height), linePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx1 - 5, ry1 + 16), width: 5, height: 10), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx1 + 5, ry1 + 8), width: 5, height: 10), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx1, ry1), width: 7, height: 13), leafPaint);

    double rx2 = width * 0.94;
    double ry2 = height * 0.88;
    canvas.drawLine(Offset(rx2, ry2), Offset(rx2, height), linePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx2 - 4, ry2 + 12), width: 4, height: 8), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx2 + 4, ry2 + 6), width: 4, height: 8), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(rx2, ry2), width: 5, height: 10), leafPaint);
  }

  @override
  bool shouldRepaint(covariant BuildingSilhouettePainter oldDelegate) => false;
}

// Vector Logos for College (Bennett University stylized face)
class CollegeLogoPainter extends CustomPainter {
  final Color logoColor;
  CollegeLogoPainter({required this.logoColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = logoColor
      ..style = PaintingStyle.fill;

    // Draw the shield base
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.6);
    path.quadraticBezierTo(
        size.width, size.height * 0.9, size.width / 2, size.height);
    path.quadraticBezierTo(0, size.height * 0.9, 0, size.height * 0.6);
    path.close();
    canvas.drawPath(path, paint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Bennett University stylized face
    // Forehead brow
    final browRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.15,
        size.height * 0.22,
        size.width * 0.85,
        size.height * 0.32,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(browRect, whitePaint);

    // Nose
    final nosePath = Path();
    nosePath.moveTo(size.width * 0.47, size.height * 0.36);
    nosePath.lineTo(size.width * 0.53, size.height * 0.36);
    nosePath.lineTo(size.width * 0.53, size.height * 0.60);
    nosePath.lineTo(size.width * 0.47, size.height * 0.65);
    nosePath.close();
    canvas.drawPath(nosePath, whitePaint);

    // Mouth
    final mouthPath = Path();
    mouthPath.moveTo(size.width * 0.5, size.height * 0.71);
    mouthPath.lineTo(size.width * 0.31, size.height * 0.81);
    mouthPath.lineTo(size.width * 0.69, size.height * 0.81);
    mouthPath.close();
    canvas.drawPath(mouthPath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CollegeLogoPainter oldDelegate) {
    return oldDelegate.logoColor != logoColor;
  }
}
