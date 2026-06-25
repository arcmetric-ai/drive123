import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_expandable_section.dart';
import '../../widgets/verified_profile_badge.dart';
import '../instructor/instructor_bookings_history_screen.dart';

class _LegalPolicy {
  const _LegalPolicy({
    required this.title,
    required this.path,
    required this.summary,
    required this.bullets,
  });

  final String title;
  final String path;
  final String summary;
  final List<String> bullets;
}

const _policyTerms = _LegalPolicy(
  title: 'Terms & Conditions',
  path: 'terms-and-conditions',
  summary:
      'The rules for using Drive Tutor, creating an account, booking lessons, and using instructor or learner features.',
  bullets: [
    'Use accurate account, licence, vehicle, and booking information.',
    'Follow platform rules, instructor requirements, payment terms, and cancellation rules.',
    'Drive Tutor may restrict accounts that misuse the platform or create safety, fraud, or compliance risk.',
  ],
);

const _policyPrivacy = _LegalPolicy(
  title: 'Privacy Policy',
  path: 'privacy-policy',
  summary:
      'How Drive Tutor collects, uses, stores, and shares personal information needed to run the platform.',
  bullets: [
    'We use account, contact, profile, booking, location, and verification information to operate Drive Tutor.',
    'Verification documents and selfies are used for trust, safety, and compliance review.',
    'You can request account deletion or data help from your profile or support.',
  ],
);

const _policyDataConsent = _LegalPolicy(
  title: 'Data Consent',
  path: 'data-consent-policy',
  summary:
      'Consent for Drive Tutor to process account, licence, verification, booking, and safety information.',
  bullets: [
    'Learners and instructors consent to licence and identity verification checks required by their role.',
    'Guardians consent to manage a learner account and provide required guardian identity information.',
    'Verification status may affect whether public profile, booking, or request features are available.',
  ],
);

const _policySafety = _LegalPolicy(
  title: 'Safety Policy',
  path: 'safety-policy',
  summary:
      'Safety expectations for lessons, communications, vehicle readiness, and account conduct.',
  bullets: [
    'Instructors must keep licence, insurance, vehicle, and profile information accurate.',
    'Learners should only book lessons they can safely attend and should follow instructor safety guidance.',
    'Unsafe, abusive, fraudulent, or non-compliant conduct can lead to removal from Drive Tutor.',
  ],
);

const _policyCommunity = _LegalPolicy(
  title: 'Community Guidelines',
  path: 'community-guidelines',
  summary:
      'Behaviour standards for respectful, lawful, and safe use of Drive Tutor.',
  bullets: [
    'Be respectful in messages, bookings, lessons, reviews, and support requests.',
    'Do not harass, discriminate, impersonate others, or bypass platform safety controls.',
    'Report safety concerns, suspicious behaviour, or incorrect profile information.',
  ],
);

