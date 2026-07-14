import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'dashboard_screen.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';

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
      case 'Guest':
        return 'guest';
      default:
        return 'student';
    }
  }

  bool _isLoading = false;

  void _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authService = AuthService();
      
      const email = "guest@bookmyfest.co";
      const password = "guestpassword123";
      
      Map<String, dynamic> loginResponse;
      try {
        // Attempt to log in with static guest credentials
        loginResponse = await authService.login(email, password);
      } catch (e) {
        // If login fails (user doesn't exist yet), register once behind the scenes
        await authService.register(
          fullName: "Guest User",
          email: email,
          password: password,
          role: "guest",
          collegeName: "",
          department: "",
          idProofUrl: "",
          isFinalYear: false,
        );
        // Login again after registration
        loginResponse = await authService.login(email, password);
      }
      
      final token = loginResponse['data']['token'];
      final user = loginResponse['data']['user'];
      
      userProvider.setSession(token, user);
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guest mode failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Create 5 staggered animations (one for each card)
    _animations = List.generate(5, (index) {
      final start = index * 0.1;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
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
                          const Spacer(),

                          // Grid/Stack Layout centered
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 380,
                                maxWidth: 360,
                              ),
                              child: Builder(
                                builder: (context) {
                                  double W = 300;
                                  double H = 300;
                                  double centerSize = 108;
                                  double centerRadius = centerSize / 2;

                                  return Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Staggered entry animation for the main grid panel
                                      AnimatedBuilder(
                                        animation: _animations[0],
                                        builder: (context, child) {
                                          final val = _animations[0].value;
                                          final scale = 0.85 + (val * 0.15);
                                          final slideY = (1.0 - val) * 60.0;
                                          return Transform(
                                            transform:
                                                Matrix4.translationValues(
                                                  0.0,
                                                  slideY,
                                                  0.0,
                                                ) *
                                                Matrix4.diagonal3Values(
                                                  scale,
                                                  scale,
                                                  1.0,
                                                ),
                                            alignment: Alignment.center,
                                            child: Opacity(
                                              opacity: val.clamp(0.0, 1.0),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: W,
                                          height: H,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(32),
                                            border: Border.all(
                                              color: appBarColor,
                                              width: 2.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // 1. Grid Lines
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: GridLinesPainter(
                                                    color: appBarColor,
                                                    centerRadius: centerRadius,
                                                  ),
                                                ),
                                              ),

                                              // 2. Quadrants
                                              // Top-Left: Faculty
                                              Positioned(
                                                left: 0,
                                                top: 0,
                                                width: W / 2,
                                                height: H / 2,
                                                child: _buildQuadrant(
                                                  context,
                                                  title: "Faculty",
                                                  iconData: Icons.person_outline_rounded,
                                                  iconColor: appBarColor,
                                                  alignment: const Alignment(-0.2, -0.2),
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(30),
                                                  ),
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => LoginScreen(
                                                        selectedRole: _getRoleParamValue(
                                                          "Faculty",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Top-Right: Coordinator
                                              Positioned(
                                                left: W / 2,
                                                top: 0,
                                                width: W / 2,
                                                height: H / 2,
                                                child: _buildQuadrant(
                                                  context,
                                                  title: "Coordinator",
                                                  iconData: Icons.groups_outlined,
                                                  iconColor: appBarColor,
                                                  alignment: const Alignment(0.2, -0.2),
                                                  borderRadius: const BorderRadius.only(
                                                    topRight: Radius.circular(30),
                                                  ),
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => LoginScreen(
                                                        selectedRole: _getRoleParamValue(
                                                          "Coordinator",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Bottom-Left: Guest
                                              Positioned(
                                                left: 0,
                                                top: H / 2,
                                                width: W / 2,
                                                height: H / 2,
                                                child: _buildQuadrant(
                                                  context,
                                                  title: "Guest",
                                                  iconData: Icons.visibility_outlined,
                                                  iconColor: appBarColor,
                                                  alignment: const Alignment(-0.2, 0.2),
                                                  borderRadius: const BorderRadius.only(
                                                    bottomLeft: Radius.circular(30),
                                                  ),
                                                  onTap: _handleGuestLogin,
                                                ),
                                              ),

                                              // Bottom-Right: Super Admin
                                              Positioned(
                                                left: W / 2,
                                                top: H / 2,
                                                width: W / 2,
                                                height: H / 2,
                                                child: _buildQuadrant(
                                                  context,
                                                  title: "Super Admin",
                                                  iconData:
                                                      Icons.manage_accounts_outlined,
                                                  iconColor: appBarColor,
                                                  alignment: const Alignment(0.2, 0.2),
                                                  borderRadius: const BorderRadius.only(
                                                    bottomRight: Radius.circular(30),
                                                  ),
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => LoginScreen(
                                                        selectedRole: _getRoleParamValue(
                                                          "Super Admin",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // 3. Center Circular Card: Student
                                      _buildCenterCard(
                                        context,
                                        title: "Student",
                                        iconData: Icons.badge_outlined,
                                        iconColor: appBarColor,
                                        size: centerSize,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Small footer text
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "BUILT FOR STUDENTS. POWERED BY RONAGATECH",
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
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: widget.brandColor),
                          const SizedBox(height: 16),
                          const Text(
                            "Entering Guest Mode...",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
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

  Widget _buildQuadrant(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required Color iconColor,
    required Alignment alignment,
    required BorderRadius borderRadius,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Align(
          alignment: alignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSketchIcon(title, iconData, iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSketchIcon(String title, IconData iconData, Color iconColor) {
    if (title == "Super Admin") {
      // Outlined person/gear shape (no extra boundary shape)
      return Icon(iconData, size: 42, color: iconColor);
    } else if (title == "Coordinator") {
      // Outlined groups shape (three people)
      return Icon(iconData, size: 44, color: iconColor);
    } else if (title == "Faculty") {
      // Faculty is outline person inside dome/arch
      return Container(
        padding: const EdgeInsets.only(top: 6, left: 10, right: 10, bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: iconColor, width: 1.8),
            left: BorderSide(color: iconColor, width: 1.8),
            right: BorderSide(color: iconColor, width: 1.8),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Icon(iconData, size: 32, color: iconColor),
      );
    } else if (title == "Guest") {
      // Guest is outline eye inside circular border
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 1.8),
        ),
        child: Icon(iconData, size: 28, color: iconColor),
      );
    } else {
      return Icon(iconData, size: 36, color: iconColor);
    }
  }

  Widget _buildCenterCard(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required Color iconColor,
    required double size,
  }) {
    final animation = _animations[4];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value;
        final scale = 0.8 + (val * 0.2);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 2.2),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LoginScreen(selectedRole: _getRoleParamValue(title)),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, size: 34, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
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

class GridLinesPainter extends CustomPainter {
  final Color color;
  final double centerRadius;
  GridLinesPainter({required this.color, required this.centerRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Vertical line: top half
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - centerRadius), paint);
    // Vertical line: bottom half
    canvas.drawLine(
      Offset(cx, cy + centerRadius),
      Offset(cx, size.height),
      paint,
    );

    // Horizontal line: left half
    canvas.drawLine(Offset(0, cy), Offset(cx - centerRadius, cy), paint);
    // Horizontal line: right half
    canvas.drawLine(
      Offset(cx + centerRadius, cy),
      Offset(size.width, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GridLinesPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.centerRadius != centerRadius;
  }
}
