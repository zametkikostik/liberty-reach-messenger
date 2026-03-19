import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/profile_provider.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';

/// 👤 Setup Profile Screen
///
/// Minimalist profile setup with:
/// - Avatar upload (IPFS via Pinata)
/// - Full name input
/// - Ghost/Love adaptive theme
class SetupProfileScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const SetupProfileScreen({super.key, this.onComplete});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  final _storageService = StorageService();

  bool _isLoading = false;
  String? _avatarPreview;
  String? _avatarCid;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Pick and crop avatar image
  Future<void> _pickAvatar() async {
    try {
      final ImageSource source = await showDialog<ImageSource>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Avatar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ) ??
          ImageSource.gallery;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Crop image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() => _isLoading = true);

      // Upload to IPFS
      final cid = await _storageService.uploadAvatar(File(croppedFile.path));
      
      setState(() {
        _avatarCid = cid;
        _avatarPreview = pickedFile.path;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Avatar uploaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save profile
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      
      await profileProvider.setFullName(_nameController.text);
      if (_avatarCid != null) {
        await profileProvider.setAvatarCid(_avatarCid!);
      }
      await profileProvider.setBio(_bioController.text);

      if (mounted) {
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeService.isGhostMode
                ? [
                    const Color(0xFF0A0A0F),
                    const Color(0xFF1A1A2E),
                  ]
                : [
                    const Color(0xFF0F0A0F),
                    const Color(0xFF2E1A2E),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Header
                Text(
                  'Complete Your Profile',
                  style: GoogleFonts.firaCode(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how others will see you',
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 48),

                // Avatar Section
                GestureDetector(
                  onTap: _isLoading ? null : _pickAvatar,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _avatarPreview != null ? colors : [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: _avatarPreview != null
                            ? colors[0]
                            : Colors.white.withOpacity(0.2),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: _avatarPreview != null
                          ? Image.file(
                              File(_avatarPreview!),
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Colors.white.withOpacity(0.5),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  _avatarPreview != null ? 'Tap to change' : 'Tap to upload',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: colors[0],
                  ),
                ),

                const SizedBox(height: 48),

                // Name Input
                _buildInputField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'John Doe',
                  icon: Icons.person,
                  autofocus: true,
                ),

                const SizedBox(height: 24),

                // Bio Input
                _buildInputField(
                  controller: _bioController,
                  label: 'Bio (Optional)',
                  hint: 'Tell us about yourself...',
                  icon: Icons.info_outline,
                  maxLines: 3,
                ),

                const SizedBox(height: 48),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors[0],
                      foregroundColor: themeService.isGhostMode
                          ? const Color(0xFF0A0A0F)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: GoogleFonts.firaCode(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip Button
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          widget.onComplete?.call();
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool autofocus = false,
    int maxLines = 1,
  }) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLines: maxLines,
            style: GoogleFonts.firaCode(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.firaCode(
                color: Colors.white.withOpacity(0.3),
              ),
              prefixIcon: Icon(icon, color: colors[0]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}
