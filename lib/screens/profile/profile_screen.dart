import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  String? _licenceNumber;
  DateTime? _licenceExpiry;
  String? _learnerCity;
  int? _learnerAge;
  String? _learnerGender;
  int? _learnerClassesTaken;
  DateTime? _learnerLastClassDate;
  DateTime? _learnerTestDate;
  String? _instructorServiceArea;
  String? _instructorBio;
  List<String> _instructorLanguages = [];
  List<String> _instructorOfferings = [];
  List<String> _instructorVehicles = [];
  List<String> _instructorAreas = [];
  List<String> _learnerLocations = [];
  List<String> _instructorLocations = [];
  String? _instructorLocationNotes;

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
                  if (_roleLabel == 'Learner')
                    _buildLearnerDetailsSection()
                  else
                    _buildInstructorDetailsSection(),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: _displayName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _emailController.text.isNotEmpty
                  ? _emailController.text
                  : (SupabaseService.currentUser?.email ?? 'Not provided'),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _phoneController.text.trim().isEmpty
                  ? 'Not provided'
                  : _phoneController.text.trim(),
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
              'Permissions',
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
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
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
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              subtitle: 'Update licence, questionnaire, and preferences',
              onTap: _openEditProfile,
            ),
            const Divider(),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnerDetailsSection() {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final licenceParts = <String>[];
    if (_licenceNumber != null && _licenceNumber!.isNotEmpty) {
      licenceParts.add('Number: $_licenceNumber');
    }
    if (_licenceExpiry != null) {
      licenceParts.add('Expiry: ${dateFormatter.format(_licenceExpiry!)}');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learner Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.credit_card,
              label: 'G1 Licence',
              value: licenceParts.isEmpty
                  ? 'Not provided'
                  : licenceParts.join(' • '),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'City',
              value: _learnerCity ?? 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Preferred Locations',
              value: _learnerLocations.isNotEmpty
                  ? _learnerLocations.join(', ')
                  : 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.cake_outlined,
              label: 'Age',
              value:
                  _learnerAge != null ? '$_learnerAge years' : 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Gender',
              value: _learnerGender ?? 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.school_outlined,
              label: 'Lesson Progress',
              value: _learnerClassesTaken != null
                  ? '${_learnerClassesTaken} classes completed'
                  : 'No lessons recorded yet',
            ),
            if (_learnerLastClassDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.event_available_outlined,
                label: 'Last Class',
                value: dateFormatter.format(_learnerLastClassDate!),
              ),
            ],
            if (_learnerTestDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.assignment_outlined,
                label: 'G1 Test Date',
                value: dateFormatter.format(_learnerTestDate!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorDetailsSection() {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final licenceParts = <String>[];
    if (_licenceNumber != null && _licenceNumber!.isNotEmpty) {
      licenceParts.add('Number: $_licenceNumber');
    }
    if (_licenceExpiry != null) {
      licenceParts.add('Expiry: ${dateFormatter.format(_licenceExpiry!)}');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instructor Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'Instructor Licence',
              value: licenceParts.isEmpty
                  ? 'Not provided'
                  : licenceParts.join(' • '),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.map_outlined,
              label: 'Service Area',
              value: _instructorServiceArea ?? 'Not provided',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.description_outlined,
              label: 'Bio',
              value: _instructorBio != null && _instructorBio!.isNotEmpty
                  ? _instructorBio!
                  : 'Share your experience so learners know what to expect.',
            ),
            if (_instructorOfferings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.local_play_outlined,
                label: 'Offerings',
                value: _instructorOfferings.join(', '),
              ),
            ],
            if (_instructorLanguages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.language_outlined,
                label: 'Languages',
                value: _instructorLanguages.join(', '),
              ),
            ],
            if (_instructorLocations.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.meeting_room_outlined,
                label: 'Preferred Lesson Locations',
                value: _instructorLocations.join(', '),
              ),
            ],
            if (_instructorLocationNotes != null &&
                _instructorLocationNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.note_alt_outlined,
                label: 'Location Notes',
                value: _instructorLocationNotes!,
              ),
            ],
            if (_instructorVehicles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.directions_car_filled_outlined,
                label: 'Vehicles',
                value: _instructorVehicles.join('\n'),
              ),
            ],
            if (_instructorAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.location_city_outlined,
                label: 'Areas of Operation',
                value: _instructorAreas.join('\n'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isLoading = true);
    _licenceNumber = null;
    _licenceExpiry = null;
    _learnerCity = null;
    _learnerAge = null;
    _learnerGender = null;
    _learnerClassesTaken = null;
    _learnerLastClassDate = null;
    _learnerTestDate = null;
    _instructorServiceArea = null;
    _instructorBio = null;
    _instructorLanguages = [];
    _instructorOfferings = [];
    _instructorVehicles = [];
    _instructorAreas = [];

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
        if (profile.role == 'learner') {
          await _populateLearnerDetails(profile.id);
        } else if (profile.role == 'instructor') {
          await _populateInstructorDetails(profile.id);
        }
      } else {
        _emailController.text = user.email ?? '';
        _roleLabel = _formatRole(user.userMetadata?['role'] as String?);
        final fallbackRole = user.userMetadata?['role'] as String?;
        if (fallbackRole == 'learner') {
          await _populateLearnerDetails(user.id);
        } else if (fallbackRole == 'instructor') {
          await _populateInstructorDetails(user.id);
        }
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

  Future<void> _populateLearnerDetails(String userId) async {
    try {
      final detail = await SupabaseService.getLearnerProfileDetail(userId);
      if (!mounted || detail == null) return;

      setState(() {
        _licenceNumber = detail['licence_number'] as String?;
        final expiry = detail['licence_expiry'] as String?;
        _licenceExpiry = expiry != null ? DateTime.tryParse(expiry) : null;
        _learnerCity = detail['city'] as String?;
        final age = detail['age'];
        if (age is int) {
          _learnerAge = age;
        } else if (age is String) {
          _learnerAge = int.tryParse(age);
        }
        _learnerGender = detail['gender'] as String?;
        final classesTaken = detail['classes_taken_total'];
        if (classesTaken is int) {
          _learnerClassesTaken = classesTaken;
        } else if (classesTaken is String) {
          _learnerClassesTaken = int.tryParse(classesTaken);
        }
        final lastClass = detail['last_class_date'] as String?;
        _learnerLastClassDate =
            lastClass != null ? DateTime.tryParse(lastClass) : null;
        final testDate = detail['g1_test_date'] as String?;
        _learnerTestDate =
            testDate != null ? DateTime.tryParse(testDate) : null;
        final locations = detail['preferred_locations'];
        _learnerLocations = [];
        if (locations is List) {
          for (final entry in locations) {
            if (entry is Map) {
              final label = (entry['label'] as String?)?.trim();
              final address = (entry['address'] as String?)?.trim();
              if ((label?.isNotEmpty ?? false) ||
                  (address?.isNotEmpty ?? false)) {
                final title = (label != null && label.isNotEmpty)
                    ? label
                    : (entry['type'] as String? ?? 'Location');
                final combined = address != null && address.isNotEmpty
                    ? '$title: $address'
                    : title ?? 'Location';
                _learnerLocations.add(combined);
              }
            } else if (entry is String) {
              _learnerLocations.add(entry);
            }
          }
        }
      });
    } catch (e) {
      // ignore but log? for now just print
      debugPrint('Error loading learner details: $e');
    }
  }

  Future<void> _populateInstructorDetails(String userId) async {
    try {
      final detail = await SupabaseService.getInstructorProfileDetail(userId);
      if (!mounted || detail == null) return;

      final vehicles = <String>[];
      final areas = <String>[];
      final offerings = <String>[];
      final languages = <String>[];

      final rawVehicles = detail['vehicles'];
      if (rawVehicles is List) {
        for (final entry in rawVehicles) {
          if (entry is Map) {
            final type = (entry['type'] as String? ?? '').trim();
            final year = (entry['year'] as String? ?? '').trim();
            final make = (entry['make'] as String? ?? '').trim();
            final model = (entry['model'] as String? ?? '').trim();
            final plate = (entry['numberPlate'] as String? ?? '').trim();

            final makeModelParts = <String>[];
            if (year.isNotEmpty) makeModelParts.add(year);
            if (make.isNotEmpty) makeModelParts.add(make);
            if (model.isNotEmpty) makeModelParts.add(model);
            final makeModel = makeModelParts.join(' ');

            final segments = <String>[];
            if (type.isNotEmpty) segments.add(type);
            if (makeModel.isNotEmpty) segments.add(makeModel);
            if (plate.isNotEmpty) segments.add('Plate: $plate');

            final label = segments.join(' • ');
            if (label.isNotEmpty) {
              vehicles.add(label);
            }
          } else if (entry is String) {
            vehicles.add(entry);
          }
        }
      }

      final rawAreas = detail['areas_of_operation'];
      if (rawAreas is List) {
        for (final entry in rawAreas) {
          if (entry is Map) {
            final city = entry['city'] as String?;
            final radius = entry['radiusKm'];
            double? parsedRadius;
            if (radius is num) {
              parsedRadius = radius.toDouble();
            } else if (radius is String) {
              parsedRadius = double.tryParse(radius);
            }
            if (city != null && parsedRadius != null) {
              areas.add('$city • ${parsedRadius.toStringAsFixed(1)} km');
            }
          }
        }
      }

      final rawOfferings = detail['offerings'];
      if (rawOfferings is List) {
        offerings.addAll(rawOfferings.whereType<String>());
      }

      final rawLanguages = detail['languages'];
      if (rawLanguages is List) {
        languages.addAll(rawLanguages.whereType<String>());
      }

      final expiry = detail['licence_expiry'] as String?;

      setState(() {
        _licenceNumber = detail['licence_number'] as String?;
        _licenceExpiry = expiry != null ? DateTime.tryParse(expiry) : null;
        _instructorServiceArea = detail['service_area'] as String?;
        _instructorBio = detail['bio'] as String?;
        _instructorLanguages = languages;
        _instructorOfferings = offerings;
        _instructorVehicles = vehicles;
        _instructorAreas = areas;
        final locations = detail['preferred_locations'];
        _instructorLocations = [];
        if (locations is List) {
          for (final entry in locations) {
            if (entry is Map) {
              final label = (entry['label'] as String?)?.trim();
              final address = (entry['address'] as String?)?.trim();
              if ((label?.isNotEmpty ?? false) ||
                  (address?.isNotEmpty ?? false)) {
                final title = (label != null && label.isNotEmpty)
                    ? label
                    : (entry['type'] as String? ?? 'Location');
                final combined = address != null && address.isNotEmpty
                    ? '$title: $address'
                    : title;
                _instructorLocations.add(combined);
              }
            } else if (entry is String) {
              _instructorLocations.add(entry);
            }
          }
        }
        final locationNotes = detail['preferred_location_notes'];
        _instructorLocationNotes =
            locationNotes is String && locationNotes.isNotEmpty
                ? locationNotes
                : null;
      });
    } catch (e) {
      debugPrint('Error loading instructor details: $e');
    }
  }

  Future<void> _openEditProfile() async {
    final result = await context.push<bool>(AppRoutes.editProfile);
    if (result == true) {
      await _loadProfile();
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
        Text(
            'A friendly platform connecting driving learners with verified instructors in Ontario.'),
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
    final initials =
        (first.isNotEmpty ? first[0] : '') + (last.isNotEmpty ? last[0] : '');
    if (initials.isEmpty) return 'DT';
    return initials.toUpperCase();
  }

  String _formatRole(String? role) {
    final value = (role ?? 'learner').trim();
    if (value.isEmpty) return 'Learner';
    return value[0].toUpperCase() + value.substring(1);
  }
}
