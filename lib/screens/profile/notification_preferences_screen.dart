import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/push_notification_service.dart';
import '../../services/supabase_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  Map<String, dynamic> _prefs = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isLearner {
    final role = SupabaseService.currentUser?.userMetadata?['role']?.toString();
    return role == null || role != 'instructor';
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SupabaseService.getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load notification settings.';
        _loading = false;
      });
    }
  }

  bool _enabled(String key) => _prefs[key] != false;

  Future<void> _setPreference(String key, bool value) async {
    if (_saving) return;
    final previous = Map<String, dynamic>.from(_prefs);
    setState(() {
      _saving = true;
      _prefs = {
        ..._prefs,
        key: value,
      };
    });

    try {
      final saved = await SupabaseService.updateNotificationPreferences({
        key: value,
      });
      if (key == 'fcm_enabled') {
        if (value) {
          await PushNotificationService.registerCurrentDevice();
        } else {
          await PushNotificationService.revokeCurrentDevice();
        }
      }
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _prefs = previous;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save notification settings: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notification Centre',
          style: TextStyle(color: AppColors.foreground),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadPreferences)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      _isLearner
                          ? 'Choose how Drive Tutor keeps you updated about lessons, reminders, instructor changes, and account status. Important alerts start enabled after you allow notifications.'
                          : 'Choose what Drive Tutor can send you. If you allowed notifications, everything important starts enabled and you can change it here anytime.',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PreferenceSection(
                      title: 'Delivery',
                      children: [
                        _PreferenceTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Push notifications',
                          subtitle:
                              'Receive Drive Tutor alerts on this device.',
                          value: _enabled('fcm_enabled'),
                          enabled: !_saving,
                          onChanged: (value) =>
                              _setPreference('fcm_enabled', value),
                        ),
                        _PreferenceTile(
                          icon: Icons.email_outlined,
                          title: 'Email notifications',
                          subtitle:
                              'Receive important account emails where available.',
                          value: _enabled('email_enabled'),
                          enabled: !_saving,
                          onChanged: (value) =>
                              _setPreference('email_enabled', value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PreferenceSection(
                      title: 'Notification types',
                      children: [
                        _PreferenceTile(
                          icon: Icons.alarm_outlined,
                          title: 'Lesson reminders',
                          subtitle: _isLearner
                              ? 'Get reminders before your confirmed driving lessons.'
                              : 'Reminders before scheduled driving lessons.',
                          value: _enabled('lesson_reminders_enabled'),
                          enabled: !_saving && _enabled('fcm_enabled'),
                          onChanged: (value) => _setPreference(
                            'lesson_reminders_enabled',
                            value,
                          ),
                        ),
                        _PreferenceTile(
                          icon: Icons.event_available_outlined,
                          title: 'Lesson updates',
                          subtitle: _isLearner
                              ? 'Know when lessons are booked, changed, cancelled, or confirmed.'
                              : 'Booking, schedule, cancellation, and request updates.',
                          value: _enabled('lesson_updates_enabled'),
                          enabled: !_saving && _enabled('fcm_enabled'),
                          onChanged: (value) => _setPreference(
                            'lesson_updates_enabled',
                            value,
                          ),
                        ),
                        _PreferenceTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Account and verification updates',
                          subtitle: _isLearner
                              ? 'Updates about your learner profile, verification, and account access.'
                              : 'Review, approval, document, and account status updates.',
                          value: _enabled('review_updates_enabled'),
                          enabled: !_saving && _enabled('fcm_enabled'),
                          onChanged: (value) => _setPreference(
                            'review_updates_enabled',
                            value,
                          ),
                        ),
                        _PreferenceTile(
                          icon: Icons.campaign_outlined,
                          title: 'General notifications',
                          subtitle: _isLearner
                              ? 'Product notices and support updates related to your learner account.'
                              : 'Service announcements and support-related updates.',
                          value: _enabled('support_updates_enabled'),
                          enabled: !_saving && _enabled('fcm_enabled'),
                          onChanged: (value) => _setPreference(
                            'support_updates_enabled',
                            value,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(
        icon,
        color: enabled ? AppColors.primaryBlue : AppColors.mutedForeground,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.mutedForeground),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              color: AppColors.mutedForeground,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.foreground),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
