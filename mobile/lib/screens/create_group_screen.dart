import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/group_chats_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../providers/profile_provider.dart';

/// 👥 Create Group Screen
///
/// Create a new group chat with:
/// - Group name and description
/// - Group avatar
/// - Privacy settings (public/private)
/// - Initial member selection
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final GroupChatsService _groupService = GroupChatsService.instance;
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  String? _avatarCid;
  File? _avatarFile;
  bool _isPublic = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _avatarFile = File(image.path);
        _isLoading = true;
      });

      // Upload to IPFS
      final cid = await _storageService.uploadAvatar(_avatarFile!);
      
      setState(() {
        _avatarCid = cid;
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

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final ownerId = profileProvider.initials ?? 'me'; // TODO: Get real user ID

      final group = await _groupService.createGroup(
        name: _nameController.text.trim(),
        ownerId: ownerId,
        description: _descriptionController.text.trim(),
        avatarCid: _avatarCid,
        isPublic: _isPublic,
      );

      if (group != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Group created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, group);
      } else {
        throw Exception('Failed to create group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
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
      appBar: AppBar(
        title: Text(
          'Create Group',
          style: GoogleFonts.firaCode(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: Text(
              'Create',
              style: GoogleFonts.firaCode(
                color: colors[0],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickAvatar,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _avatarFile != null
                          ? null
                          : LinearGradient(colors: colors),
                      image: _avatarFile != null
                          ? DecorationImage(
                              image: FileImage(_avatarFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: colors[0],
                        width: 3,
                      ),
                    ),
                    child: _avatarFile == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to upload avatar',
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: colors[0],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Group name
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.firaCode(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(Icons.group, color: colors[0]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  if (value.trim().length < 2) {
                    return 'Group name must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.firaCode(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(Icons.info_outline, color: colors[0]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Privacy settings
              Text(
                'Privacy Settings',
                style: GoogleFonts.firaCode(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Public/Private toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      color: colors[0],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPublic ? 'Public Group' : 'Private Group',
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isPublic
                                ? 'Anyone can join via invite link'
                                : 'Invite only',
                            style: GoogleFonts.firaCode(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPublic,
                      onChanged: (value) {
                        setState(() => _isPublic = value);
                      },
                      activeColor: colors[0],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors[0].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors[0].withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors[0]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can add up to 1000 members to your group',
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
