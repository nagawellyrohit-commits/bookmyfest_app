import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingResume = false;
  String? _uploadedResumeName;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _studentIdController = TextEditingController();

  // Job Profile controllers
  final _resumeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  final _linkedinUrlController = TextEditingController();
  final _branchController = TextEditingController();
  final _passingYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    _resumeController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _contactPhoneController.dispose();
    _websiteUrlController.dispose();
    _instagramUrlController.dispose();
    _linkedinUrlController.dispose();
    _branchController.dispose();
    _passingYearController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final profile = await _authService.getMe(userProvider.token!);
      
      // Update basic fields
      _fullNameController.text = profile['fullName'] ?? '';
      _phoneController.text = profile['phone'] ?? '';
      _departmentController.text = profile['department'] ?? '';
      _studentIdController.text = profile['studentId'] ?? '';

      // Update job profile fields
      if (profile['jobProfile'] != null) {
        final jp = profile['jobProfile'];
        final resumeVal = jp['resumeUrl'];
        _resumeController.text = (resumeVal != null && resumeVal != 'No resume link provided') ? resumeVal : '';
        _businessNameController.text = jp['businessName'] ?? '';
        _descriptionController.text = jp['description'] ?? '';
        _contactPhoneController.text = jp['contactPhone'] ?? '';
        _websiteUrlController.text = jp['websiteUrl'] ?? '';
        _instagramUrlController.text = jp['instagramUrl'] ?? '';
        _linkedinUrlController.text = jp['linkedinUrl'] ?? '';
        _branchController.text = jp['branch'] ?? '';
        _passingYearController.text = jp['passingYear'] != null ? jp['passingYear'].toString() : '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading profile: $e"), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Call update API
      final response = await _authService.updateProfile(
        userProvider.token!,
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        department: _departmentController.text,
        studentId: userProvider.role == 'student' ? _studentIdController.text : null,
        resumeUrl: _resumeController.text.isNotEmpty ? _resumeController.text : null,
        businessName: _businessNameController.text.isNotEmpty ? _businessNameController.text : null,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        contactPhone: _contactPhoneController.text.isNotEmpty ? _contactPhoneController.text : null,
        websiteUrl: _websiteUrlController.text.isNotEmpty ? _websiteUrlController.text : null,
        instagramUrl: _instagramUrlController.text.isNotEmpty ? _instagramUrlController.text : null,
        linkedinUrl: _linkedinUrlController.text.isNotEmpty ? _linkedinUrlController.text : null,
        branch: _branchController.text.isNotEmpty ? _branchController.text : null,
        passingYear: _passingYearController.text.isNotEmpty ? int.tryParse(_passingYearController.text) : null,
      );

      // Refresh local UserProvider session
      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        // Re-inject college info if present
        if (userData != null) {
          userData['college'] = { "name": userProvider.collegeName };
          userProvider.setSession(userProvider.token!, userData);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving profile: $e"), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadResume() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) return;

      final file = result.files.single;
      final fileBytes = file.bytes;
      final fileName = file.name;

      if (fileBytes == null) {
        throw Exception("Could not read file data. Please try another PDF.");
      }

      // Strict 20MB size limit validation on client
      const maxLimit = 20 * 1024 * 1024;
      if (fileBytes.length > maxLimit) {
        throw Exception("File size exceeds 20MB limit. Please choose a smaller PDF.");
      }

      // Strict PDF extension validation on client
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        throw Exception("Only PDF format (.pdf) files are allowed!");
      }

      setState(() {
        _isUploadingResume = true;
      });

      // Upload file to server
      final fileUrl = await _authService.uploadPdf(fileBytes, fileName);

      setState(() {
        _resumeController.text = fileUrl;
        _uploadedResumeName = fileName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF CV uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingResume = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isStudent = userProvider.role == 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgorund.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Personal Details",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _fullNameController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: AppTheme.inputDecoration(
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: AppTheme.inputDecoration(
                              labelText: "Phone Number (Optional)",
                              prefixIcon: Icons.phone_outlined,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return null;
                              }
                              if (val.length != 10) {
                                return "Phone number must be exactly 10 digits";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _departmentController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: AppTheme.inputDecoration(
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
                          if (isStudent) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _studentIdController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: AppTheme.inputDecoration(
                                labelText: "Student ID / Roll Number",
                                prefixIcon: Icons.card_membership_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "Please enter your Student ID";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              "Job / Startup Profile (Optional)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: AppTheme.cardDecoration(),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _businessNameController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Business/Startup Name",
                                      prefixIcon: Icons.business_center_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _descriptionController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Description of what company does",
                                      prefixIcon: Icons.description_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _contactPhoneController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Business Contact Phone",
                                      prefixIcon: Icons.phone_android_outlined,
                                    ),
                                    validator: (val) {
                                      if (val != null && val.isNotEmpty && val.length != 10) {
                                        return "Phone number must be exactly 10 digits";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _websiteUrlController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Webpage Link",
                                      prefixIcon: Icons.web_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _instagramUrlController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Instagram Link",
                                      prefixIcon: Icons.camera_alt_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _linkedinUrlController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "LinkedIn Link",
                                      prefixIcon: Icons.link_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _branchController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Branch/Field",
                                      prefixIcon: Icons.school_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passingYearController,
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                    decoration: AppTheme.inputDecoration(
                                      labelText: "Passing Out Year",
                                      prefixIcon: Icons.calendar_today_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // CV PDF Upload UI
                                  _isUploadingResume
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8.0),
                                            child: CircularProgressIndicator(color: AppTheme.primary),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.surface,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFF334155), width: 1),
                                          ),
                                          child: InkWell(
                                            onTap: _pickAndUploadResume,
                                            borderRadius: BorderRadius.circular(16),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.picture_as_pdf_outlined,
                                                    color: _resumeController.text.isNotEmpty
                                                        ? Colors.green
                                                        : AppTheme.primary,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          _uploadedResumeName != null
                                                              ? "Selected: $_uploadedResumeName"
                                                              : (_resumeController.text.isNotEmpty
                                                                  ? "Resume Uploaded"
                                                                  : "Upload CV PDF (Max 20MB, PDF Only)"),
                                                          style: TextStyle(
                                                            color: _resumeController.text.isNotEmpty
                                                                ? Colors.green
                                                                : AppTheme.textPrimary,
                                                            fontWeight: _resumeController.text.isNotEmpty
                                                                ? FontWeight.bold
                                                                : FontWeight.normal,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        if (_resumeController.text.isNotEmpty)
                                                          const SizedBox(height: 2),
                                                        if (_resumeController.text.isNotEmpty)
                                                          const Text(
                                                            "Tap to replace the file",
                                                            style: TextStyle(
                                                              color: AppTheme.textSecondary,
                                                              fontSize: 11,
                                                              ),
                                                            ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_resumeController.text.isNotEmpty)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                    )
                                                  else
                                                    const Icon(
                                                      Icons.upload_file_outlined,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          _isSaving
                              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  onPressed: _saveProfile,
                                  child: const Text("Save Changes"),
                                ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