const _policyCookie = _LegalPolicy(
  title: 'Cookie Policy',
  path: 'cookie-policy',
  summary:
      'How Drive Tutor website cookies and similar technologies support login, analytics, and service reliability.',
  bullets: [
    'Cookies may be used on the website for authentication, preferences, analytics, and security.',
    'Mobile app behaviour may still rely on secure tokens and device-level platform services.',
    'Browser cookie controls may affect website login and portal functionality.',
  ],
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.refreshToken = 0,
  });

  final int refreshToken;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
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
  bool _openingPreview = false;
  String? _licenceNumber;
  DateTime? _licenceExpiry;
  String? _learnerCity;
  String? _learnerAccountType;
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
  String? _instructorDriveTutorNumber;
  int? _instructorYearsExperience;
  bool? _instructorPickupPreference;
  List<String> _learnerLocations = [];
  List<String> _instructorLocations = [];
  Map<String, List<String>> _learnerWeeklyAvailability = {};
  bool _learnerAvailabilityRecurring = true;
  bool _openingAvailability = false;
  bool _openingCredentialsPortal = false;
  bool _isRequestingDeletion = false;
  bool _isPersonalInfoExpanded = false;
  bool _isLearnerDetailsExpanded = false;
  bool _isInstructorDetailsExpanded = false;
  Map<String, dynamic>? _graduatedRelationship;
  bool _resumingTraining = false;

  bool get _isLearnerProfile =>
      _roleLabel == 'Learner' || _roleLabel == 'Guardian';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 18),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 18),
                    if (_isLearnerProfile)
                      Column(
                        children: [
                          if (_graduatedRelationship != null) ...[
                            _buildGraduatedTrainingCard(),
                            const SizedBox(height: 18),
                          ],
                          _buildLearnerDetailsSection(),
                        ],
                      )
                    else
                      _buildInstructorDetailsSection(),
                    const SizedBox(height: 18),
                    _buildAccountActionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _profileCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(22),
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildProfileHeader() {
    return _profileCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.primaryBlue.withValues(alpha: 0.45),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  backgroundImage: _avatarImage,
                  child: _avatarImage == null
                      ? Text(
                          _initials,
                          style: const TextStyle(
                            fontSize: 26,
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
                        color: Colors.black.withValues(alpha: 0.35),
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  if (_isVerified) ...[
                    const SizedBox(width: 8),
                    const VerifiedProfileBadge(size: 32),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _roleLabel,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _profileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileExpandableSection(
            title: 'Personal Information',
            isExpanded: _isPersonalInfoExpanded,
            onToggle: () {
              setState(() {
                _isPersonalInfoExpanded = !_isPersonalInfoExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: _displayName,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _emailController.text.isNotEmpty
                      ? _emailController.text
                      : (SupabaseService.currentUser?.email ?? 'Not provided'),
                ),
                const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget _buildAccountActionsSection() {
    final isInstructor = _roleLabel.toLowerCase() == 'instructor';
    return _profileCard(
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
          if (isInstructor) ...[
            _buildInstructorReferralCard(),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openingPreview ? null : _openPublicProfilePreview,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _openingPreview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(
                _openingPreview
                    ? 'Opening preview...'
                    : (isInstructor
                        ? 'Preview Public Instructor Profile'
                        : 'Preview Public Profile'),
              ),
            ),
          ),
          if (_isLearnerProfile) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openingAvailability
                    ? null
                    : _openLearnerAvailabilityEditor,
                icon: _openingAvailability
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.schedule_outlined),
                label: Text(
                  _openingAvailability
                      ? 'Loading availability...'
                      : 'Update Weekly Availability',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showInstructorCodeSheet,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Enter Instructor Code'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openingCredentialsPortal
                    ? null
                    : _openInstructorCredentialsPortal,
                icon: _openingCredentialsPortal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  _openingCredentialsPortal
                      ? 'Opening credentials portal...'
                      : 'Manage Credentials Portal',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update licence, questionnaire, and preferences',
            onTap: _openEditProfile,
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notification Centre',
            subtitle: 'Choose reminders, updates, and general alerts',
            onTap: () => context.push(AppRoutes.notificationPreferences),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Review how Drive Tutor handles your information',
            onTap: () => _showLegalPolicy(_policyPrivacy),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.gavel_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Review the terms for using Drive Tutor',
            onTap: () => _showLegalPolicy(_policyTerms),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.fact_check_outlined,
            title: 'Data Consent',
            subtitle: 'Review your verification and data consent',
            onTap: () => _showLegalPolicy(_policyDataConsent),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety Policy',
            subtitle: 'Review safety expectations for lessons',
            onTap: () => _showLegalPolicy(_policySafety),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.groups_2_outlined,
            title: 'Community Guidelines',
            subtitle: 'Review conduct rules for learners and instructors',
            onTap: () => _showLegalPolicy(_policyCommunity),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.cookie_outlined,
            title: 'Cookie Policy',
            subtitle: 'Review website cookie and analytics use',
            onTap: () => _showLegalPolicy(_policyCookie),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.history,
            title: isInstructor ? 'Bookings History' : 'Lesson History',
            subtitle: isInstructor
                ? 'Review all previous bookings'
                : 'View all your past lessons',
            onTap: isInstructor
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InstructorBookingsHistoryScreen(),
                      ),
                    )
                : () => context.push(AppRoutes.myLessons),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.lock_reset_outlined,
            title: 'Update Password',
            subtitle: 'Keep your account secure',
            onTap: _showUpdatePasswordSheet,
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help or contact support',
            onTap: () => context.push(AppRoutes.helpSupport),
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: _showAboutDialog,
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Request account and data deletion',
            onTap: _isRequestingDeletion ? () {} : _showDeleteAccountDialog,
            textColor: AppColors.error,
          ),
          _buildActionDivider(),
          _buildActionTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            onTap: _signOut,
            textColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorReferralCard() {
    final code = _instructorDriveTutorNumber?.trim();
    final hasCode = code != null && code.isNotEmpty;
    final inviteUrl =
        hasCode ? 'https://www.drivetutor.ca/invite/instructor/$code' : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBlue, width: 3),
                  image: _avatarImage != null
                      ? DecorationImage(image: _avatarImage!, fit: BoxFit.cover)
                      : null,
                ),
                child: _avatarImage == null
                    ? Center(
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isVerified)
                          const VerifiedProfileBadge(
                            size: 22,
                          )
                        else
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primaryBlue,
                            size: 18,
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isVerified
                                ? 'Verified Instructor Card'
                                : 'Instructor Referral Card',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _instructorServiceArea?.isNotEmpty == true
                          ? 'Serving $_instructorServiceArea'
                          : 'Service area pending',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INSTRUCTOR ID',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasCode ? code : 'Generate your code',
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (hasCode && inviteUrl != null)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE3E8F5)),
                  ),
                  child: QrImageView(data: inviteUrl, size: 118),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan to join you in Drive Tutor',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Use this with learners you already know. They can also type your code after approval.',
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton.icon(
                            onPressed: () => _shareInstructorReferral(
                              code: code,
                              inviteUrl: inviteUrl,
                            ),
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: const Text('Share'),
                          ),
                          TextButton.icon(
                            onPressed: () => _copyInstructorReferral(inviteUrl),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy link'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateInstructorReferralCode,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Generate Instructor Code'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyInstructorReferral(String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
        const SnackBar(content: Text('Instructor invite link copied.')));
  }

  Future<void> _shareInstructorReferral({
    required String code,
    required String inviteUrl,
  }) async {
    final message = 'Book driving lessons with me on Drive Tutor: $inviteUrl\n'
        'Instructor code: $code';
    await Share.share(
      message,
      subject: 'Drive Tutor instructor invite',
    );
  }

  Future<void> _generateInstructorReferralCode() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final code = await SupabaseService.ensureInstructorDriveTutorNumber(
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _instructorDriveTutorNumber = code);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructor code generated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate code: $error')),
      );
    }
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
        style: TextStyle(
          color: textColor ?? AppColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.mutedForeground),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.mutedForeground,
      ),
      onTap: onTap,
    );
  }

  Widget _buildActionDivider() =>
      const Divider(height: 20, color: Color(0xFFE6ECF7));

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryBlue),
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
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.foreground,
                ),
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

    return _profileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileExpandableSection(
            title: 'Learner Details',
            isExpanded: _isLearnerDetailsExpanded,
            onToggle: () {
              setState(() {
                _isLearnerDetailsExpanded = !_isLearnerDetailsExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.supervisor_account_outlined,
                  label: 'Account Type',
                  value: _learnerAccountType == 'guardian'
                      ? 'Guardian-managed learner'
                      : 'Learner',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.credit_card,
                  label: 'G1/G2/G Licence',
                  value: licenceParts.isEmpty
                      ? 'Not provided'
                      : licenceParts.join(' - '),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'City',
                  value: _learnerCity ?? 'Not provided',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.meeting_room_outlined,
                  label: 'Preferred Locations',
                  value: _learnerLocations.isNotEmpty
                      ? _learnerLocations.join(', ')
                      : 'Not provided',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.access_time,
                  label: 'Weekly Availability',
                  value: _formatWeeklyAvailabilitySummary(),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: _learnerAge != null
                      ? '$_learnerAge years'
                      : 'Not provided',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value: _learnerGender ?? 'Not provided',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.school_outlined,
                  label: 'Lesson Progress',
                  value: _learnerClassesTaken != null
                      ? '$_learnerClassesTaken classes completed'
                      : 'No lessons recorded yet',
                ),
                if (_learnerLastClassDate != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Last Class',
                    value: dateFormatter.format(_learnerLastClassDate!),
                  ),
                ],
                if (_learnerTestDate != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.assignment_outlined,
                    label: 'G1 Test Date',
                    value: dateFormatter.format(_learnerTestDate!),
                  ),
                ],
              ],
            ),
          ),
        ],
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

    return _profileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileExpandableSection(
            title: 'Instructor Details',
            isExpanded: _isInstructorDetailsExpanded,
            onToggle: () {
              setState(() {
                _isInstructorDetailsExpanded = !_isInstructorDetailsExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Instructor Licence',
                  value: licenceParts.isEmpty
                      ? 'Not provided'
                      : licenceParts.join(' - '),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.map_outlined,
                  label: 'Service Area',
                  value: _instructorServiceArea ?? 'Not provided',
                ),
                if (_instructorYearsExperience != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.timeline_outlined,
                    label: 'Years of Experience',
                    value: _instructorYearsExperience == 1
                        ? '1 year'
                        : '$_instructorYearsExperience years',
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.description_outlined,
                  label: 'Bio',
                  value: _instructorBio != null && _instructorBio!.isNotEmpty
                      ? _instructorBio!
                      : 'Share your experience so learners know what to expect.',
                ),
                if (_instructorOfferings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.local_play_outlined,
                    label: 'Offerings',
                    value: _instructorOfferings.join(', '),
                  ),
                ],
                if (_instructorLanguages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.language_outlined,
                    label: 'Languages',
                    value: _instructorLanguages.join(', '),
                  ),
                ],
                if (_instructorPickupPreference != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Learner Pickup',
                    value: _instructorPickupPreference!
                        ? 'Offered'
                        : 'Not offered',
                  ),
                ],
                if (_instructorLocations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.meeting_room_outlined,
                    label: 'Preferred Lesson Locations',
                    value: _instructorLocations.join(', '),
                  ),
                ],
                if (_instructorVehicles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.directions_car_filled_outlined,
                    label: 'Vehicles',
                    value: _instructorVehicles.join('\n'),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    _learnerAccountType = null;
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
    _instructorDriveTutorNumber = null;
    _instructorYearsExperience = null;
    _instructorPickupPreference = null;

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
        final normalizedRole = _normalizeRole(profile.role);
        _roleLabel = _formatRole(normalizedRole);
        if (normalizedRole == 'learner') {
          await _populateLearnerDetails(profile.id);
        } else if (normalizedRole == 'instructor') {
          await _populateInstructorDetails(profile.id);
        }
      } else {
        _emailController.text = user.email ?? '';
        final fallbackRole = _normalizeRole(user.userMetadata?['role']);
        _roleLabel = _formatRole(fallbackRole);
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
      final results = await Future.wait<dynamic>([
        SupabaseService.getLearnerProfileDetail(userId),
        SupabaseService.getRawProfile(userId),
      ]);
      if (!mounted) return;

      final detail = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : <String, dynamic>{};
      final rawProfile = results[1] is Map
          ? Map<String, dynamic>.from(results[1] as Map)
          : <String, dynamic>{};
      final nestedProfile = detail['profile'] is Map
          ? Map<String, dynamic>.from(detail['profile'] as Map)
          : <String, dynamic>{};
      Map<String, dynamic>? graduation;
      try {
        final row = await SupabaseService.getCurrentLearnerGraduation();
        if (row != null) {
          graduation = Map<String, dynamic>.from(row);
        }
      } catch (error) {
        debugPrint('Unable to load learner graduation state: $error');
      }
      final profileMap = _mergeNonNull(rawProfile, nestedProfile);
      final learnerMap = _mergeNonNull(detail, profileMap);
      final accountType = _firstString([
        detail['account_type'],
        detail['accountType'],
        learnerMap['account_type'],
        learnerMap['accountType'],
      ])?.toLowerCase();
      final locations = _locationSummaries(
        detail['preferred_locations'] ??
            profileMap['preferred_locations'] ??
            learnerMap['preferredLocations'],
      );
      setState(() {
        _graduatedRelationship = graduation;
        _learnerAccountType = accountType;
        if (accountType == 'guardian') {
          _roleLabel = 'Guardian';
        }
        _licenceNumber = _firstString([
          profileMap['licence_number'],
          learnerMap['licence_number'],
          learnerMap['licenseNumber'],
        ]);
        _licenceExpiry = _firstDate([
          profileMap['licence_expiry'],
          learnerMap['licence_expiry'],
          learnerMap['licenseExpiry'],
        ]);
        _learnerCity = _firstString([
          profileMap['city'],
          learnerMap['city'],
          detail['city'],
        ]);
        _learnerAge = _firstInt([
          profileMap['age'],
          detail['age'],
          detail['ward_age'],
          learnerMap['age'],
        ]);
        _learnerGender = _firstString([
          profileMap['gender'],
          detail['gender'],
          detail['ward_gender'],
          learnerMap['gender'],
        ]);
        _learnerClassesTaken = _firstInt([
          detail['classes_taken_sofar'],
          detail['classes_taken'],
          learnerMap['classes_taken_sofar'],
          learnerMap['classes_taken'],
        ]);
        _learnerLastClassDate = _firstDate([
          detail['last_class_date'],
          learnerMap['last_class_date'],
        ]);
        _learnerTestDate = _firstDate([
          detail['target_test_date'],
          detail['g1_test_date'],
          detail['test_date'],
          learnerMap['target_test_date'],
        ]);
        _learnerLocations = locations;
        _learnerWeeklyAvailability = _parseWeeklyAvailability(
          detail['weekly_availability'] ??
              profileMap['weekly_availability'] ??
              learnerMap['weeklyAvailability'],
        );
        _learnerAvailabilityRecurring =
            detail['availability_recurring'] == true ||
                profileMap['availability_recurring'] == true;
      });
    } catch (e) {
      // ignore but log? for now just print
      debugPrint('Error loading learner details: $e');
    }
  }

  Widget _buildGraduatedTrainingCard() {
    final request = _graduatedRelationship!;
    final instructor = request['instructor'] is Map
        ? Map<String, dynamic>.from(request['instructor'] as Map)
        : const <String, dynamic>{};
    final name = [instructor['first_name'], instructor['last_name']]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    return _profileCard(
      borderColor: AppColors.success.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Training completed',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          Text(name.isEmpty
              ? 'You remain connected to your instructor.'
              : 'You remain connected to $name and can resume training later.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _resumingTraining
                ? null
                : () async {
                    setState(() => _resumingTraining = true);
                    try {
                      await SupabaseService.resumeGraduatedTraining(
                        request['id'].toString(),
                      );
                      await _loadProfile();
                    } finally {
                      if (mounted) setState(() => _resumingTraining = false);
                    }
                  },
            child: Text(_resumingTraining ? 'Resuming...' : 'Resume training'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLegalPolicy(_LegalPolicy policy) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(policy.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(policy.summary),
              const SizedBox(height: 14),
              for (final bullet in policy.bullets) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(bullet)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openPolicy(policy.path),
            child: const Text('View full policy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPolicy(String path) async {
    final uri = Uri.parse('https://www.drivetutor.ca/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _populateInstructorDetails(String userId) async {
    try {
      final detail = await SupabaseService.getInstructorProfileDetail(userId);
      if (!mounted || detail == null) return;

      final profileMap = detail['profile'] is Map
          ? Map<String, dynamic>.from(detail['profile'] as Map)
          : <String, dynamic>{};
      final vehicles = <String>[];
      final areas = <String>[];
      final offerings = <String>[];
      final languages = <String>[];

      final rawVehicles = detail['vehicles'];
      if (rawVehicles is List) {
        for (final entry in rawVehicles) {
          if (entry is Map) {
            final type = (_asString(entry['type']) ?? '').trim();
            final year = (_asString(entry['year']) ?? '').trim();
            final make = (_asString(entry['make']) ?? '').trim();
            final model = (_asString(entry['model']) ?? '').trim();
            final plate = (_asString(entry['numberPlate']) ?? '').trim();

            final makeModelParts = <String>[];
            if (year.isNotEmpty) makeModelParts.add(year);
            if (make.isNotEmpty) makeModelParts.add(make);
            if (model.isNotEmpty) makeModelParts.add(model);
            final makeModel = makeModelParts.join(' ');

            final segments = <String>[];
            if (type.isNotEmpty) segments.add(type);
            if (makeModel.isNotEmpty) segments.add(makeModel);
            if (plate.isNotEmpty) segments.add('Plate: $plate');

            final label = segments.join(' - ');
            if (label.isNotEmpty) {
              vehicles.add(label);
            }
          } else if (entry is String) {
            vehicles.add(entry);
          }
        }
      }

      final rawAreas = detail['preferred_locations'];
      if (rawAreas is List) {
        for (final entry in rawAreas) {
          if (entry is Map) {
            final city = _asString(entry['city']);
            final radius = entry['radiusKm'] ?? entry['radius_km'];
            double? parsedRadius;
            if (radius is num) {
              parsedRadius = radius.toDouble();
            } else if (radius is String) {
              parsedRadius = double.tryParse(radius);
            }
            if (city != null && parsedRadius != null) {
              areas.add('$city - ${parsedRadius.toStringAsFixed(1)} km');
            }
          }
        }
      }

      final rawOfferings = detail['offerings'];
      if (rawOfferings is List) {
        offerings.addAll(rawOfferings.whereType<String>());
      }

      final rawLanguages = profileMap['languages'];
      if (rawLanguages is List) {
        languages.addAll(
          rawLanguages
              .whereType<String>()
              .map(_titleCase)
              .where((value) => value.isNotEmpty),
        );
      }

      final rawYears = detail['years_of_experience'];
      int? yearsExperience;
      if (rawYears is num) {
        yearsExperience = rawYears.toInt();
      } else if (rawYears is String) {
        yearsExperience = int.tryParse(rawYears);
      }

      final rawPickup = detail['pickup_preference'];
      bool? pickupPreference;
      if (rawPickup is bool) {
        pickupPreference = rawPickup;
      } else if (rawPickup is String) {
        final normalized = rawPickup.toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          pickupPreference = true;
        } else if (normalized == 'false' || normalized == '0') {
          pickupPreference = false;
        }
      }

      final expiry = _asString(profileMap['licence_expiry']);
      final profileCity = _asString(profileMap['city']);
      final driveTutorNumber = _asString(detail['drive_tutor_number']);

      setState(() {
        _instructorYearsExperience = yearsExperience;
        _instructorPickupPreference = pickupPreference;
        _instructorDriveTutorNumber = driveTutorNumber;
        _licenceNumber = _asString(profileMap['licence_number']);
        _licenceExpiry = expiry != null ? DateTime.tryParse(expiry) : null;
        _instructorServiceArea =
            profileCity ?? (areas.isNotEmpty ? areas.first : null);
        _instructorBio = _asString(detail['bio']);
        _instructorLanguages = languages;
        _instructorOfferings = offerings;
        _instructorVehicles = vehicles;
        final locations = detail['preferred_locations'];
        _instructorLocations = [];
        if (locations is List) {
          for (final entry in locations) {
            if (entry is Map) {
              final label = _asString(entry['label'])?.trim();
              final address = _asString(entry['address'])?.trim();
              if ((label?.isNotEmpty ?? false) ||
                  (address?.isNotEmpty ?? false)) {
                final title = (label != null && label.isNotEmpty)
                    ? label
                    : (_asString(entry['type']) ?? 'Location');
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
      });
    } catch (e) {
      debugPrint('Error loading instructor details: $e');
    }
  }

  Future<void> _openPublicProfilePreview() async {
    final user = SupabaseService.currentUser;
    if (user == null || _openingPreview) return;
    setState(() => _openingPreview = true);
    try {
      final role = _roleLabel.toLowerCase();
      if (role == 'instructor') {
        final rawProfile = await SupabaseService.getRawProfile(user.id);
        final detail = await SupabaseService.getInstructorProfileDetail(
          user.id,
        );
        if (!mounted) return;
        final payload = _buildInstructorPreviewPayload(
          rawProfile is Map<String, dynamic>
              ? Map<String, dynamic>.from(rawProfile)
              : null,
          detail is Map<String, dynamic>
              ? Map<String, dynamic>.from(detail)
              : null,
        );
        await context.push(AppRoutes.instructorProfilePreview, extra: payload);
      } else {
        await context.push(
          AppRoutes.instructorLearnerDetail,
          extra: {'profile_id': user.id, 'status': 'public_preview'},
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open preview: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingPreview = false);
      }
    }
  }

  Future<void> _openLearnerAvailabilityEditor() async {
    final user = SupabaseService.currentUser;
    if (user == null || _openingAvailability) return;
    setState(() => _openingAvailability = true);
    try {
      final result = await context.push<bool>(
        AppRoutes.editLearnerAvailability,
        extra: {
          'initialAvailability': _learnerWeeklyAvailability,
          'availabilityRecurring': _learnerAvailabilityRecurring,
        },
      );
      if (result == true) {
        await _loadProfile();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open availability editor: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAvailability = false);
      }
    }
  }

  Map<String, dynamic> _buildInstructorPreviewPayload(
    Map<String, dynamic>? profile,
    Map<String, dynamic>? detail,
  ) {
    final profileMap = profile ?? <String, dynamic>{};
    final detailMap = detail ?? <String, dynamic>{};

    String? clean(dynamic value) => _asString(value)?.trim();

    String? firstVehiclePhoto(dynamic rawVehicles) {
      if (rawVehicles is List) {
        for (final entry in rawVehicles) {
          if (entry is Map) {
            final url = clean(entry['photoUrl']) ??
                clean(entry['photo_url']) ??
                clean(entry['imageUrl']) ??
                clean(entry['image_url']);
            if (url != null && url.isNotEmpty) return url;
          }
        }
      }
      return null;
    }

    String combineName() {
      final first =
          clean(profileMap['first_name']) ?? _firstNameController.text.trim();
      final last =
          clean(profileMap['last_name']) ?? _lastNameController.text.trim();
      final parts = [first, last].where((value) => value.isNotEmpty);
      final name = parts.join(' ').trim();
      if (name.isNotEmpty) return name;
      return _displayName;
    }

    List<String> summarizeVehicles(dynamic raw) {
      final vehicles = <String>[];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            final type = clean(entry['type']);
            final year = clean(entry['year']);
            final make = clean(entry['make']);
            final model = clean(entry['model']);
            final plate = clean(entry['numberPlate']);
            final makeModelParts = <String>[];
            if (year != null && year.isNotEmpty) makeModelParts.add(year);
            if (make != null && make.isNotEmpty) makeModelParts.add(make);
            if (model != null && model.isNotEmpty) makeModelParts.add(model);
            final makeModel = makeModelParts.join(' ').trim();
            final segments = <String>[];
            if (type != null && type.isNotEmpty) segments.add(type);
            if (makeModel.isNotEmpty) segments.add(makeModel);
            if (plate != null && plate.isNotEmpty) {
              segments.add('Plate: $plate');
            }
            final summary = segments.join(' - ').trim();
            if (summary.isNotEmpty) {
              vehicles.add(summary);
            }
          } else if (entry is String && entry.trim().isNotEmpty) {
            vehicles.add(entry.trim());
          }
        }
      }
      if (vehicles.isEmpty) {
        vehicles.addAll(_instructorVehicles);
      }
      return vehicles;
    }

    List<String> composePreferredLocations(dynamic raw) {
      final locations = <String>[];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            final label = clean(entry['label']);
            final address = clean(entry['address']);
            final type = clean(entry['type']);
            String? combined;
            if (label != null && address != null) {
              combined = '$label - $address';
            } else if (address != null) {
              combined = address;
            } else if (label != null) {
              combined = label;
            } else if (type != null) {
              combined = type;
            }
            if (combined != null && combined.isNotEmpty) {
              locations.add(combined);
            }
          } else if (entry is String && entry.trim().isNotEmpty) {
            locations.add(entry.trim());
          }
        }
      }
      if (locations.isEmpty) {
        locations.addAll(_instructorLocations);
      }
      return locations;
    }

    List<String> composeAreas(dynamic raw) {
      final areas = <String>[];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            final areaName = clean(entry['area']) ?? clean(entry['areaName']);
            final city = clean(entry['city']);
            final radius = entry['radiusKm'] ?? entry['radius_km'];
            double? radiusValue;
            if (radius is num) {
              radiusValue = radius.toDouble();
            } else if (radius is String) {
              radiusValue = double.tryParse(radius);
            }
            final parts = <String>[];
            if (areaName != null && areaName.isNotEmpty) {
              parts.add(areaName);
            }
            if (city != null && city.isNotEmpty) {
              parts.add(city);
            }
            if (radiusValue != null) {
              parts.add(
                '${radiusValue.toStringAsFixed(radiusValue == radiusValue.roundToDouble() ? 0 : 1)} km radius',
              );
            }
            final label = parts.join(' - ').trim();
            if (label.isNotEmpty) {
              areas.add(label);
            }
          }
        }
      }
      return areas;
    }

    Map<String, String> composeOfferingRates(dynamic raw) {
      final rates = <String, String>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          final label = key.toString();
          if (value is num) {
            rates[label] = '\$${value.toDouble().toStringAsFixed(0)}/hr';
          } else if (value is String && value.trim().isNotEmpty) {
            rates[label] = value.trim();
          }
        });
      }
      return rates;
    }

    String composeRatesLabel(
      dynamic defaultRateRaw,
      Map<String, String> rates,
    ) {
      if (defaultRateRaw is num && defaultRateRaw > 0) {
        return 'Standard lesson: \$${defaultRateRaw.toDouble().toStringAsFixed(0)}/hr';
      }
      if (rates.isNotEmpty) {
        final first = rates.entries.first;
        return '${first.key}: ${first.value}';
      }
      return 'Add your rates';
    }

    final vehicles = summarizeVehicles(detailMap['vehicles']);
    final preferredLocations = composePreferredLocations(
      detailMap['preferred_locations'],
    );
    final areas = composeAreas(detailMap['areas_of_operation']);
    final offeringRates = composeOfferingRates(detailMap['offering_rates']);
    final languages = (profileMap['languages'] is List
            ? (profileMap['languages'] as List)
                .whereType<String>()
                .map(_titleCase)
                .where((value) => value.isNotEmpty)
                .toList()
            : _instructorLanguages)
        .toList();
    final offerings = detailMap['offerings'] is List
        ? List<String>.from(
            (detailMap['offerings'] as List).whereType<String>(),
          )
        : _instructorOfferings;
    final focus = detailMap['levels_offered'] is List
        ? List<String>.from(
            (detailMap['levels_offered'] as List).whereType<String>(),
          )
        : offerings;
    final defaultRate = detailMap['default_rate'];
    final ratesLabel = composeRatesLabel(defaultRate, offeringRates);

    final vehiclePhotoUrl = clean(detailMap['vehicle_photo_url']) ??
        clean(detailMap['vehiclePhotoUrl']) ??
        clean(profileMap['vehicle_photo_url']) ??
        firstVehiclePhoto(detailMap['vehicles']) ??
        firstVehiclePhoto(profileMap['vehicles']) ??
        '';
    final bio = _instructorBio ?? clean(detailMap['bio']) ?? '';
    final serviceArea = _instructorServiceArea ??
        clean(detailMap['service_area']) ??
        clean(profileMap['city']) ??
        '';
    final serviceAreaArea = clean(detailMap['service_area_area']);
    final serviceAreaCity = clean(detailMap['service_area_city']);

    final name = combineName();
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : clean(profileMap['email']) ?? '';
    final phone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : clean(profileMap['phone']) ?? '';

    return {
      'id': profileMap['id'] ?? SupabaseService.currentUser?.id,
      'name': name,
      'email': email,
      'phone': phone,
      'phoneVerifiedAt': clean(profileMap['phone_verified_at']) ?? '',
      'phone_verified_at': clean(profileMap['phone_verified_at']) ?? '',
      'bio': bio,
      'profileImageUrl':
          _profileImageUrl ?? clean(profileMap['profile_image_url']) ?? '',
      'vehiclePhotoUrl': vehiclePhotoUrl,
      'detail': detailMap,
      'serviceArea': serviceArea,
      'serviceAreaArea': serviceAreaArea,
      'serviceAreaCity': serviceAreaCity,
      'car': vehicles.isNotEmpty ? vehicles.first : '',
      'vehicles': vehicles,
      'areas': areas,
      'languages': languages,
      'offerings': offerings,
      'offeringRates': offeringRates,
      'focus': focus,
      'rates': ratesLabel,
      'preferredLocations': preferredLocations,
      'pickupPreference': _instructorPickupPreference,
      'yearsOfExperience': _instructorYearsExperience,
      'isVerified': _isVerified,
      'driveTutorNumber': clean(detailMap['drive_tutor_number']) ?? '',
      'licenseNumber': _licenceNumber ?? clean(profileMap['licence_number']),
      'licenseExpiry': _licenceExpiry?.toIso8601String() ??
          clean(profileMap['licence_expiry']),
      'age': clean(profileMap['age']) ?? '',
      'gender': clean(profileMap['gender']) ?? '',
    };
  }

  Future<void> _openEditProfile() async {
    final result = await context.push<bool>(AppRoutes.editProfile);
    if (result == true) {
      await _loadProfile();
    }
  }

  Future<void> _openInstructorCredentialsPortal() async {
    if (_openingCredentialsPortal) return;
    setState(() => _openingCredentialsPortal = true);
    try {
      await context.push(AppRoutes.instructorCredentialsPortal);
      if (mounted) {
        await _loadProfile();
      }
    } finally {
      if (mounted) {
        setState(() => _openingCredentialsPortal = false);
      }
    }
  }

  Future<void> _showInstructorCodeSheet() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Instructor Code',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the code your instructor shared with you to connect directly after approval.',
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: controller,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Instructor code',
                          hintText: 'B3-387529',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          final cleaned = (value ?? '').replaceAll(
                            RegExp(r'[^A-Za-z0-9]'),
                            '',
                          );
                          if (cleaned.length != 8) {
                            return 'Enter the full instructor code.';
                          }
                          return null;
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setModalState(() {
                                        isSubmitting = true;
                                        error = null;
                                      });
                                      try {
                                        await SupabaseService
                                            .claimInstructorReferralCode(
                                          controller.text,
                                        );
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Instructor connected. They can now manage lessons with you.',
                                            ),
                                          ),
                                        );
                                      } catch (exception) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          error = _referralClaimError(
                                            exception,
                                          );
                                        });
                                      }
                                    },
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Connect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  String _referralClaimError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('learner_not_approved')) {
      return 'Your learner account must be approved before you can connect with an instructor code.';
    }
    if (message.contains('instructor_referral_not_found')) {
      return 'No verified instructor was found for that code.';
    }
    if (message.contains('invalid_referral_code')) {
      return 'Enter the full instructor code.';
    }
    if (message.contains('cannot_claim_own_referral')) {
      return 'You cannot use your own instructor code.';
    }
    return 'Unable to connect with that instructor code. Please try again.';
  }

  Future<void> _showUpdatePasswordSheet() async {
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    String? error;

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a new password';
                          }
                          if (value.trim().length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Confirm your new password';
                          }
                          if (value.trim() !=
                              newPasswordController.text.trim()) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setModalState(() {
                                    isSubmitting = true;
                                    error = null;
                                  });
                                  try {
                                    await SupabaseService.updatePassword(
                                      newPasswordController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.of(context).pop(true);
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isSubmitting = false;
                                      error = e.toString();
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update password'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
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
              this.context.go(AppRoutes.auth);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final detailsController = TextEditingController();
    final confirmController = TextEditingController();
    String reason = 'No longer using Drive Tutor';

    showDialog(
      context: context,
      barrierDismissible: !_isRequestingDeletion,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit =
                confirmController.text.trim().toUpperCase() == 'DELETE';
            return AlertDialog(
              title: const Text('Delete Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This submits an account deletion request. Drive Tutor may retain records required for safety, fraud prevention, legal compliance, pass records, disputes, or law-enforcement requests.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'No longer using Drive Tutor',
                          child: Text('No longer using Drive Tutor'),
                        ),
                        DropdownMenuItem(
                          value: 'Privacy or data concern',
                          child: Text('Privacy or data concern'),
                        ),
                        DropdownMenuItem(
                          value: 'Created account by mistake',
                          child: Text('Created account by mistake'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: _isRequestingDeletion
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => reason = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      enabled: !_isRequestingDeletion,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      enabled: !_isRequestingDeletion,
                      decoration: const InputDecoration(
                        labelText: 'Type DELETE to confirm',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isRequestingDeletion
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isRequestingDeletion || !canSubmit
                      ? null
                      : () async {
                          setDialogState(() => _isRequestingDeletion = true);
                          setState(() => _isRequestingDeletion = true);
                          try {
                            await SupabaseService.requestAccountDeletion(
                              reason: reason,
                              details: detailsController.text,
                            );
                            await SupabaseService.signOut();
                            if (!mounted || !dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Account deletion request submitted.',
                                ),
                                backgroundColor: AppColors.foreground,
                              ),
                            );
                            this.context.go(AppRoutes.auth);
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => _isRequestingDeletion = false);
                            setState(() => _isRequestingDeletion = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to request account deletion: $e',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: _isRequestingDeletion
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Request Deletion'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      detailsController.dispose();
      confirmController.dispose();
      if (mounted) {
        setState(() => _isRequestingDeletion = false);
      }
    });
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Drive Tutor',
      applicationVersion: '1.0.0',
      children: const [
        Text(
          'A friendly platform connecting driving learners with verified instructors in Ontario.',
        ),
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

  String _formatWeeklyAvailabilitySummary() {
    if (_learnerWeeklyAvailability.isEmpty) {
      return 'Not provided';
    }
    final entries = _learnerWeeklyAvailability.entries.toList()
      ..sort((a, b) => _weekdayOrder(a.key).compareTo(_weekdayOrder(b.key)));
    final lines = <String>[];
    for (final entry in entries) {
      final dayLabel = _titleCase(entry.key);
      final slots = entry.value.map(_titleCase).join(', ');
      lines.add('$dayLabel: $slots');
    }
    lines.add(
      "Recurring weekly: ${_learnerAvailabilityRecurring ? 'Yes' : 'No'}",
    );
    return lines.join('\n');
  }

  Map<String, List<String>> _parseWeeklyAvailability(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final day = key.toString().toLowerCase();
        final slots = (value as List?)
                ?.whereType<String>()
                .map((slot) => slot.trim().toLowerCase())
                .where((slot) => slot.isNotEmpty)
                .toSet()
                .toList() ??
            const <String>[];
        if (day.isNotEmpty && slots.isNotEmpty) {
          slots.sort();
          result[day] = slots;
        }
      });
    } else if (raw is Iterable) {
      for (final entry in raw) {
        if (entry is Map) {
          final day = entry['day']?.toString().toLowerCase();
          final slots = (entry['slots'] as List?)
                  ?.whereType<String>()
                  .map((slot) => slot.trim().toLowerCase())
                  .where((slot) => slot.isNotEmpty)
                  .toSet()
                  .toList() ??
              const <String>[];
          if (day != null && day.isNotEmpty && slots.isNotEmpty) {
            slots.sort();
            result[day] = slots;
          }
        }
      }
    }
    return result;
  }

  int _weekdayOrder(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 0;
      case 'tuesday':
        return 1;
      case 'wednesday':
        return 2;
      case 'thursday':
        return 3;
      case 'friday':
        return 4;
      case 'saturday':
        return 5;
      case 'sunday':
        return 6;
      default:
        return 7;
    }
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      return trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  String? _firstString(List<dynamic> values) {
    for (final value in values) {
      final string = _asString(value);
      if (string != null && string.isNotEmpty) return string;
    }
    return null;
  }

  int? _firstInt(List<dynamic> values) {
    for (final value in values) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      final string = _asString(value);
      if (string == null) continue;
      final parsed = int.tryParse(string);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _firstDate(List<dynamic> values) {
    for (final value in values) {
      if (value is DateTime) return value;
      final string = _asString(value);
      if (string == null) continue;
      final parsed = DateTime.tryParse(string);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<String> _locationSummaries(dynamic source) {
    final results = <String>[];
    if (source is List) {
      for (final entry in source) {
        if (entry is Map) {
          final label = _asString(entry['label']);
          final address = _asString(entry['address']);
          final type = _asString(entry['type']);
          final value = label != null && address != null
              ? '$label - $address'
              : address ?? label ?? type;
          if (value != null && value.isNotEmpty) {
            results.add(value);
          }
        } else {
          final value = _asString(entry);
          if (value != null && value.isNotEmpty) {
            results.add(value);
          }
        }
      }
    } else {
      final value = _asString(source);
      if (value != null && value.isNotEmpty) {
        results.add(value);
      }
    }
    return results;
  }

  Map<String, dynamic> _mergeNonNull(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final merged = Map<String, dynamic>.from(base);
    for (final entry in overlay.entries) {
      if (entry.value != null) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _formatRole(String? role) {
    final value = (role ?? 'learner').trim();
    if (value.isEmpty) return 'Learner';
    return value[0].toUpperCase() + value.substring(1);
  }

  String _normalizeRole(dynamic role) {
    final value = _asString(role)?.toLowerCase();
    if (value == 'instructor') return 'instructor';
    return 'learner';
  }
}
