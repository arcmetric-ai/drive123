import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;
  String _roleLabel = 'Learner';
  bool _isVerified = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 24),
                  _buildSettingsSection(),
                  const SizedBox(height: 24),
                  _buildAccountActionsSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    backgroundImage: _avatarImage,
                    child: _avatarImage == null
                        ? Text(
                            _initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingImage)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(18.0),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _roleLabel,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Receive lesson reminders and updates',
              value: _notificationsEnabled,
              onChanged: (value) => setState(() => _notificationsEnabled = value),
            ),
            const Divider(),
            _buildSwitchTile(
              icon: Icons.location_on_outlined,
              title: 'Location Services',
              subtitle: 'Allow location access for nearby instructors',
              value: _locationEnabled,
              onChanged: (value) => setState(() => _locationEnabled = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              icon: Icons.history,
              title: 'Lesson History',
              subtitle: 'View all your past lessons',
              onTap: () => context.push(AppRoutes.myLessons),
            ),
            const Divider(),
            _buildActionTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help or contact support',
              onTap: () => context.push(AppRoutes.helpSupport),
            ),
            const Divider(),
            _buildActionTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version and information',
              onTap: _showAboutDialog,
            ),
            const Divider(),
            _buildActionTile(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Sign out of your account',
              onTap: _signOut,
              textColor: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.primaryBlue),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _loadProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserModel? profile = await SupabaseService.getUserProfile(user.id);
      if (!mounted) return;

      if (profile != null) {
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _emailController.text = profile.email;
        _phoneController.text = profile.phone ?? '';
        _profileImageUrl = profile.profileImageUrl;
        _isVerified = profile.isVerified;
        _roleLabel = _formatRole(profile.role);
      } else {
        _emailController.text = user.email ?? '';
        _roleLabel = _formatRole(user.userMetadata?['role'] as String?);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No signed-in user found.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _isLoading = true);

    try {
      await SupabaseService.updateProfileFields(userId, {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone.isNotEmpty ? phone : null,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to update your photo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final selectedFile = File(image.path);

    setState(() {
      _profileImage = selectedFile;
      _isUploadingImage = true;
    });

    try {
      final uploadedUrl = await SupabaseService.uploadProfileImage(
        userId: userId,
        file: selectedFile,
      );

      if (!mounted) return;

      setState(() {
        _profileImageUrl = uploadedUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService.signOut();
              if (!mounted) return;
              context.go(AppRoutes.roleSelection);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Drive T',
      applicationVersion: '1.0.0',
      children: const [
        Text('A friendly platform connecting driving learners with verified instructors in Ontario.'),
      ],
    );
  }

  ImageProvider<Object>? get _avatarImage {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  String get _displayName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final name = [first, last].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Your name' : name;
  }

  String get _initials {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final initials = (first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : '');
    if (initials.isEmpty) return 'DT';
    return initials.toUpperCase();
  }

  String _formatRole(String? role) {
    final value = (role ?? 'learner').trim();
    if (value.isEmpty) return 'Learner';
    return value[0].toUpperCase() + value.substring(1);
  }
}
