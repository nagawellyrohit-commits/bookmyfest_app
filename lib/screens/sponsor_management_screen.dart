import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/sponsor_service.dart';
import '../services/auth_service.dart';

class SponsorManagementScreen extends StatefulWidget {
  const SponsorManagementScreen({super.key});

  @override
  State<SponsorManagementScreen> createState() => _SponsorManagementScreenState();
}

class _SponsorManagementScreenState extends State<SponsorManagementScreen> {
  final SponsorService _sponsorService = SponsorService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  List<dynamic> _sponsors = [];

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    setState(() => _isLoading = true);
    try {
      final sponsors = await _sponsorService.fetchSponsors();
      setState(() {
        _sponsors = sponsors;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching sponsors: $e"),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSponsor(String id) async {
    final user = Provider.of<UserProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Sponsor", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to remove this sponsor? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _sponsorService.deleteSponsor(user.token!, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sponsor removed successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadSponsors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e"), backgroundColor: AppTheme.accent),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEditSponsorSheet({Map<String, dynamic>? sponsor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditSponsorSheet(
        sponsor: sponsor,
        onSave: () {
          Navigator.pop(context);
          _loadSponsors();
        },
        sponsorService: _sponsorService,
        authService: _authService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Sponsors",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background illustration image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgorund.png',
              fit: BoxFit.cover,
            ),
          ),

          // Main contents
          _isLoading && _sponsors.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _loadSponsors,
                  color: AppTheme.primary,
                  child: _sponsors.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.business_rounded, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "No Sponsors Added Yet",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Add sponsors to show them on the welcome screen.",
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sponsors.length,
                          itemBuilder: (context, index) {
                            final sp = _sponsors[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                              ),
                              elevation: 2,
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        color: const Color(0xFFF1F5F9),
                                        child: sp['logoUrl'] != null && sp['logoUrl'].toString().isNotEmpty
                                            ? Image.network(
                                                sp['logoUrl'],
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary),
                                              )
                                            : const Icon(Icons.business_outlined, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (sp['name'] != null && sp['name'].toString().isNotEmpty)
                                            Text(
                                              sp['name'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            )
                                          else if (sp['subtitle'] != null && sp['subtitle'].toString().isNotEmpty && sp['subtitle'].toString().startsWith('http')) ...[
                                            const Text(
                                              "Name Image Sponsor",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              height: 24,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Image.network(
                                                sp['subtitle'],
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Text("Error loading name image", style: TextStyle(fontSize: 10, color: AppTheme.accent)),
                                              ),
                                            )
                                          ] else
                                            const Text(
                                              "Logo-Only Sponsor",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.normal,
                                                fontStyle: FontStyle.italic,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                      onPressed: () => _showAddEditSponsorSheet(sponsor: sp),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent),
                                      onPressed: () => _deleteSponsor(sp['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
          if (_isLoading && _sponsors.isNotEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSponsorSheet(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Sponsor",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _AddEditSponsorSheet extends StatefulWidget {
  final Map<String, dynamic>? sponsor;
  final VoidCallback onSave;
  final SponsorService sponsorService;
  final AuthService authService;

  const _AddEditSponsorSheet({
    this.sponsor,
    required this.onSave,
    required this.sponsorService,
    required this.authService,
  });

  @override
  State<_AddEditSponsorSheet> createState() => _AddEditSponsorSheetState();
}

class _AddEditSponsorSheetState extends State<_AddEditSponsorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _logoUrlController = TextEditingController();

  bool _isUploading = false;
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.sponsor != null) {
      _nameController.text = widget.sponsor!['name'] ?? '';
      _logoUrlController.text = widget.sponsor!['logoUrl'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                "Select Sponsor Logo Source",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

      if (source == null) return;

      XFile? pickedFile;
      if (source == 'camera') {
        pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      } else {
        pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      }

      if (pickedFile == null) return;

      final fileName = pickedFile.name;
      final fileBytes = await pickedFile.readAsBytes();

      setState(() {
        _isUploading = true;
        _pickedFileBytes = fileBytes;
        _pickedFileName = fileName;
      });

      // Upload file to server using existing route
      final fileUrl = await widget.authService.uploadImage(fileBytes, fileName);

      setState(() {
        _logoUrlController.text = fileUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Logo uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _pickedFileBytes = null;
        _pickedFileName = null;
        _logoUrlController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image upload failed: $e"), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final String finalName = _nameController.text.trim();
    final String finalLogoUrl = _logoUrlController.text.trim();

    setState(() => _isSaving = true);
    final user = Provider.of<UserProvider>(context, listen: false);

    try {
      if (widget.sponsor == null) {
        // Create mode
        await widget.sponsorService.createSponsor(
          user.token!,
          name: finalName,
          subtitle: null,
          logoUrl: finalLogoUrl,
        );
      } else {
        // Edit mode
        await widget.sponsorService.updateSponsor(
          user.token!,
          widget.sponsor!['id'],
          name: finalName,
          subtitle: "", // Clear name graphic subtitle
          logoUrl: finalLogoUrl,
        );
      }
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e"), backgroundColor: AppTheme.accent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.sponsor != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? "Edit Sponsor" : "Add Sponsor",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: AppTheme.inputDecoration(
                  labelText: "Sponsor Name",
                  prefixIcon: Icons.business_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter sponsor name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Logo Picker UI
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                  child: Text(
                    "Sponsor Logo (Optional)",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              _isUploading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _logoUrlController.text.isNotEmpty ? Colors.green : const Color(0xFFCBD5E1),
                          width: _logoUrlController.text.isNotEmpty ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    color: _logoUrlController.text.isNotEmpty ? Colors.green : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _pickedFileName != null
                                              ? "Selected: $_pickedFileName"
                                              : (_logoUrlController.text.isNotEmpty
                                                  ? "Sponsor Logo Selected"
                                                  : "Tap to select logo image"),
                                          style: TextStyle(
                                            color: _logoUrlController.text.isNotEmpty ? Colors.green : const Color(0xFF1E293B),
                                            fontWeight: _logoUrlController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "JPEG, JPG, PNG or WEBP up to 20MB",
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_logoUrlController.text.isNotEmpty)
                                    const Icon(Icons.check_circle, color: Colors.green)
                                  else
                                    const Icon(Icons.upload_file_outlined, color: Color(0xFF64748B)),
                                ],
                              ),
                              if (_pickedFileBytes != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 120,
                                    width: double.infinity,
                                    color: const Color(0xFFF8FAFC),
                                    child: Image.memory(_pickedFileBytes!, fit: BoxFit.contain),
                                  ),
                                ),
                              ] else if (_logoUrlController.text.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 120,
                                    width: double.infinity,
                                    color: const Color(0xFFF8FAFC),
                                    child: Image.network(_logoUrlController.text, fit: BoxFit.contain),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEdit ? "Save Changes" : "Create Sponsor",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
