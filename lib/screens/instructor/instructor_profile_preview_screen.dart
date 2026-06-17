import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';

class InstructorProfilePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const InstructorProfilePreviewScreen({super.key, required this.profile});

  @override
  State<InstructorProfilePreviewScreen> createState() =>
      _InstructorProfilePreviewScreenState();
}

class _InstructorProfilePreviewScreenState
    extends State<InstructorProfilePreviewScreen> {
  late final Map<String, dynamic> _profile;
  Map<String, dynamic>? _requestContext;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _requestContext = _profile.remove('__request') as Map<String, dynamic>?;
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

  Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
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

    final profileVehicles = _firstVehiclePhoto(_profile['vehicles']);
    if (profileVehicles != null) return profileVehicles;

    final detail = _mapOrNull(_profile['detail']);
    final detailUrl = _asNullableString(detail?['vehiclePhotoUrl']) ??
        _asNullableString(detail?['vehicle_photo_url']);
    if (detailUrl != null) return detailUrl;

    return _firstVehiclePhoto(detail?['vehicles']);
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

  Map<String, String> _asStringMap(String key) {
    final value = _profile[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  bool _readBool(String key) {
    final value = _profile[key];
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  String _readString(String key, {String fallback = ''}) {
    final value = _profile[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (key == 'serviceArea') {
      final areaValue = _profile['serviceAreaArea'] as String?;
      final cityValue = _profile['serviceAreaCity'] as String?;
      final composed = _composeServiceAreaLabel(areaValue, cityValue);
      if (composed != null && composed.trim().isNotEmpty) {
        return composed.trim();
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

  Future<void> _handleRequestLesson() async {
    final contextData = _requestContext;
    if (contextData == null) return;

    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to request a lesson.')),
        );
      }
      return;
    }

    final instructorId = contextData['instructorId'] as String?;
    if (instructorId == null || instructorId.isEmpty) {
      return;
    }

    final draft = await _promptRequestMessage();
    if (draft == null) return;

    setState(() => _submitting = true);

    try {
      await SupabaseService.createLessonRequest(
        instructorId: instructorId,
        learnerId: learnerId,
        focus: (contextData['focus'] as String?)?.trim().isNotEmpty == true
            ? contextData['focus'] as String
            : null,
        message: draft.note.isEmpty ? null : draft.note,
        requestedVehicleLabel: draft.vehicleLabel,
        requestedVehicleType: draft.vehicleType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to the instructor.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  List<_RequestVehicleOption> _requestVehicleOptions() {
    final rawVehicles = _profile['vehicles'];
    final options = <_RequestVehicleOption>[];
    if (rawVehicles is List) {
      for (final entry in rawVehicles) {
        if (entry is Map) {
          final type = _asNullableString(entry['type']);
          final year = _asNullableString(entry['year']);
          final make = _asNullableString(entry['make']);
          final model = _asNullableString(entry['model']);
          final plate = _asNullableString(entry['numberPlate']);
          final summary = _concealPlate([
            if (type != null) type,
            [
              if (year != null) year,
              if (make != null) make,
              if (model != null) model,
            ].join(' ').trim(),
            if (plate != null) 'Plate: $plate',
          ].where((value) => value.isNotEmpty).join(' - ').trim());
          if (summary.isNotEmpty) {
            options
                .add(_RequestVehicleOption(label: summary, type: type ?? ''));
          }
        } else if (entry is String) {
          final summary = _concealPlate(entry.trim());
          if (summary.isNotEmpty) {
            options.add(_RequestVehicleOption(label: summary, type: ''));
          }
        }
      }
    }
    return options;
  }

  Future<_RequestLessonDraft?> _promptRequestMessage() async {
    final controller = TextEditingController();
    final focus = (_requestContext?['focus'] as String?)?.trim();
    final options = _requestVehicleOptions();
    final matchedType = (_requestContext?['matchedVehicleType'] as String?)
        ?.trim()
        .toLowerCase();
    _RequestVehicleOption? initialSelection;
    if (matchedType != null && matchedType.isNotEmpty) {
      for (final option in options) {
        if (option.type.trim().toLowerCase() == matchedType) {
          initialSelection = option;
          break;
        }
      }
    }
    initialSelection ??= options.length == 1 ? options.first : null;

    return showModalBottomSheet<_RequestLessonDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        _RequestVehicleOption? selectedVehicle = initialSelection;
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request lesson',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  focus != null && focus.isNotEmpty
                      ? 'Let the instructor know what you need help with ($focus).'
                      : 'Let the instructor know what you need help with.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<_RequestVehicleOption>(
                    value: selectedVehicle,
                    decoration: const InputDecoration(
                      labelText: 'Preferred vehicle',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (option) => DropdownMenuItem<_RequestVehicleOption>(
                            value: option,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() => selectedVehicle = value);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Share a short note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(
                          _RequestLessonDraft(
                            note: controller.text.trim(),
                            vehicleLabel: selectedVehicle?.label,
                            vehicleType: selectedVehicle?.type,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ocean,
                        ),
                        child: const Text('Send request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _readString('name', fallback: 'Drive Tutor Instructor');
    final phone = _readString('phone', fallback: 'Add your phone number');
    final bio = _readString('bio', fallback: 'Describe your experience.');
    final serviceArea =
        _readString('serviceArea', fallback: 'Define service area');
    final rates = _readString('rates', fallback: 'Add your rates');
    final vehicleSummaries = _vehicleSummaries(concealPlate: true);
    var carSummary = vehicleSummaries.isNotEmpty
        ? vehicleSummaries.first
        : _concealPlate(_readString('car', fallback: 'Add vehicle details'));
    if (carSummary.isEmpty) {
      carSummary = 'Add vehicle details';
    }
    final age = _readString('age', fallback: 'Add your age');
    final gender = _readString('gender', fallback: 'Add your gender');
    final driveTutorNumber = _readString(
      'driveTutorNumber',
      fallback: 'Assigned after profile setup',
    );
    final profileImageUrl = _readString('profileImageUrl');
    final vehiclePhotoUrl = _resolveVehiclePhotoUrl();

    final languages = _asStringList('languages');
    final vehicles = vehicleSummaries;
    final areas = _asStringList('areas');
    final preferredLocations = _asStringList('preferredLocations');
    final pickupFromLearnerLocation =
        _readBool('pickupPreference') || _readBool('pickup_preference');
    final offerings = _asStringList('offerings');
    final offeringRates = _asStringMap('offeringRates');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public profile preview'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ocean,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            name: name,
            bio: bio,
            profileImageUrl: profileImageUrl,
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Contact & credentials',
            rows: [
              _tile(icon: Icons.phone_outlined, label: 'Phone', value: phone),
              _tile(
                icon: Icons.confirmation_number_outlined,
                label: 'Drive Tutor number',
                value: driveTutorNumber,
              ),
              _tile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Age',
                  value: age),
              _tile(icon: Icons.person_outline, label: 'Gender', value: gender),
            ],
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Vehicle & service',
            rows: [
              _tile(
                  icon: Icons.directions_car_filled_outlined,
                  label: 'Primary vehicle',
                  value: carSummary),
              _tile(
                  icon: Icons.map_outlined,
                  label: 'Service area',
                  value: serviceArea),
              _tile(icon: Icons.attach_money, label: 'Base rate', value: rates),
            ],
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: vehiclePhotoUrl?.isNotEmpty == true
                        ? Image.network(
                            vehiclePhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.directions_car_filled_outlined,
                                  color: Colors.grey),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.directions_car_filled_outlined,
                                  color: Colors.grey, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'Add a photo of your teaching vehicle to help learners recognise you.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
                ),
                if (vehicles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Other vehicles',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...vehicles.map(_bullet),
                ],
              ],
            ),
          ),
          _InfoCard(
            title: 'Languages',
            content: languages.isNotEmpty
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: languages
                        .map((lang) => Chip(label: Text(lang)))
                        .toList(),
                  )
                : const Text(
                    'Add the languages you teach in so learners know if you are a match.',
                    style: TextStyle(color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Offerings & pricing',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                offerings.isNotEmpty
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: offerings
                            .map(
                              (code) => Chip(
                                label: Text(_labelForOffering(code)),
                                backgroundColor:
                                    AppColors.golden.withOpacity(0.16),
                                labelStyle:
                                    const TextStyle(color: AppColors.golden),
                              ),
                            )
                            .toList(),
                      )
                    : const Text(
                        'Add at least one lesson offering so learners know how you can help.',
                        style: TextStyle(color: Colors.grey),
                      ),
                if (offeringRates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...offeringRates.entries.map(
                    (entry) => _bullet('${entry.key}: ${entry.value}'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Service area',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pickupFromLearnerLocation) ...[
                  const Text(
                    'Pickup option',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bullet('Picks up learners from their chosen location'),
                  if (areas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Areas covered',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ocean,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: areas.map(_bullet).toList(),
                    ),
                  ],
                ] else if (preferredLocations.isNotEmpty) ...[
                  const Text(
                    'Preferred pickup spots',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: preferredLocations.map(_bullet).toList(),
                  ),
                  if (areas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Areas covered',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ocean,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: areas.map(_bullet).toList(),
                    ),
                  ],
                ] else if (areas.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: areas.map(_bullet).toList(),
                  ),
                ] else
                  const Text(
                    'Add the areas you teach in so learners can book with confidence.',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'About you',
            content: Text(
              bio,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _requestContext == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleRequestLesson,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ocean,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Request Lesson'),
                ),
              ),
            ),
    );
  }

  static Widget _tile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ocean),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '- ',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.ocean,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  static String _labelForOffering(String code) {
    switch (code) {
      case 'G2':
        return 'G2 Road Test';
      case 'G':
        return 'G Road Test';
      case 'PR':
        return 'Practice Sessions';
    }
    return code;
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String bio;
  final String profileImageUrl;

  const _HeaderCard({
    required this.name,
    required this.bio,
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ocean,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(
                          color: AppColors.ocean,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            bio,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget>? rows;
  final Widget? content;

  const _InfoCard({required this.title, this.rows, this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 12),
          if (rows != null) ...rows!,
          if (content != null) content!,
        ],
      ),
    );
  }
}

class _RequestLessonDraft {
  const _RequestLessonDraft({
    required this.note,
    this.vehicleLabel,
    this.vehicleType,
  });

  final String note;
  final String? vehicleLabel;
  final String? vehicleType;
}

class _RequestVehicleOption {
  const _RequestVehicleOption({
    required this.label,
    required this.type,
  });

  final String label;
  final String type;
}
