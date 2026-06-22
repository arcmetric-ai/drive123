import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/learner_progress.dart';
import '../../services/supabase_service.dart';
import '../../widgets/verified_profile_badge.dart';
import '../../widgets/lesson_feedback_sheet.dart';

class InstructorLearnerDetailScreen extends StatefulWidget {
  /// Accepts either a full learner map or an object with a 'profile_id' / 'id'.
  final Map<String, dynamic>? learner;

  const InstructorLearnerDetailScreen({super.key, this.learner});

  @override
  State<InstructorLearnerDetailScreen> createState() =>
      _InstructorLearnerDetailScreenState();
}

class _InstructorLearnerDetailScreenState
    extends State<InstructorLearnerDetailScreen> {
  bool _loading = true;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _learner = {};
  List<LearnerProgressSkill> _progressSkills = defaultLearnerProgressSkills();
  String? _progressSavingSkillId;
  static const List<String> _daySequence = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const Map<String, int> _slotOrder = {
    'early': 0,
    'morning': 1,
    'afternoon': 2,
    'evening': 3,
  };
  static const Map<String, String> _slotLabels = {
    'early': 'Early (7am-9am)',
    'morning': 'Morning (9am-12pm)',
    'afternoon': 'Afternoon (12pm-4pm)',
    'evening': 'Evening (4pm-8pm)',
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);

    final passed = widget.learner ?? {};

    // Prefer explicit profile data passed in. If a profile id is provided, fetch raw profile + learner detail.
    final profileId =
        (passed['profile_id'] ?? passed['id'] ?? passed['userId'])?.toString();

    if (profileId != null) {
      final learnerDetail = await SupabaseService.getLearnerProfileDetail(
        profileId,
      );
      final progressRows = await SupabaseService.getLearnerSkillProgress(
        profileId,
      );
      if (learnerDetail != null) {
        setState(() {
          _learner = {...learnerDetail, ...passed};
          _profile = _mapOrNull(learnerDetail['profile']) ?? {};
          _progressSkills = learnerProgressSkillsFromRows(progressRows);
          _normalizeLearnerDetail();
          _loading = false;
        });
      } else {
        // Fallback to fetching raw profile if learner detail is not found
        final rawProfile = await SupabaseService.getRawProfile(profileId);
        setState(() {
          _profile = rawProfile ?? {};
          _learner = passed;
          _progressSkills = learnerProgressSkillsFromRows(progressRows);
          _normalizeLearnerDetail();
          _loading = false;
        });
      }
      return;
    }

    // No id — use passed map values (may be placeholder data).
    setState(() {
      _profile = {
        'email': passed['email'] ?? '',
        'phone': passed['phone'] ?? '',
      };
      _learner = passed;
      _normalizeLearnerDetail();
      _loading = false;
    });
  }

  void _normalizeLearnerDetail() {
    final profileMap = _mapOrNull(_learner['profile']);
    if (profileMap != null) {
      if (_profile.isEmpty) {
        _profile = Map<String, dynamic>.from(profileMap);
      } else {
        _profile.addAll(
          profileMap.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }

    String? _pickString(List<dynamic> candidates) {
      for (final candidate in candidates) {
        final value = _asNullableString(candidate);
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    int? _pickInt(List<dynamic> candidates) {
      for (final candidate in candidates) {
        final value = _asNullableInt(candidate);
        if (value != null) return value;
      }
      return null;
    }

    DateTime? _pickDate(List<dynamic> candidates) {
      for (final candidate in candidates) {
        final value = _asNullableDate(candidate);
        if (value != null) return value;
      }
      return null;
    }

    _learner['email'] ??= _pickString([
      _learner['email'],
      profileMap?['email'],
      _profile['email'],
    ]);
    _learner['phone'] ??= _pickString([
      _learner['phone'],
      profileMap?['phone'],
      _profile['phone'],
    ]);
    _learner['city'] ??= _pickString([
      _learner['city'],
      profileMap?['city'],
      _profile['city'],
    ]);
    _learner['age'] ??= _pickInt([
      _learner['age'],
      profileMap?['age'],
      _profile['age'],
    ]);
    _learner['gender'] ??= _pickString([
      _learner['gender'],
      profileMap?['gender'],
      _profile['gender'],
    ]);

    final licenceNumber = _pickString([
      _learner['licence_number'],
      _learner['license_number'],
      profileMap?['licence_number'],
      profileMap?['license_number'],
      _profile['licence_number'],
      _profile['license_number'],
    ]);
    if (licenceNumber != null) {
      _learner['licence_number'] = licenceNumber;
    }

    final licenceExpiry = _pickDate([
      _learner['licence_expiry'],
      _learner['license_expiry'],
      profileMap?['licence_expiry'],
      profileMap?['license_expiry'],
      _profile['licence_expiry'],
      _profile['license_expiry'],
    ]);
    if (licenceExpiry != null) {
      _learner['licence_expiry'] = licenceExpiry.toIso8601String();
    }

    if (_profile['home_address'] == null &&
        profileMap != null &&
        profileMap['home_address'] != null) {
      _profile['home_address'] = profileMap['home_address'];
    }
    if (_learner['home_address'] == null &&
        profileMap != null &&
        profileMap['home_address'] != null) {
      _learner['home_address'] = profileMap['home_address'];
    }

    final availabilityRaw =
        _learner['weekly_availability'] ?? profileMap?['weekly_availability'];
    if (availabilityRaw != null) {
      _learner['weekly_availability'] = _normalizeWeeklyAvailability(
        availabilityRaw,
      );
    }

    if (_learner['availability_recurring'] == null &&
        profileMap?['availability_recurring'] != null) {
      _learner['availability_recurring'] =
          profileMap?['availability_recurring'];
    }

    final accountType = _asNullableString(_learner['account_type']) ??
        _asNullableString(profileMap?['account_type']);
    if (accountType?.toLowerCase() == 'guardian') {
      final wardFirst = _pickString([
        _learner['ward_first_name'],
        profileMap?['ward_first_name'],
      ]);
      final wardLast = _pickString([
        _learner['ward_last_name'],
        profileMap?['ward_last_name'],
      ]);
      final wardName = [wardFirst, wardLast]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' ')
          .trim();
      if (wardName.isNotEmpty) {
        _learner['name'] = wardName;
      }
      final wardAge = _pickInt([_learner['ward_age'], profileMap?['ward_age']]);
      if (wardAge != null) {
        _learner['age'] = wardAge;
      }
      final wardGender = _pickString([
        _learner['ward_gender'],
        profileMap?['ward_gender'],
      ]);
      if (wardGender != null) {
        _learner['gender'] = wardGender;
      }
    }
  }

  String? _asNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString().trim().isEmpty ? null : value.toString().trim();
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  DateTime? _asNullableDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  bool? _asNullableBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'n') {
        return false;
      }
    }
    return null;
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    return DateFormat('MMM d, yyyy').format(value);
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, List<String>> _normalizeWeeklyAvailability(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final day = key.toString().toLowerCase();
        final slots = (value as List?)
                ?.whereType<String>()
                .map((slot) => slot.toLowerCase())
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
                  .map((slot) => slot.toLowerCase())
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

  List<String> _preferredLocationSummaries() {
    final source = _learner['preferred_locations'] ??
        _profile['preferred_locations'] ??
        _learner['preferredLocations'];
    final results = <String>[];
    if (source is List) {
      for (final entry in source) {
        if (entry is Map) {
          final label = _asNullableString(entry['label']);
          final address = _asNullableString(entry['address']);
          final type = _asNullableString(entry['type']);
          String? value;
          if (label != null && address != null) {
            value = '$label - $address';
          } else if (address != null) {
            value = address;
          } else if (label != null) {
            value = label;
          } else if (type != null) {
            value = type;
          }
          if (value != null && value.isNotEmpty) {
            results.add(value);
          }
        } else if (entry is String && entry.trim().isNotEmpty) {
          results.add(entry.trim());
        }
      }
    } else if (source is String && source.trim().isNotEmpty) {
      results.add(source.trim());
    }
    return results;
  }

  String get _name {
    final explicit = _asNullableString(_learner['name']);
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final profileMap = _mapOrNull(_learner['profile']) ?? _mapOrNull(_profile);
    final first = _asNullableString(profileMap?['first_name']) ??
        _asNullableString(_profile['first_name']);
    final last = _asNullableString(profileMap?['last_name']) ??
        _asNullableString(_profile['last_name']);
    final combined = [first, last]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (combined.isNotEmpty) {
      return combined;
    }
    final fallback = _asNullableString(profileMap?['full_name']) ??
        _asNullableString(profileMap?['name']) ??
        _asNullableString(_profile['full_name']) ??
        _asNullableString(_profile['name']);
    return fallback?.isNotEmpty == true ? fallback! : 'Learner';
  }

  String get _phone {
    final profileMap = _mapOrNull(_learner['profile']) ?? _mapOrNull(_profile);
    return _asNullableString(profileMap?['phone']) ??
        _asNullableString(_profile['phone']) ??
        _asNullableString(_learner['phone']) ??
        '';
  }

  String get _address {
    final profileMap = _mapOrNull(_learner['profile']) ?? _mapOrNull(_profile);
    final addressMap = _learner['home_address'] ??
        _profile['home_address'] ??
        profileMap?['home_address'] ??
        _learner['address'] ??
        _profile['address'];
    if (addressMap is Map<String, dynamic>) {
      final line1 = (addressMap['address_line1'] ?? addressMap['line1'] ?? '')
          .toString()
          .trim();
      final line2 = (addressMap['address_line2'] ?? addressMap['line2'] ?? '')
          .toString()
          .trim();
      final city = (addressMap['city'] ?? '').toString().trim();
      final province = (addressMap['province'] ?? addressMap['state'] ?? '')
          .toString()
          .trim();
      final postal = (addressMap['postal_code'] ?? addressMap['zip'] ?? '')
          .toString()
          .trim();
      final parts = <String>[
        if (line1.isNotEmpty) line1,
        if (line2.isNotEmpty) line2,
        if (city.isNotEmpty) city,
        if (province.isNotEmpty) province,
        if (postal.isNotEmpty) postal,
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return '';
  }

  String? get _relationshipStatus {
    final status = widget.learner?['status'] ??
        _learner['status'] ??
        _learner['requestStatus'] ??
        _learner['learner_status'];
    if (status is String) {
      return status.toLowerCase();
    }
    return null;
  }

  bool get _isActiveLearner {
    const activeStatuses = {'accepted', 'active', 'in_progress'};
    final status = _relationshipStatus;
    if (status == null) return false;
    return activeStatuses.contains(status);
  }

  String? get _learnerProfileId {
    final value = _learner['profile_id'] ??
        _learner['learner_id'] ??
        _learner['id'] ??
        _profile['id'];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  bool get _isVerifiedLearner {
    final direct = _asNullableBool(_profile['is_verified']);
    if (direct != null) return direct;
    final profileMap = _mapOrNull(_learner['profile']);
    final nested = _asNullableBool(profileMap?['is_verified']);
    return nested ?? false;
  }

  String? get _profileImageUrl {
    final direct = _asNullableString(_profile['profile_image_url']);
    if (direct != null) return direct;
    final profileMap = _mapOrNull(_learner['profile']);
    final nested = _asNullableString(profileMap?['profile_image_url']);
    if (nested != null) return nested;
    final fallback = _asNullableString(
      _learner['profileImageUrl'] ??
          _learner['profile_image_url'] ??
          widget.learner?['profile_image_url'],
    );
    return fallback;
  }

  Future<void> _launchPhone() async {
    if (_phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: _phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Map<String, List<String>> _normalizeAvailability(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        final dayRaw = entry['day'];
        final slotsRaw = entry['slots'];
        if (dayRaw == null) continue;
        final day = dayRaw.toString().toLowerCase();
        final slots = slotsRaw is List
            ? slotsRaw
                .whereType<String>()
                .map((slot) => slot.toLowerCase())
                .toList()
            : <String>[];
        if (slots.isEmpty) continue;
        slots.sort(
          (a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99),
        );
        result[day] = slots;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final day = entry.key.toString().toLowerCase();
        final value = entry.value;
        final slots = value is List
            ? value
                .whereType<String>()
                .map((slot) => slot.toLowerCase())
                .toList()
            : <String>[];
        if (slots.isEmpty) continue;
        slots.sort(
          (a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99),
        );
        result[day] = slots;
      }
    }
    return result;
  }

  String _slotLabel(String key) {
    return _slotLabels[key] ?? key;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final parts =
        value.split(RegExp(r'[_\s]+')).where((part) => part.isNotEmpty);
    return parts.map(_capitalize).join(' ');
  }

  Widget _buildWeeklyAvailability() {
    final rawAvailability =
        _learner['weekly_availability'] ?? _profile['weekly_availability'];
    final availability = _normalizeAvailability(rawAvailability);
    if (availability.isEmpty) {
      return const Text('Availability not set.');
    }
    final sortedDays = availability.keys.toList()
      ..sort(
        (a, b) => _daySequence.indexOf(a).compareTo(_daySequence.indexOf(b)),
      );
    final recurring = (_learner['availability_recurring'] ??
            _profile['availability_recurring']) ==
        true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          runSpacing: 8,
          spacing: 8,
          children: [
            for (final day in sortedDays)
              _AvailabilityPill(
                day: _capitalize(day),
                slots: availability[day]!.map(_slotLabel).toList(),
              ),
          ],
        ),
        if (recurring)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Repeats monthly',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ocean,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _isActiveLearner
                    ? _buildContactRow(context)
                    : _buildInfoCard(
                        title: 'Contact',
                        child: Text(
                          'Contact details become available after you accept this learner.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                const SizedBox(height: 16),
                _buildLearnerSummaryCard(),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: 'Progress & focus areas',
                  child: _buildProgressEditor(),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: 'Weekly availability',
                  child: _buildWeeklyAvailability(),
                ),
                if (_learnerProfileId != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showUserReportSheet(
                      context,
                      reportedUserId: _learnerProfileId!,
                      reportedUserName: _name,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report learner'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final upcoming = (_learner['upcoming'] as String?) ??
        (_learner['upcoming_lesson'] as String?) ??
        '';
    final level = (_learner['level'] as String?) ??
        (_learner['learning_focus'] as String?) ??
        '';
    final imageUrl = _profileImageUrl;
    final isVerified = _isVerifiedLearner;
    final status = _relationshipStatus;
    final statusLabel = status != null ? _titleCase(status) : null;
    final bool showStatusChip = statusLabel != null && !_isActiveLearner;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? Text(
                    _name.isNotEmpty ? _name[0] : '?',
                    style: const TextStyle(
                      color: AppColors.ocean,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isVerified) const _VerifiedBadge(),
                  ],
                ),
                if (level.isNotEmpty)
                  Text(
                    level,
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                if (showStatusChip) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Status: $statusLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      upcoming,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phone',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _phone.isNotEmpty ? _phone : 'Phone not set',
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _launchPhone,
            icon: const Icon(Icons.phone_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnerSummaryCard() {
    final profileMap = _mapOrNull(_learner['profile']) ?? _mapOrNull(_profile);
    final city = _asNullableString(
      profileMap?['city'] ?? _learner['city'] ?? _profile['city'],
    );
    final age = _asNullableInt(
      profileMap?['age'] ?? _learner['age'] ?? _profile['age'],
    );
    final gender = _asNullableString(
      profileMap?['gender'] ?? _learner['gender'] ?? _profile['gender'],
    );
    final classesTaken = _asNullableInt(
      _learner['classes_taken_sofar'] ?? _learner['classes_taken'],
    );
    final lastClassDate = _asNullableDate(_learner['last_class_date']);
    final targetTestDate = _asNullableDate(
      _learner['target_test_date'] ??
          _learner['g1_test_date'] ??
          _learner['test_date'],
    );
    final preferredLocations = _preferredLocationSummaries();

    final details = <Widget>[
      _detailRow('City', city ?? 'Not provided'),
      _detailRow('Age', age != null ? '$age years' : 'Not provided'),
      _detailRow('Gender', gender ?? 'Not provided'),
      _detailRow(
        'Lessons completed',
        classesTaken != null
            ? '$classesTaken lesson${classesTaken == 1 ? '' : 's'}'
            : 'Not provided',
      ),
      _detailRow(
        'Last class',
        lastClassDate != null
            ? _formatDate(lastClassDate) ?? 'Not provided'
            : 'Not provided',
      ),
      _detailRow(
        'Upcoming test',
        targetTestDate != null
            ? _formatDate(targetTestDate) ?? 'Not provided'
            : 'Not provided',
      ),
    ];

    final children = <Widget>[
      ...details,
      if (_isActiveLearner) ...[
        const SizedBox(height: 4),
        Text(
          'Preferred locations',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        preferredLocations.isNotEmpty
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferredLocations
                    .map((location) => Chip(label: Text(location)))
                    .toList(),
              )
            : Text('Not provided', style: TextStyle(color: Colors.grey[600])),
      ],
    ];

    return _buildInfoCard(
      title: 'Learner details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color labelColor = const Color(0xFF6B7280),
    Color valueColor = const Color(0xFF1F2933),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressEditor() {
    final readyCount =
        _progressSkills.where((skill) => skill.status.isTestReady).length;
    final progress = _progressSkills.isEmpty
        ? 0.0
        : _progressSkills.fold<double>(
              0,
              (sum, skill) => sum + skill.status.score,
            ) /
            _progressSkills.length;
    final focusAreas = ((_learner['focusAreas'] as List?) ??
            (_learner['focus_areas'] as List?) ??
            [])
        .whereType<String>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.grey200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.ocean,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$readyCount/${_progressSkills.length} ready',
              style: const TextStyle(
                color: AppColors.ocean,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (!_isActiveLearner) ...[
          const SizedBox(height: 10),
          Text(
            'Accept this learner before updating progress.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
        if (focusAreas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children:
                focusAreas.map((focus) => Chip(label: Text(focus))).toList(),
          ),
        ],
        const SizedBox(height: 12),
        for (final skill in _progressSkills) ...[
          _ProgressSkillEditorTile(
            skill: skill,
            enabled: _isActiveLearner && _learnerProfileId != null,
            isSaving: _progressSavingSkillId == skill.id,
            onChanged: (status) => _updateSkillProgress(skill, status),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _updateSkillProgress(
    LearnerProgressSkill skill,
    LearnerSkillStatus status,
  ) async {
    final learnerId = _learnerProfileId;
    if (learnerId == null || _progressSavingSkillId != null) return;

    final previousSkills = List<LearnerProgressSkill>.from(_progressSkills);
    final now = DateTime.now().toUtc();
    setState(() {
      _progressSavingSkillId = skill.id;
      _progressSkills = _progressSkills.map((item) {
        if (item.id != skill.id) return item;
        return item.copyWith(
          status: status,
          completedAt: status.isTestReady ? now : null,
          updatedAt: now,
        );
      }).toList();
    });

    try {
      await SupabaseService.upsertLearnerSkillProgress(
        userId: learnerId,
        skillId: skill.id,
        status: status.storageValue,
        updatedByRole: 'instructor',
      );
      if (!mounted) return;
      setState(() => _progressSavingSkillId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${skill.name} set to ${status.label}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progressSkills = previousSkills;
        _progressSavingSkillId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update progress: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _ProgressSkillEditorTile extends StatelessWidget {
  const _ProgressSkillEditorTile({
    required this.skill,
    required this.enabled,
    required this.isSaving,
    required this.onChanged,
  });

  final LearnerProgressSkill skill;
  final bool enabled;
  final bool isSaving;
  final ValueChanged<LearnerSkillStatus> onChanged;

  Color get _statusColor {
    switch (skill.status) {
      case LearnerSkillStatus.notStarted:
        return Colors.grey;
      case LearnerSkillStatus.practicing:
        return AppColors.info;
      case LearnerSkillStatus.confident:
        return AppColors.warning;
      case LearnerSkillStatus.testReady:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(skill.icon, color: _statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skill.description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<LearnerSkillStatus>(
            initialValue: skill.status,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: LearnerSkillStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: enabled && !isSaving
                ? (status) {
                    if (status != null && status != skill.status) {
                      onChanged(status);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ocean.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          VerifiedProfileBadge(size: 18),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.day, required this.slots});

  final String day;
  final List<String> slots;

  @override
  Widget build(BuildContext context) {
    final chipColor = AppColors.lightSurface.withOpacity(0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: slots
                .map(
                  (slot) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Text(
                      slot,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
