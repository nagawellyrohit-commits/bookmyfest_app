import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialRole;
  const RegisterScreen({super.key, this.initialRole});

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
  final _studentIdController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  final _linkedinUrlController = TextEditingController();
  final _branchController = TextEditingController();
  final _passingYearController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late String _selectedRole;

  final Color _brandColor = const Color(0xFFD30014); // Bennett Crimson Red

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'student';
  }

  // Display name helper for roles in UI
  String _getRoleDisplayName() {
    switch (_selectedRole) {
      case 'student':
        return 'Student';
      case 'coordinator':
        return 'Coordinator';
      case 'faculty_admin':
        return 'Faculty';
      case 'super_admin':
        return 'Super Admin';
      default:
        return 'User';
    }
  }

  // ID Proof field label helper
  String _getIdProofLabel() {
    switch (_selectedRole) {
      case 'student':
        return "Student ID Card Proof URL (Optional)";
      case 'coordinator':
        return "Coordinator ID Card Proof URL (Optional)";
      case 'faculty_admin':
        return "Faculty ID Card Proof URL (Optional)";
      default:
        return "ID Proof URL (Optional)";
    }
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isSuperAdmin = _selectedRole == 'super_admin';
      final isStudent = _selectedRole == 'student';

      await _authService.register(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        collegeName: !isSuperAdmin ? _collegeNameController.text : "N/A",
        department: !isSuperAdmin ? _departmentController.text : "N/A",
        idProofUrl: !isSuperAdmin && _idProofController.text.isNotEmpty
            ? _idProofController.text
            : "https://via.placeholder.com/150",
        isFinalYear: false,
        resumeUrl: isStudent && _resumeController.text.isNotEmpty
            ? _resumeController.text
            : null,
        studentId: isStudent ? _studentIdController.text : null,
        businessName: isStudent && _businessNameController.text.isNotEmpty
            ? _businessNameController.text
            : null,
        description: isStudent && _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        contactPhone: isStudent && _contactPhoneController.text.isNotEmpty
            ? _contactPhoneController.text
            : null,
        websiteUrl:
            isStudent && _websiteUrlController.text.isNotEmpty
            ? _websiteUrlController.text
            : null,
        instagramUrl:
            isStudent && _instagramUrlController.text.isNotEmpty
            ? _instagramUrlController.text
            : null,
        linkedinUrl:
            isStudent && _linkedinUrlController.text.isNotEmpty
            ? _linkedinUrlController.text
            : null,
        branch: isStudent && _branchController.text.isNotEmpty
            ? _branchController.text
            : null,
        passingYear:
            isStudent && _passingYearController.text.isNotEmpty
            ? int.tryParse(_passingYearController.text)
            : null,
      );

      if (mounted) {
        String successMsg = "Registration completed successfully!";
        if (_selectedRole == 'coordinator' ||
            _selectedRole == 'faculty_admin') {
          successMsg =
              "Registration successful! Your account is pending manual faculty verification.";
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Success",
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              successMsg,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to login screen
                },
                child: Text(
                  "OK",
                  style: TextStyle(
                    color: _brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: _brandColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final isSuperAdmin = _selectedRole == 'super_admin';
    final isStudent = _selectedRole == 'student';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _brandColor,
        elevation: 0,
        title: const Text(
          "Create Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header text
                  Text(
                    "Register as ${_getRoleDisplayName()}",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Provide your credentials to establish your profile",
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 30),

                  // Forms wrapper
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
                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          decoration: _lightInputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Please enter your name";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _lightInputDecoration(
                            labelText: "Email Address",
                            prefixIcon: Icons.email_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Please enter your email";
                            }
                            if (!val.contains("@")) {
                              return "Invalid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          obscureText: _obscurePassword,
                          decoration: _lightInputDecoration(
                            labelText: "Password",
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Please enter a password";
                            }
                            if (val.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          keyboardType: TextInputType.phone,
                          decoration: _lightInputDecoration(
                            labelText: "Phone Number",
                            prefixIcon: Icons.phone_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Please enter your phone number";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Student ID (Only for Student Role)
                        if (isStudent) ...[
                          TextFormField(
                            controller: _studentIdController,
                            style: const TextStyle(color: Color(0xFF1E293B)),
                            decoration: _lightInputDecoration(
                              labelText: "Student ID / Roll Number",
                              prefixIcon: Icons.badge_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Please enter your Student ID";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // College Name (Only if NOT Super Admin)
                        if (!isSuperAdmin) ...[
                          TextFormField(
                            controller: _collegeNameController,
                            style: const TextStyle(color: Color(0xFF1E293B)),
                            decoration: _lightInputDecoration(
                              labelText: "College Name",
                              prefixIcon: Icons.apartment_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Please enter your college name";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _departmentController,
                            style: const TextStyle(color: Color(0xFF1E293B)),
                            decoration: _lightInputDecoration(
                              labelText: "Department / Major",
                              prefixIcon: Icons.badge_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Please enter your department";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ID Proof Link (Optional)
                          TextFormField(
                            controller: _idProofController,
                            style: const TextStyle(color: Color(0xFF1E293B)),
                            decoration: _lightInputDecoration(
                              labelText: _getIdProofLabel(),
                              prefixIcon: Icons.attachment_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Optional Job/Startup Profile (Students Only)
                        if (isStudent) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _brandColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Job / Startup Profile (Optional)",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _brandColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Note: Fill these details if you wish to share startup/job details.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _businessNameController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Business/Startup Name (Optional)",
                                      prefixIcon: Icons.business_center_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _descriptionController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Description of what company does (Optional)",
                                      prefixIcon: Icons.description_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _contactPhoneController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    decoration: _lightInputDecoration(
                                      labelText: "Business Contact Phone Number (Optional)",
                                      prefixIcon: Icons.phone_android_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _resumeController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Resume/CV Link (PDF Format, Optional)",
                                      prefixIcon: Icons.picture_as_pdf_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _websiteUrlController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Webpage Link (Optional)",
                                      prefixIcon: Icons.web_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _instagramUrlController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Instagram Link (Optional)",
                                      prefixIcon: Icons.camera_alt_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _linkedinUrlController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "LinkedIn Link (Optional)",
                                      prefixIcon: Icons.link_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _branchController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    decoration: _lightInputDecoration(
                                      labelText: "Branch/Field (Optional)",
                                      prefixIcon: Icons.school_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passingYearController,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: _lightInputDecoration(
                                      labelText: "Passing Out Year (Optional)",
                                      prefixIcon: Icons.calendar_today_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        const SizedBox(height: 10),

                        // Sign Up Submit Button
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: _brandColor,
                                ),
                              )
                            : Container(
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: _register,
                                  child: const Text(
                                    "Create Account",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Sign In",
                          style: TextStyle(
                            color: _brandColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
