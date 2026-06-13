import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _collegeNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _idProofController = TextEditingController();
  final _resumeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Selected role
  String _selectedRole = 'student';
  final List<String> _roles = ['student', 'coordinator', 'faculty_admin', 'super_admin'];

  // Final year toggle
  bool _isFinalYear = false;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authService.register(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        collegeName: _collegeNameController.text,
        department: _departmentController.text,
        idProofUrl: _idProofController.text.isNotEmpty ? _idProofController.text : "https://via.placeholder.com/150",
        isFinalYear: _isFinalYear,
        resumeUrl: _isFinalYear ? _resumeController.text : null,
      );

      if (mounted) {
        String successMsg = "Registration completed successfully!";
        if (_selectedRole == 'coordinator' || _selectedRole == 'faculty_admin') {
          successMsg = "Registration successful! Your coordinator/admin account is pending manual faculty verification.";
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text("Success", style: TextStyle(color: AppTheme.textPrimary)),
            content: Text(successMsg, style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to login screen
                },
                child: const Text("OK", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkBackgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Join the multi-college network",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Forms wrapper
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Dropdown for Role Selection
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: AppTheme.inputDecoration(
                              labelText: "Account Role Type",
                              prefixIcon: Icons.admin_panel_settings_outlined,
                            ),
                            items: _roles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.replaceAll('_', ' ').toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRole = val;
                                  if (val != 'student') {
                                    _isFinalYear = false;
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // Full Name
                          TextFormField(
                            controller: _fullNameController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: AppTheme.inputDecoration(
                              labelText: "Full Name",
                              prefixIcon: Icons.person_outline,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Please enter your name";
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            keyboardType: TextInputType.emailAddress,
                            decoration: AppTheme.inputDecoration(
                              labelText: "Email Address",
                              prefixIcon: Icons.email_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Please enter your email";
                              if (!val.contains("@")) return "Invalid email address";
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            obscureText: _obscurePassword,
                            decoration: AppTheme.inputDecoration(
                              labelText: "Password",
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Please enter a password";
                              if (val.length < 6) return "Password must be at least 6 characters";
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Phone Number
                          TextFormField(
                            controller: _phoneController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            keyboardType: TextInputType.phone,
                            decoration: AppTheme.inputDecoration(
                              labelText: "Phone Number",
                              prefixIcon: Icons.phone_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Please enter your phone number";
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // College Name (Only if NOT Super Admin)
                          if (_selectedRole != 'super_admin') ...[
                            TextFormField(
                              controller: _collegeNameController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: AppTheme.inputDecoration(
                                labelText: "College Name",
                                prefixIcon: Icons.apartment_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return "Please enter your college name";
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _departmentController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: AppTheme.inputDecoration(
                                labelText: "Department / Major",
                                prefixIcon: Icons.badge_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return "Please enter your department";
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // ID Proof Link
                            TextFormField(
                              controller: _idProofController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: AppTheme.inputDecoration(
                                labelText: "Student ID Card Proof URL (Optional)",
                                prefixIcon: Icons.attachment_outlined,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Final Year Toggle (Students Only)
                          if (_selectedRole == 'student') ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Are you in your Final Year?",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Switch(
                                  value: _isFinalYear,
                                  activeColor: AppTheme.primary,
                                  onChanged: (val) {
                                    setState(() => _isFinalYear = val);
                                  },
                                ),
                              ],
                            ),
                            
                            // Expandable Job Profile section
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        "Final Year Job Profile Collection",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        "Note: This data is restricted to the client company/super admin.",
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _resumeController,
                                        style: const TextStyle(color: AppTheme.textPrimary),
                                        decoration: AppTheme.inputDecoration(
                                          labelText: "Resume/CV Link (PDF Format)",
                                          prefixIcon: Icons.picture_as_pdf_outlined,
                                        ),
                                        validator: (val) {
                                          if (_isFinalYear && (val == null || val.isEmpty)) {
                                            return "Please provide a resume URL";
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              crossFadeState: _isFinalYear ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                            ),
                            const SizedBox(height: 30),
                          ],

                          // Sign Up Submit Button
                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                    ),
                                    onPressed: _register,
                                    child: const Text("Create Account"),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account?",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Sign In",
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
