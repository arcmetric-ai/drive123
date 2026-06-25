import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/ontario_locations.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/verified_profile_badge.dart';
import '../../widgets/lesson_feedback_sheet.dart';

class LearnerInstructorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const LearnerInstructorDetailScreen({super.key, required this.profile});

  @override
  State<LearnerInstructorDetailScreen> createState() =>
      _LearnerInstructorDetailScreenState();
}

class _LearnerInstructorDetailScreenState
    extends State<LearnerInstructorDetailScreen> {
  late final Map<String, dynamic> _profile;
  Map<String, dynamic>? _requestContext;

  bool _checkingRequest = true;
  bool _processing = false;
  String? _requestStatus;
  String? _requestId;
  bool _isSuppressed = false;
  DateTime? _cancelledAt;
  final TextEditingController _messageController = TextEditingController();
  String? _selectedVehicleLabel;
  String? _selectedVehicleType;

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _requestContext = _profile.remove('__request') as Map<String, dynamic>?;
    final contextStatus = _requestContext?['status'] as String?;
    final contextRequestId = _requestContext?['requestId'] as String?;
    final suppressedFlag = _requestContext?['suppressed'] == true;
    final cancelledAtIso = _requestContext?['cancelledAt'] as String?;
    if (contextRequestId != null && contextRequestId.isNotEmpty) {
      _requestId = contextRequestId;
    }
    if (cancelledAtIso != null && cancelledAtIso.isNotEmpty) {
      _cancelledAt = DateTime.tryParse(cancelledAtIso);
    }
    if (contextStatus != null) {
      if (contextStatus == 'suppressed_cancelled') {
        _requestStatus = null;
        _isSuppressed = true;
      } else {
        _requestStatus = contextStatus;
      }
    }
    if (suppressedFlag) {
      _isSuppressed = true;
    }
    _syncSelectedVehicle();
    _hydrateInstructorProfile();
    _loadExistingRequest();
  }

  Future<void> _loadExistingRequest() async {
    final instructorId = _requestContext?['instructorId'] as String?;
    final learnerId = SupabaseService.currentUser?.id;
    if (mounted) {
      setState(() {
        _checkingRequest = true;
      });
    } else {
      _checkingRequest = true;
    }
    if (instructorId == null || instructorId.isEmpty || learnerId == null) {
      setState(() {
        _checkingRequest = false;
        _requestStatus = null;
        _requestId = null;
      });
      return;
    }
    if (_isSuppressed) {
      setState(() {
        _checkingRequest = false;
        _requestStatus = null;
      });
      return;
    }

    try {
      final existing = await SupabaseService.getActiveLessonRequest(
        instructorId: instructorId,
        learnerId: learnerId,
      );
      if (!mounted) return;
      setState(() {
        _checkingRequest = false;
        _requestStatus = existing?['status'] as String?;
        _requestId = existing?['id'] as String?;
        final existingMessage = existing?['message'] as String?;
        final existingVehicleLabel =
            existing?['requested_vehicle_label'] as String?;
        final existingVehicleType =
            existing?['requested_vehicle_type'] as String?;
        if (existingMessage != null && existingMessage.trim().isNotEmpty) {
          _messageController.text = existingMessage.trim();
        }
        if (existingVehicleLabel != null &&
            existingVehicleLabel.trim().isNotEmpty) {
          _selectedVehicleLabel = existingVehicleLabel.trim();
        }
        if (existingVehicleType != null &&
            existingVehicleType.trim().isNotEmpty) {
          _selectedVehicleType = existingVehicleType.trim();
        }
        if (_requestStatus != 'pending') {
          _isSuppressed = false;
          _cancelledAt = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingRequest = false;
        _requestStatus = null;
        _requestId = null;
      });
    }
  }

  Future<void> _hydrateInstructorProfile() async {
    final instructorId =
        (_profile['id'] ?? _profile['profile_id'] ?? _profile['profileId'])
            ?.toString();
    if (instructorId == null || instructorId.isEmpty) {
      return;
    }

    try {
      final detail = await SupabaseService.getInstructorProfileDetail(
        instructorId,
      );
      final profile = await SupabaseService.getRawProfile(instructorId);

      if (!mounted) return;
      setState(() {
        if (detail is Map<String, dynamic>) {
          final detailMap = Map<String, dynamic>.from(detail);
          _profile['detail'] = detailMap;
          final vehicles = detailMap['vehicles'];
          if (vehicles is List) {
            _profile['vehicles'] = vehicles;
          }
          final preferredLocations = detailMap['preferred_locations'];
          if (preferredLocations is List &&
              (_profile['preferredLocationsRaw'] == null ||
                  (_profile['preferredLocationsRaw'] as List).isEmpty)) {
            _profile['preferredLocationsRaw'] = preferredLocations;
          }
          _profile['pickupPreference'] ??= detailMap['pickup_preference'];
          _profile['locationNotes'] ??= detailMap['preferred_location_notes'];
          _profile['yearsOfExperience'] ??= detailMap['years_of_experience'];
          _profile['driveTutorNumber'] ??= detailMap['drive_tutor_number'];
          _profile['bio'] ??= detailMap['bio'];
        }
        if (profile is Map<String, dynamic>) {
          final profileMap = Map<String, dynamic>.from(profile);
          _profile['profileId'] ??= profileMap['id'];
          _profile['first_name'] ??= profileMap['first_name'];
          _profile['last_name'] ??= profileMap['last_name'];
          _profile['email'] ??= profileMap['email'];
          _profile['phone'] ??= profileMap['phone'];
          _profile['phoneVerifiedAt'] ??= profileMap['phone_verified_at'];
          _profile['isVerified'] ??= profileMap['is_verified'];
          _profile['licenseNumber'] ??= profileMap['licence_number'];
          _profile['licenseExpiry'] ??= profileMap['licence_expiry'];
          final languages = profileMap['languages'];
          if (languages is List &&
              (_profile['languages'] == null ||
                  (_profile['languages'] as List).isEmpty)) {
            _profile['languages'] =
                languages.whereType<String>().map((e) => e.trim()).toList();
          }
        }
        _syncSelectedVehicle();
      });
    } catch (error) {
      debugPrint('Error loading instructor profile: $error');
    } finally {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestAction() async {
    final instructorId = _requestContext?['instructorId'] as String?;
    final learnerId = SupabaseService.currentUser?.id;
    if (instructorId == null || instructorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing instructor information.')),
      );
      return;
    }

    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to request a lesson.')),
      );
      return;
    }

    if (_processing) return;
    setState(() => _processing = true);

    try {
      if (_requestStatus == 'pending' && _requestId != null) {
        await SupabaseService.cancelLessonRequest(_requestId!);
        if (!mounted) return;
        setState(() {
          _requestStatus = null;
          _requestId = null;
          _isSuppressed = true;
          _cancelledAt = DateTime.now();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request cancelled.')));
      } else if (_requestStatus == null) {
        final focus = (_requestContext?['focus'] as String?)?.trim();
        final messageText = _messageController.text.trim();
        await SupabaseService.createLessonRequest(
          instructorId: instructorId,
          learnerId: learnerId,
          focus: focus?.isNotEmpty == true ? focus : null,
          message: messageText.isNotEmpty ? messageText : null,
          requestedVehicleLabel: _selectedVehicleLabel,
          requestedVehicleType: _selectedVehicleType,
        );
        if (!mounted) return;
        setState(() {
          _requestStatus = 'pending';
          _isSuppressed = false;
          _cancelledAt = null;
        });
        await _loadExistingRequest();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent to the instructor.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString().replaceFirst('Exception: ', '');
      final message = errorText == OntarioLocations.requestRestrictionMessage
          ? errorText
          : 'Unable to update request: $errorText';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _handleRemoveInstructor() async {
    final instructorId = _requestContext?['instructorId'] as String? ??
        (_profile['id'] ?? _profile['profile_id'] ?? _profile['profileId'])
            ?.toString();
    if (instructorId == null || instructorId.isEmpty || _processing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove instructor?'),
        content: const Text(
          'This removes the instructor from your active learner list and cancels scheduled lessons with them. If this account came from an instructor invite, open instructor search will require identity verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Instructor'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      final result = await SupabaseService.removeCurrentLearnerInstructor(
        instructorId: instructorId,
      );
      if (!mounted) return;
      final requiresVerification = result['requiresVerification'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requiresVerification
                ? 'Instructor removed. Verify your identity to use open instructor search.'
                : 'Instructor removed.',
          ),
        ),
      );
      if (requiresVerification) {
        context.go(AppRoutes.identityVerificationIntro, extra: 'learner');
        return;
      }
      setState(() {
        _requestStatus = null;
        _requestId = null;
        _isSuppressed = true;
        _cancelledAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove instructor: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Map<String, dynamic> _resultPayload() {
    final payload = <String, dynamic>{};
    if (_requestStatus != null) {
      payload['status'] = _requestStatus;
    }
    if (_requestId != null) {
      payload['requestId'] = _requestId;
    }
    if (_isSuppressed) {
      payload['suppressed'] = true;
      if (_cancelledAt != null) {
        payload['cancelledAt'] = _cancelledAt!.toIso8601String();
      }
    }
    return payload;
  }

  String? get _relationshipStatus {
    final status = _requestStatus ??
        (_requestContext?['status'] as String?) ??
        (_profile['status'] as String?) ??
        (_profile['relationshipStatus'] as String?);
    return status?.toLowerCase();
  }

  bool get _hasActiveRelationship {
    const activeStatuses = {'accepted', 'active', 'in_progress'};
    final status = _relationshipStatus;
    if (status == null) return false;
    return activeStatuses.contains(status);
  }

  bool get _isVerifiedInstructor {
    final direct = _profile['isVerified'];
    final parsedDirect = _asNullableBool(direct);
    if (parsedDirect != null) {
      return parsedDirect;
    }
    final user = _profile['user'];
    if (user is Map) {
      final nested = _asNullableBool(user['is_verified']);
      if (nested != null) {
        return nested;
      }
    }
    final profileVerified = _profile['profile'] is Map
        ? _asNullableBool((_profile['profile'] as Map)['is_verified'])
        : null;
    return profileVerified ?? false;
  }

  void _closeWithResult() {
    if (!Navigator.of(context).canPop()) {
      return;
    }
    final payload = _resultPayload();
    if (payload.isEmpty) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop(payload);
    }
  }

  Future<bool> _handleWillPop() async {
    _closeWithResult();
    return false;
  }

  List<String> _asStringList(String key) {
    final value = _profile[key];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  String? _asNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
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

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<String> _vehicleSummaries({bool concealPlate = false}) {
    final rawVehicles = _profile['vehicles'];
    final vehicles = <String>[];
    if (rawVehicles is List) {
      for (final entry in rawVehicles) {
        if (entry is Map) {
          final type = _asNullableString(entry['type']);
          final year = _asNullableString(entry['year']);
          final make = _asNullableString(entry['make']);
          final model = _asNullableString(entry['model']);
          final plate = _asNullableString(entry['numberPlate']);

          final makeModelParts = <String>[];
          if (year != null) makeModelParts.add(year);
          if (make != null) makeModelParts.add(make);
          if (model != null) makeModelParts.add(model);
          final makeModel =
              makeModelParts.isNotEmpty ? makeModelParts.join(' ') : null;

          final segments = <String>[];
          if (type != null) segments.add(type);
          if (makeModel != null && makeModel.isNotEmpty) {
            segments.add(makeModel);
          }
          if (plate != null && plate.isNotEmpty) {
            segments.add('Plate: $plate');
          }
          final summary = segments.join(' - ').trim();
          if (summary.isNotEmpty) {
            vehicles.add(concealPlate ? _concealPlate(summary) : summary);
          }
        } else if (entry is String) {
          final label = entry.trim();
          if (label.isNotEmpty) {
            vehicles.add(concealPlate ? _concealPlate(label) : label);
          }
        }
      }
    }
    return vehicles;
  }

  String? _firstVehiclePhoto(dynamic vehicles) {
    if (vehicles is List) {
      for (final entry in vehicles) {
        if (entry is Map) {
          final url = _asNullableString(entry['photoUrl']) ??
              _asNullableString(entry['photo_url']) ??
              _asNullableString(entry['imageUrl']) ??
              _asNullableString(entry['image_url']);
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      }
    }
    return null;
  }

  String? _resolveVehiclePhotoUrl() {
    final directUrl = _asNullableString(_profile['vehiclePhotoUrl']) ??
        _asNullableString(_profile['vehicle_photo_url']);
    if (directUrl != null) return directUrl;

    final detailMap = _mapOrNull(_profile['detail']);
    final detailUrl = _asNullableString(detailMap?['vehiclePhotoUrl']) ??
        _asNullableString(detailMap?['vehicle_photo_url']);
    if (detailUrl != null) return detailUrl;

    final fromProfileVehicles = _firstVehiclePhoto(_profile['vehicles']);
    if (fromProfileVehicles != null) return fromProfileVehicles;

    return _firstVehiclePhoto(detailMap?['vehicles']);
  }

  Map<String, String> _asStringMap(String key) {
    final value = _profile[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  String _readString(String key, {String fallback = ''}) {
    final value = _profile[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (key == 'serviceArea') {
      final directValue = _profile['serviceArea'] as String?;
      if (directValue != null && directValue.trim().isNotEmpty) {
        return directValue.trim();
      }
      final areaValue = _profile['serviceAreaArea'] as String?;
      final cityValue = _profile['serviceAreaCity'] as String?;
      final composed = _composeServiceAreaLabel(areaValue, cityValue);
      if (composed != null && composed.trim().isNotEmpty) {
        return composed.trim();
      }
      final userCity = (_profile['user'] as Map?)?['city'] as String?;
      if (userCity != null && userCity.trim().isNotEmpty) {
        return userCity.trim();
      }
    }
    return fallback;
  }

  String? _composeServiceAreaLabel(String? area, String? city) {
    final parts = <String>[];
    if (area != null && area.trim().isNotEmpty) {
      parts.add(area.trim());
    }
    if (city != null && city.trim().isNotEmpty) {
      parts.add(city.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(' - ');
  }

  String _concealPlate(String value) {
    final index = value.toLowerCase().indexOf('plate:');
    if (index == -1) return value;
    var sanitized = value.substring(0, index).trim();
    sanitized = sanitized.replaceAll(RegExp(r'[-–—]\s*$'), '').trim();
    return sanitized;
  }

  String _labelForOffering(String code) {
    switch (code.trim().toUpperCase()) {
      case 'G2':
        return 'G2 Road Test';
      case 'G':
        return 'G Road Test';
      case 'PR':
        return 'Refresher Lessons';
      default:
        return code.trim().isEmpty ? 'Lesson' : code.trim();
    }
  }

  String _formatLanguage(String language) {
    final trimmed = language.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  List<_VehicleRequestOption> _vehicleRequestOptions({
    required bool concealPlate,
  }) {
    final rawVehicles = _profile['vehicles'];
    final options = <_VehicleRequestOption>[];
    if (rawVehicles is List) {
      for (final entry in rawVehicles) {
        if (entry is Map) {
          final type = _asNullableString(entry['type']);
          final year = _asNullableString(entry['year']);
          final make = _asNullableString(entry['make']);
          final model = _asNullableString(entry['model']);
          final plate = _asNullableString(entry['numberPlate']);
          final makeModel = [
            if (year != null) year,
            if (make != null) make,
            if (model != null) model,
          ].join(' ').trim();
          var label = [
            if (type != null) type,
            if (makeModel.isNotEmpty) makeModel,
            if (plate != null) 'Plate: $plate',
          ].where((value) => value.isNotEmpty).join(' - ').trim();
          if (concealPlate) {
            label = _concealPlate(label);
          }
          if (label.isNotEmpty) {
            options.add(_VehicleRequestOption(label: label, type: type ?? ''));
          }
        } else if (entry is String) {
          final value =
              concealPlate ? _concealPlate(entry.trim()) : entry.trim();
          if (value.isNotEmpty) {
            options.add(_VehicleRequestOption(label: value, type: ''));
          }
        }
      }
    }
    return options;
  }

  void _syncSelectedVehicle() {
    final options = _vehicleRequestOptions(concealPlate: true);
    if (options.isEmpty) {
      _selectedVehicleLabel = null;
      _selectedVehicleType = null;
      return;
    }
    final matchedType = (_requestContext?['matchedVehicleType'] as String?)
        ?.trim()
        .toLowerCase();
    final currentIndex = options.indexWhere(
      (option) => option.label == _selectedVehicleLabel,
    );
    if (currentIndex != -1) {
      _selectedVehicleType = options[currentIndex].type;
      return;
    }
    if (matchedType != null && matchedType.isNotEmpty) {
      for (final option in options) {
        if (option.type.trim().toLowerCase() == matchedType) {
          _selectedVehicleLabel = option.label;
          _selectedVehicleType = option.type;
          return;
        }
      }
    }
    if (options.length == 1) {
      _selectedVehicleLabel = options.first.label;
      _selectedVehicleType = options.first.type;
    } else {
      _selectedVehicleLabel = options.first.label;
      _selectedVehicleType = options.first.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _readString('name', fallback: 'Drive Tutor Instructor');
    final age = _readString('age', fallback: 'Age not provided');
    final gender = _readString('gender', fallback: 'Gender not provided');
    final profileImageUrl = _readString('profileImageUrl');
    final vehiclePhotoUrl = _resolveVehiclePhotoUrl();
    final vehicleSummaries = _vehicleSummaries(
      concealPlate: !_hasActiveRelationship,
    );
    var vehicleSummary = vehicleSummaries.isNotEmpty
        ? vehicleSummaries.first
        : _concealPlate(
            _readString('car', fallback: 'Vehicle details not provided'),
          );
    if (vehicleSummary.isEmpty) {
      vehicleSummary = 'Vehicle details not provided';
    }
    final serviceArea = _readString(
      'serviceArea',
      fallback: 'Service area not provided',
    );
    final languages = List<String>.from(_asStringList('languages'));
    final offerings = List<String>.from(_asStringList('offerings'));
    final offeringRates = _asStringMap('offeringRates');
    final ratesFallback = _readString(
      'rates',
      fallback: 'Rates not provided yet.',
    );
    final vehicleOptions = _vehicleRequestOptions(
      concealPlate: !_hasActiveRelationship,
    );
    final preferredLocations = List<String>.from(
      _asStringList('preferredLocations'),
    );
    if (preferredLocations.isEmpty) {
      final rawPreferred = _profile['preferredLocationsRaw'];
      if (rawPreferred is List) {
        for (final entry in rawPreferred) {
          if (entry is Map) {
            final label = _asNullableString(entry['label']);
            final address = _asNullableString(entry['address']);
            final caption = entry['type'];
            String? combined;
            if (label != null && address != null) {
              combined = '$label - $address';
            } else if (address != null) {
              combined = address;
            } else if (label != null) {
              combined = label;
            } else if (caption is String && caption.trim().isNotEmpty) {
              combined = caption.trim();
            }
            if (combined != null && combined.isNotEmpty) {
              preferredLocations.add(combined);
            }
          } else if (entry is String && entry.trim().isNotEmpty) {
            preferredLocations.add(entry.trim());
          }
        }
      }
    }
    final detailMap = _mapOrNull(_profile['detail']);
    final profileRecord =
        _mapOrNull(detailMap?['profile']) ?? _mapOrNull(_profile['profile']);
    if (languages.isEmpty) {
      final profileLanguages = profileRecord?['languages'];
      if (profileLanguages is List) {
        languages.addAll(
          profileLanguages
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
    }
    final bool? pickupPreference = _asNullableBool(
      _profile['pickupPreference'] ?? detailMap?['pickup_preference'],
    );
    final int? yearsOfExperience = _asNullableInt(
      _profile['yearsOfExperience'] ?? detailMap?['years_of_experience'],
    );
    final String? locationNotes = _asNullableString(
      _profile['locationNotes'] ?? detailMap?['preferred_location_notes'],
    );
    final String? bio = _asNullableString(_profile['bio'] ?? detailMap?['bio']);
    final String? phone = _asNullableString(
      _profile['phone'] ??
          (_profile['user'] as Map?)?['phone'] ??
          profileRecord?['phone'],
    );
    final bool showContactInfo =
        _hasActiveRelationship && ((phone ?? '').isNotEmpty);
    final bool showLocationNotes = _hasActiveRelationship &&
        (locationNotes != null && locationNotes.isNotEmpty);
    final bool isVerified = _isVerifiedInstructor;
    final bool phoneVerified = _asNullableString(
          _profile['phoneVerifiedAt'] ??
              _profile['phone_verified_at'] ??
              (_profile['user'] as Map?)?['phone_verified_at'] ??
              profileRecord?['phone_verified_at'],
        ) !=
        null;
    final String? displayAge = age == 'Age not provided' ? null : age;
    final String? displayGender =
        gender == 'Gender not provided' ? null : gender;
    final String subtitleLine = [
      displayAge,
      displayGender,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' \u2022 ');

    final bool isPending = _requestStatus == 'pending';
    final bool isAccepted = _requestStatus == 'accepted';
    final bool isDeclined = _requestStatus == 'declined';
    final bool canRequest =
        !_isSuppressed && (_requestStatus == null || isDeclined);
    final bool canEditMessage =
        !isPending && !_isSuppressed && (_requestStatus == null || isDeclined);
    final String requestButtonLabel =
        isDeclined ? 'Request Again' : 'Request Lesson';

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeWithResult,
            ),
            title: const Text('Instructor Details'),
          ),
          body: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      _ProfileImage(
                        imageUrl: profileImageUrl,
                        fallbackInitial: name.isNotEmpty ? name[0] : '?',
                        isVerified: isVerified,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (subtitleLine.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitleLine,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Bio',
                  child: Text(
                    bio?.isNotEmpty == true
                        ? bio!
                        : 'This instructor hasn\'t added a bio yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Verified details',
                  child: Row(
                    children: [
                      _PublicVerificationItem(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        verified: isVerified,
                      ),
                      _PublicVerificationItem(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        verified: phoneVerified,
                      ),
                      _PublicVerificationItem(
                        icon: Icons.badge_outlined,
                        label: 'Licence',
                        verified: isVerified,
                      ),
                    ],
                  ),
                ),
                if (showContactInfo) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Contact',
                    child: _DetailRow(label: 'Phone', value: phone!),
                  ),
                ],
                if (showContactInfo) const SizedBox(height: 16),
                _DetailSection(
                  title: 'Teaching Vehicle',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (vehiclePhotoUrl != null &&
                          vehiclePhotoUrl.trim().isNotEmpty) ...[
                        _VehiclePhotoPreview(imageUrl: vehiclePhotoUrl),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        vehicleSummary,
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[800]),
                      ),
                      for (final extra in vehicleSummaries.skip(1))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            extra,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Service Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Service area', value: serviceArea),
                      if (yearsOfExperience != null) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Years of experience',
                          value: yearsOfExperience == 1
                              ? '1 year'
                              : '$yearsOfExperience years',
                        ),
                      ],
                      if (pickupPreference != null) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Learner pickup',
                          value: pickupPreference ? 'Offered' : 'Not offered',
                        ),
                      ],
                      if (preferredLocations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Preferred locations',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: preferredLocations
                              .map(
                                (location) => Chip(
                                  label: Text(location),
                                  backgroundColor: AppColors.ocean.withOpacity(
                                    0.08,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (offerings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Services offered',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: offerings
                              .map(
                                (offering) => Chip(
                                  label: Text(_labelForOffering(offering)),
                                  backgroundColor:
                                      AppColors.primaryBlue.withOpacity(
                                    0.12,
                                  ),
                                  labelStyle: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (showLocationNotes) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Location notes',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          locationNotes,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Languages',
                  child: languages.isEmpty
                      ? Text(
                          'Languages not provided yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: languages
                              .map(_formatLanguage)
                              .where((language) => language.isNotEmpty)
                              .map(
                                (language) => Chip(
                                  label: Text(language),
                                  backgroundColor: AppColors.ocean.withOpacity(
                                    0.1,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                if (canRequest && vehicleOptions.isNotEmpty) ...[
                  _DetailSection(
                    title: 'Preferred Vehicle',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: vehicleOptions.any(
                        (option) => option.label == _selectedVehicleLabel,
                      )
                          ? _selectedVehicleLabel
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Choose the vehicle you want to learn in',
                        border: OutlineInputBorder(),
                      ),
                      items: vehicleOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.label,
                              child: Text(
                                option.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _processing
                          ? null
                          : (value) {
                              if (value == null) return;
                              final selected = vehicleOptions.firstWhere(
                                (option) => option.label == value,
                              );
                              setState(() {
                                _selectedVehicleLabel = selected.label;
                                _selectedVehicleType = selected.type;
                              });
                            },
                      selectedItemBuilder: (context) => vehicleOptions
                          .map(
                            (option) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _DetailSection(
                  title: 'Message to Instructor',
                  child: TextField(
                    controller: _messageController,
                    enabled: canEditMessage && !_processing,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Share your goals, availability, or anything else the instructor should know.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RatesSection(
                  rates: offeringRates,
                  fallback: ratesFallback,
                  labelForOffering: _labelForOffering,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    final instructorId = (_requestContext?['instructorId'] ??
                            _profile['id'] ??
                            _profile['profile_id'])
                        ?.toString();
                    if (instructorId == null || instructorId.isEmpty) return;
                    showUserReportSheet(
                      context,
                      reportedUserId: instructorId,
                      reportedUserName: name,
                    );
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report instructor'),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildBottomAction(
              isPending: isPending,
              isAccepted: isAccepted,
              hasActiveRelationship: _hasActiveRelationship,
              canRequest: canRequest,
              requestLabel: requestButtonLabel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required bool isPending,
    required bool isAccepted,
    required bool hasActiveRelationship,
    required bool canRequest,
    required String requestLabel,
  }) {
    if (_checkingRequest) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (isPending) {
      return _statusBanner(
        icon: Icons.hourglass_top,
        message: 'Request pending. Your instructor will reply soon.',
        textColor: AppColors.golden,
        backgroundColor: AppColors.golden.withOpacity(0.15),
      );
    }
    if (isAccepted || hasActiveRelationship) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusBanner(
            icon: Icons.check_circle_outline,
            message:
                'Connected. Head to the Lessons tab to schedule with this instructor.',
            textColor: AppColors.success,
            backgroundColor: AppColors.success.withOpacity(0.12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _processing ? null : _handleRemoveInstructor,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.34),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('Remove Instructor'),
            ),
          ),
        ],
      );
    }
    if (_isSuppressed) {
      return _statusBanner(
        icon: Icons.info_outline,
        message: 'Finishing up your last action. Try again in a moment.',
        textColor: Colors.grey.shade700,
        backgroundColor: Colors.grey.withOpacity(0.2),
      );
    }

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (!canRequest || _processing) ? null : _handleRequestAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocean,
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _processing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(requestLabel),
      ),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String message,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          VerifiedProfileBadge(size: 18),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  final String imageUrl;
  final String fallbackInitial;
  final bool isVerified;

  const _ProfileImage({
    required this.imageUrl,
    required this.fallbackInitial,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: Image.network(
              imageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _FallbackAvatar(initial: fallbackInitial),
            ),
          )
        else
          _FallbackAvatar(initial: fallbackInitial),
        if (isVerified)
          const Positioned(
            top: -6,
            right: -10,
            child: VerifiedProfileBadge(
              size: 26,
              showCutout: true,
            ),
          ),
      ],
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String initial;

  const _FallbackAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.ocean.withOpacity(0.15),
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: AppColors.ocean),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _VehiclePhotoPreview extends StatelessWidget {
  const _VehiclePhotoPreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.ocean.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.primaryBlue,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicVerificationItem extends StatelessWidget {
  const _PublicVerificationItem({
    required this.icon,
    required this.label,
    required this.verified,
  });

  final IconData icon;
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: verified ? AppColors.primaryBlue : AppColors.error),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            verified ? 'Verified' : 'Not verified',
            style: TextStyle(
              fontSize: 12,
              color: verified ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleRequestOption {
  const _VehicleRequestOption({required this.label, required this.type});

  final String label;
  final String type;
}

class _RatesSection extends StatelessWidget {
  const _RatesSection({
    required this.rates,
    required this.fallback,
    required this.labelForOffering,
  });

  final Map<String, String> rates;
  final String fallback;
  final String Function(String code) labelForOffering;

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) {
      return _DetailSection(
        title: 'Lesson pricing',
        child: Text(
          fallback,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[800],
              ),
        ),
      );
    }

    return _DetailSection(
      title: 'Lesson pricing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: rates.entries
                .map(
                  (entry) => _RatePill(
                    label: labelForOffering(entry.key),
                    value: entry.value,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Rates are shown per hour. Final lesson details are confirmed after your request is accepted.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatePill extends StatelessWidget {
  const _RatePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final normalizedValue =
        value.trim().startsWith(r'$') ? value.trim() : '\$${value.trim()}';
    final displayValue = normalizedValue.toLowerCase().contains('/hr')
        ? normalizedValue
        : '$normalizedValue/hr';

    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}
