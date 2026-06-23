import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 1; // 1: Email, 2: Verification Code, 3: Reset Password
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final Color _brandColor = const Color(0xff9708AA);

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      _showSnackBar("Please enter a valid email address", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.forgotPassword(_emailController.text.trim());
      _showSnackBar(response['message'] ?? "Reset code sent to your email", Colors.green);
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      _showSnackBar(e.toString(), _brandColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      _showSnackBar("Please enter the 6-digit verification code", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.verifyResetCode(
        _emailController.text.trim(),
        _codeController.text.trim(),
      );
      _showSnackBar(response['message'] ?? "Code verified successfully", Colors.green);
      setState(() {
        _currentStep = 3;
      });
    } catch (e) {
      _showSnackBar(e.toString(), _brandColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("Passwords do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.resetPassword(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );

      _showSnackBar(response['message'] ?? "Password reset successful", Colors.green);

      // Show success dialog and navigate back
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text("Your password has been reset successfully. You can now log in with your new password."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // go back to login screen
                },
                child: Text("Go to Sign In", style: TextStyle(color: _brandColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar(e.toString(), _brandColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  InputDecoration _lightInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: _brandColor, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _brandColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _brandColor,
        elevation: 0,
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Image same as Sign In for design coherence
          Positioned.fill(
            child: Image.asset('assets/images/signin.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header Logo Circle
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: _brandColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _brandColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        "bookmyfest",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentStep == 1
                            ? "Step 1 of 3: Enter Registered Email"
                            : _currentStep == 2
                                ? "Step 2 of 3: Enter Code Sent to Email"
                                : "Step 3 of 3: Set New Password",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Card containing the form fields
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _currentStep == 1
                                  ? "Forgot Password"
                                  : _currentStep == 2
                                      ? "Verify Reset Code"
                                      : "Reset Password",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (_currentStep == 1) ...[
                              // STEP 1 UI
                              const Text(
                                "Enter the email address associated with your account, and we'll send you a 6-digit verification code to reset your password.",
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Color(0xFF1E293B)),
                                keyboardType: TextInputType.emailAddress,
                                decoration: _lightInputDecoration(
                                  labelText: "Email Address",
                                  prefixIcon: Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 30),
                              _buildButton(
                                label: "Send Code",
                                onPressed: _sendCode,
                              ),
                            ] else if (_currentStep == 2) ...[
                              // STEP 2 UI
                              Text(
                                "We have sent a 6-digit verification code to:\n${_emailController.text}\nPlease enter the code below to proceed.",
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _codeController,
                                style: const TextStyle(color: Color(0xFF1E293B)),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: _lightInputDecoration(
                                  labelText: "6-Digit Code",
                                  prefixIcon: Icons.pin_outlined,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentStep = 1;
                                        _codeController.clear();
                                      });
                                    },
                                    child: Text(
                                      "Change Email",
                                      style: TextStyle(color: _brandColor, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _sendCode,
                                    child: Text(
                                      "Resend Code",
                                      style: TextStyle(color: _brandColor, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildButton(
                                label: "Verify Code",
                                onPressed: _verifyCode,
                              ),
                            ] else if (_currentStep == 3) ...[
                              // STEP 3 UI
                              const Text(
                                "Create a strong new password for your account.",
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                style: const TextStyle(color: Color(0xFF1E293B)),
                                obscureText: _obscurePassword,
                                decoration: _lightInputDecoration(
                                  labelText: "New Password",
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Please enter a new password";
                                  }
                                  if (val.length < 6) {
                                    return "Password must be at least 6 characters";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _confirmPasswordController,
                                style: const TextStyle(color: Color(0xFF1E293B)),
                                obscureText: _obscureConfirmPassword,
                                decoration: _lightInputDecoration(
                                  labelText: "Confirm Password",
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "Please confirm your password";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              _buildButton(
                                label: "Reset Password",
                                onPressed: _resetPassword,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required String label, required VoidCallback onPressed}) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _brandColor,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _brandColor,
            _brandColor.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _brandColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
