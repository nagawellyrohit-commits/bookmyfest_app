import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class SelectLoginScreen extends StatefulWidget {
  final Color brandColor;
  final String instituteName;

  const SelectLoginScreen({
    super.key,
    required this.brandColor,
    required this.instituteName,
  });

  @override
  State<SelectLoginScreen> createState() => _SelectLoginScreenState();
}

class _SelectLoginScreenState extends State<SelectLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _animations;

  // Helper to map UI role text to registration parameter values
  String _getRoleParamValue(String roleName) {
    switch (roleName) {
      case 'Student':
        return 'student';
      case 'Coordinator':
        return 'coordinator';
      case 'Faculty':
        return 'faculty_admin';
      case 'Super Admin':
        return 'super_admin';
      default:
        return 'student';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Create 4 staggered animations (one for each card)
    _animations = List.generate(4, (index) {
      final start = index * 0.12;
      final end = (start + 0.6).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBarColor = widget.brandColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light grey/white background
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 2,
        title: const Text(
          "Sign In",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset('assets/images/signin.png', fit: BoxFit.cover),
          ),

          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Heading: "Select Login"
                const Text(
                  "Select Login",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A), // Dark Slate
                  ),
                ),
                const SizedBox(height: 30),

                // Grid of 4 login types
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.95,
                    children: [
                      _buildLoginCard(
                        context,
                        index: 0,
                        title: "Student",
                        iconData: Icons.badge_rounded,
                        iconColor: appBarColor,
                      ),
                      _buildLoginCard(
                        context,
                        index: 1,
                        title: "Coordinator",
                        iconData: Icons.groups_rounded,
                        iconColor: appBarColor,
                      ),
                      _buildLoginCard(
                        context,
                        index: 2,
                        title: "Faculty",
                        iconData: Icons.co_present_rounded,
                        iconColor: appBarColor,
                      ),
                      _buildLoginCard(
                        context,
                        index: 3,
                        title: "Super Admin",
                        iconData: Icons.manage_accounts_rounded,
                        iconColor: appBarColor,
                      ),
                    ],
                  ),
                ),

                // Small footer text
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "BUILT FOR STUDENTS. POWERED BY RNI TECH",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(255, 14, 14, 14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(
    BuildContext context, {
    required int index,
    required String title,
    required IconData iconData,
    required Color iconColor,
  }) {
    final animation = _animations[index];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value;
        final scale = 0.85 + (val * 0.15);
        final slideY = (1.0 - val) * 60.0;
        final rotateX = (1.0 - val) * 0.22;
        final rotateY = (1.0 - val) * (index % 2 == 0 ? -0.15 : 0.15);

        final transformMatrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // 3D Perspective
          ..rotateX(rotateX)
          ..rotateY(rotateY);

        return Transform(
          transform:
              transformMatrix *
              Matrix4.translationValues(0.0, slideY, 0.0) *
              Matrix4.diagonal3Values(scale, scale, 1.0),
          alignment: Alignment.center,
          child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Navigate directly to LoginScreen, passing the selected role
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LoginScreen(selectedRole: _getRoleParamValue(title)),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large circular icon matching the screenshot style
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(iconData, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 16),
                // Card label
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Background CustomPainter to draw faint educational watermarks (graduation caps, books, etc.)
class WatermarkDoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double width = size.width;
    final double height = size.height;

    // Draw some simple vector representations of academic icons as watermarks

    // 1. Graduation Cap (Top Left)
    _drawCap(canvas, Offset(width * 0.15, height * 0.15), 25, paint);

    // 2. Book (Middle Right)
    _drawBook(canvas, Offset(width * 0.82, height * 0.35), 20, paint);

    // 3. Atom/Science (Bottom Left)
    _drawAtom(canvas, Offset(width * 0.18, height * 0.65), 22, paint);

    // 4. Pencil (Bottom Right)
    _drawPencil(canvas, Offset(width * 0.80, height * 0.75), 20, paint);

    // 5. Light bulb (Center Center)
    _drawBulb(canvas, Offset(width * 0.5, height * 0.48), 24, paint);
  }

  void _drawCap(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Rhombus top
    path.moveTo(center.dx, center.dy - size * 0.4);
    path.lineTo(center.dx + size * 0.8, center.dy);
    path.lineTo(center.dx, center.dy + size * 0.4);
    path.lineTo(center.dx - size * 0.8, center.dy);
    path.close();

    // Cap neck/base
    path.moveTo(center.dx - size * 0.4, center.dy + size * 0.2);
    path.quadraticBezierTo(
      center.dx,
      center.dy + size * 0.6,
      center.dx + size * 0.4,
      center.dy + size * 0.2,
    );
    path.lineTo(center.dx + size * 0.4, center.dy + size * 0.45);
    path.quadraticBezierTo(
      center.dx,
      center.dy + size * 0.8,
      center.dx - size * 0.4,
      center.dy + size * 0.45,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawBook(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Left page
    path.moveTo(center.dx, center.dy + size * 0.4);
    path.quadraticBezierTo(
      center.dx - size * 0.4,
      center.dy + size * 0.2,
      center.dx - size * 0.8,
      center.dy + size * 0.35,
    );
    path.lineTo(center.dx - size * 0.8, center.dy - size * 0.45);
    path.quadraticBezierTo(
      center.dx - size * 0.4,
      center.dy - size * 0.6,
      center.dx,
      center.dy - size * 0.4,
    );

    // Right page
    path.quadraticBezierTo(
      center.dx + size * 0.4,
      center.dy - size * 0.6,
      center.dx + size * 0.8,
      center.dy - size * 0.45,
    );
    path.lineTo(center.dx + size * 0.8, center.dy + size * 0.35);
    path.quadraticBezierTo(
      center.dx + size * 0.4,
      center.dy + size * 0.2,
      center.dx,
      center.dy + size * 0.4,
    );

    // Center fold
    path.moveTo(center.dx, center.dy - size * 0.4);
    path.lineTo(center.dx, center.dy + size * 0.4);

    canvas.drawPath(path, paint);
  }

  void _drawAtom(Canvas canvas, Offset center, double size, Paint paint) {
    // Central nucleus
    final nucleusPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, nucleusPaint);

    // Orbit 1
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 1.8,
        height: size * 0.6,
      ),
      paint,
    );
    canvas.restore();

    // Orbit 2
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 1.8,
        height: size * 0.6,
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawPencil(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.78); // 45 degrees

    // Body
    path.addRect(
      Rect.fromLTRB(-size * 0.15, -size * 0.6, size * 0.15, size * 0.4),
    );
    // Tip
    path.moveTo(-size * 0.15, -size * 0.6);
    path.lineTo(0, -size * 0.95);
    path.lineTo(size * 0.15, -size * 0.6);
    // Eraser
    path.moveTo(-size * 0.15, size * 0.4);
    path.lineTo(-size * 0.15, size * 0.6);
    path.quadraticBezierTo(0, size * 0.75, size * 0.15, size * 0.6);
    path.lineTo(size * 0.15, size * 0.4);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawBulb(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    // Bulb head curve
    path.arcTo(
      Rect.fromCircle(center: center, radius: size * 0.6),
      0.8, // startAngle
      4.68, // sweepAngle
      true,
    );
    // Connect to screw base
    path.lineTo(center.dx + size * 0.25, center.dy + size * 0.7);
    path.lineTo(center.dx - size * 0.25, center.dy + size * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    // Threads at bottom
    canvas.drawLine(
      Offset(center.dx - size * 0.2, center.dy + size * 0.78),
      Offset(center.dx + size * 0.2, center.dy + size * 0.78),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - size * 0.15, center.dy + size * 0.86),
      Offset(center.dx + size * 0.15, center.dy + size * 0.86),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
