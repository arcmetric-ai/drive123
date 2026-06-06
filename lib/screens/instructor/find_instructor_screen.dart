import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../utils/constants.dart';
import '../../constants/ontario_locations.dart';
import '../../models/instructor_model.dart';
import '../../models/lesson_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/discovery_filter_chip.dart';
import '../../widgets/instructor_discovery_card.dart';

class FindInstructorScreen extends StatefulWidget {
  const FindInstructorScreen({super.key, this.selectedFocus});

  final String? selectedFocus;

  @override
  State<FindInstructorScreen> createState() => _FindInstructorScreenState();
}

class _LearnerRequestState {
  const _LearnerRequestState({
    required this.status,
    this.requestId,
    required this.updatedAt,
    required this.createdAt,
  });

  final String status;
  final String? requestId;
  final DateTime updatedAt;
  final DateTime createdAt;

  DateTime get cooldownEnd => updatedAt.add(const Duration(days: 7));

  bool get isCoolingDown =>
      status == 'declined' && DateTime.now().isBefore(cooldownEnd);

  Duration get cooldownRemaining => cooldownEnd.difference(DateTime.now());
}

class _FindInstructorScreenState extends State<FindInstructorScreen> {
  String _selectedCarType = 'all';
  String _selectedTransmission = 'all';
  String? _focusFilter;

  List<InstructorModel> _instructors = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  double _searchRadiusKm = 20;
  static const double _minRadiusKm = 5;
  static const double _maxRadiusKm = 75;
  String? _selectedAreaFilter;
  String? _selectedCityFilter;
  String? _homeCity;
  final Map<String, _LearnerRequestState> _requestStates =
      <String, _LearnerRequestState>{};
  final Set<String> _scheduledInstructorIds = <String>{};
  bool _syncingRequests = false;
  Timer? _requestStatusTimer;
  bool _isOpeningProfile = false;

  @override
  void initState() {
    super.initState();
    _focusFilter = widget.selectedFocus;
    _initializeLearnerContext();
    _loadActiveRequests();
    _loadScheduledLessons();
    _scheduleRequestPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _requestStatusTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FindInstructorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFocus != widget.selectedFocus) {
      setState(() {
        _focusFilter = widget.selectedFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructors = _filteredInstructors();
    final searchHint = _homeCity != null && _homeCity!.isNotEmpty
        ? '$_homeCity, ON'
        : 'Toronto, ON';

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.card,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 18,
                        color: AppColors.mutedForeground,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 30,
                        color: AppColors.mutedForeground,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _showFilterBottomSheet,
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DiscoveryFilterChip(
                          label: 'AUTOMATIC',
                          selected: _selectedTransmission == 'automatic',
                          onTap: () => setState(() {
                            _selectedTransmission =
                                _selectedTransmission == 'automatic'
                                    ? 'all'
                                    : 'automatic';
                          }),
                        ),
                        const SizedBox(width: 12),
                        DiscoveryFilterChip(
                          label: 'MANUAL',
                          selected: _selectedTransmission == 'manual',
                          onTap: () => setState(() {
                            _selectedTransmission =
                                _selectedTransmission == 'manual'
                                    ? 'all'
                                    : 'manual';
                          }),
                        ),
                        const SizedBox(width: 12),
                        DiscoveryFilterChip(
                          label: 'MORE FILTERS',
                          selected: _selectedAreaFilter != null ||
                              _selectedCityFilter != null ||
                              _selectedCarType != 'all',
                          onTap: _showFilterBottomSheet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RADIUS ${_searchRadiusKm.round()} KM',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              overlayShape: SliderComponentShape.noOverlay,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _searchRadiusKm,
                              min: _minRadiusKm,
                              max: _maxRadiusKm,
                              onChanged: (value) => setState(() {
                                _searchRadiusKm = value;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _instructors.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                              sliver: SliverToBoxAdapter(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        instructors.isEmpty
                                            ? 'Nearby Instructors'
                                            : 'Nearby Instructors',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.foreground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (instructors.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      'No instructors match your filters yet. Try adjusting the search radius or filters.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 28),
                                sliver: SliverList.separated(
                                  itemCount: instructors.length,
                                  itemBuilder: (context, index) =>
                                      _buildInstructorCard(instructors[index]),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 18),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCard(InstructorModel instructor) {
    final statusLabel = _statusLabelForInstructor(instructor.id);
    final displayedRate = _displayRateForInstructor(instructor);
    return InstructorDiscoveryCard(
      instructor: instructor,
      onViewProfile: () => _openInstructorProfile(instructor),
      requestStatusLabel: statusLabel,
      displayedRate: displayedRate,
    );
  }

  double _displayRateForInstructor(InstructorModel instructor) {
    double? matchOfferingRate(String? focus) {
      if (focus == null || focus.trim().isEmpty) return null;
      final normalizedFocus =
          focus.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final entry in instructor.offeringRates.entries) {
        final normalizedKey =
            entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normalizedKey == normalizedFocus) {
          return entry.value;
        }
      }
      return null;
    }

    final focusRate = matchOfferingRate(_focusFilter);
    if (focusRate != null && focusRate > 0) {
      return focusRate;
    }

    if (instructor.hourlyRate > 0) {
      return instructor.hourlyRate;
    }

    if (instructor.offeringRates.isNotEmpty) {
      return instructor.offeringRates.values.first;
    }

    return 45.0;
  }

  String? _statusLabelForInstructor(String instructorId) {
    if (_scheduledInstructorIds.contains(instructorId)) {
      return 'Scheduled';
    }
    final state = _requestStates[instructorId];
    if (state == null) {
      return null;
    }
    switch (state.status) {
      case 'pending':
        return 'Requested';
      case 'accepted':
        return 'Accepted';
      default:
        return null;
    }
  }

  String _formatCarTypeLabel(String value) {
    final parts = value.split(RegExp(r'[_\\s-]+'));
    String normalize(String part) {
      if (part.length <= 3) return part.toUpperCase();
      return '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}';
    }

    return parts.where((part) => part.isNotEmpty).map(normalize).join(' ');
  }

  List<InstructorModel> _filteredInstructors() {
    _focusFilter ??= widget.selectedFocus;
    final searchTerm = _searchController.text.trim().toLowerCase();
    final hasSearch = searchTerm.isNotEmpty;

    return _instructors.where((instructor) {
      if (_focusFilter != null && _focusFilter!.isNotEmpty) {
        final focusLower = _focusFilter!.toLowerCase();
        final offersFocus = instructor.levelsOffered
            .map((level) => level.toLowerCase())
            .contains(focusLower);
        if (!offersFocus) return false;
      }
      if (_selectedCarType != 'all' &&
          !instructor.carTypes
              .map((value) => value.toLowerCase())
              .contains(_selectedCarType)) {
        return false;
      }
      if (_selectedTransmission != 'all' &&
          !instructor.transmissionTypes
              .map((value) => value.toLowerCase())
              .contains(_selectedTransmission)) {
        return false;
      }
      if (_selectedAreaFilter != null &&
          _selectedAreaFilter!.isNotEmpty &&
          !_matchesAreaSelection(instructor, _selectedAreaFilter!)) {
        return false;
      }
      if (_selectedCityFilter != null &&
          _selectedCityFilter!.isNotEmpty &&
          !_matchesCitySelection(instructor, _selectedCityFilter!)) {
        return false;
      }
      if (!_matchesRadiusCriteria(instructor)) {
        return false;
      }
      if (hasSearch && !_matchesSearchTerm(instructor, searchTerm)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadActiveRequests() async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      return;
    }
    if (_syncingRequests) return;
    _syncingRequests = true;

    try {
      final requests =
          await SupabaseService.getActiveLessonRequestsForLearner(learnerId);
      final states = <String, _LearnerRequestState>{};
      for (final request in requests) {
        final instructorId = request['instructor_id']?.toString();
        if (instructorId == null || instructorId.isEmpty) continue;
        final status =
            (request['status'] as String?)?.toLowerCase() ?? 'pending';
        final requestId = request['id']?.toString();
        final updatedAtRaw = request['updated_at']?.toString();
        final createdAtRaw = request['created_at']?.toString();
        final createdAt =
            DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now();
        final updatedAt = DateTime.tryParse(updatedAtRaw ?? '') ?? createdAt;

        states[instructorId] = _LearnerRequestState(
          status: status,
          requestId: requestId,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      }
      if (!mounted) return;
      setState(() {
        _requestStates
          ..clear()
          ..addAll(states);
      });
    } catch (_) {
      // silently ignore request sync issues
    } finally {
      _syncingRequests = false;
    }
  }

  Future<void> _loadScheduledLessons() async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      return;
    }

    try {
      final lessons = await SupabaseService.getLessons(learnerId);
      final scheduledIds = <String>{};
      for (final lesson in lessons) {
        if (_isScheduledRelationship(lesson)) {
          scheduledIds.add(lesson.instructor.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _scheduledInstructorIds
          ..clear()
          ..addAll(scheduledIds);
      });
    } catch (_) {
      // Ignore failures for now; cards can still render without scheduled state.
    }
  }

  bool _isScheduledRelationship(LessonModel lesson) {
    final status = lesson.effectiveStatus;
    return status == LessonStatus.scheduled ||
        status == LessonStatus.inProgress;
  }

  void _scheduleRequestPolling() {
    _requestStatusTimer?.cancel();
    _requestStatusTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadActiveRequests());
  }

  Future<void> _openInstructorProfile(InstructorModel instructor) async {
    if (_isOpeningProfile) return;
    setState(() {
      _isOpeningProfile = true;
    });
    try {
      final payload = _buildInstructorPreview(instructor);
      final requestState = _requestStates[instructor.id];
      payload['__request'] = {
        'instructorId': instructor.id,
        if (_focusFilter != null && _focusFilter!.isNotEmpty)
          'focus': _focusFilter,
        if (_selectedCarType != 'all') 'matchedVehicleType': _selectedCarType,
        if (requestState != null) 'status': requestState.status,
        if (requestState?.requestId != null)
          'requestId': requestState?.requestId,
        if (requestState != null)
          'updatedAt': requestState.updatedAt.toIso8601String(),
        if (requestState != null)
          'cooldownEndsAt': requestState.cooldownEnd.toIso8601String(),
      };

      await context.push(
        AppRoutes.learnerInstructorDetail,
        extra: payload,
      );
      await _loadActiveRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningProfile = false;
        });
      }
    }
  }

  String _normalizeVehicleType(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }

  List<InstructorVehicle> _orderedVehiclesForPreview(
      InstructorModel instructor) {
    final vehicles = List<InstructorVehicle>.from(instructor.vehicles);
    final selectedType = _normalizeVehicleType(_selectedCarType);
    if (selectedType.isEmpty || selectedType == 'all' || vehicles.length < 2) {
      return vehicles;
    }

    final matching = <InstructorVehicle>[];
    final others = <InstructorVehicle>[];
    for (final vehicle in vehicles) {
      if (_normalizeVehicleType(vehicle.type) == selectedType) {
        matching.add(vehicle);
      } else {
        others.add(vehicle);
      }
    }
    return [...matching, ...others];
  }

  Map<String, dynamic> _buildInstructorPreview(InstructorModel instructor) {
    final orderedVehicles = _orderedVehiclesForPreview(instructor);
    final vehiclesRaw =
        orderedVehicles.map((vehicle) => vehicle.toJson()).toList();
    final areaSummaries = _areasOfOperation(instructor).map((area) {
      final city = area.city ?? 'City not set';
      final radius = area.radiusKm;
      final radiusLabel = radius != null
          ? '${radius == radius.roundToDouble() ? radius.toStringAsFixed(0) : radius.toStringAsFixed(1)} km radius'
          : 'Radius not set';
      final areaName = area.areaName;
      if (areaName != null && areaName.isNotEmpty) {
        return '$areaName - $city ($radiusLabel)';
      }
      return '$city ($radiusLabel)';
    }).toList();

    final preferredLocations = instructor.preferredPickupSpots.map((spot) {
      final label = spot.label?.trim();
      final address = spot.address?.trim();
      if (label != null &&
          label.isNotEmpty &&
          address != null &&
          address.isNotEmpty) {
        return '$label - $address';
      }
      if (address != null && address.isNotEmpty) {
        return address;
      }
      if (label != null && label.isNotEmpty) {
        return label;
      }
      return 'Preferred location';
    }).toList();

    final defaultRate = instructor.hourlyRate > 0
        ? instructor.hourlyRate
        : (instructor.offeringRates.isNotEmpty
            ? instructor.offeringRates.values.first
            : 0.0);
    final ratesLabel = defaultRate > 0
        ? 'Standard lesson: \$${defaultRate.toStringAsFixed(0)}/hr'
        : 'Add your rates';

    return {
      'id': instructor.id,
      'name': '${instructor.user.firstName} ${instructor.user.lastName}'.trim(),
      'email': instructor.user.email,
      'phone': instructor.user.phone ?? '',
      'bio': instructor.bio,
      'profileImageUrl': instructor.user.profileImageUrl ?? '',
      'vehiclePhotoUrl': orderedVehicles.isNotEmpty
          ? (orderedVehicles.first.photoUrl ?? instructor.vehiclePhotoUrl ?? '')
          : (instructor.vehiclePhotoUrl ?? ''),
      'serviceArea': instructor.serviceArea ?? instructor.address,
      'serviceAreaArea': instructor.serviceAreaArea,
      'serviceAreaCity': instructor.serviceAreaCity,
      'car': orderedVehicles.isNotEmpty
          ? orderedVehicles.first.summary()
          : 'Vehicle details not provided',
      'vehicles': vehiclesRaw,
      'areas': areaSummaries,
      'languages': instructor.languages,
      'offerings': instructor.offerings,
      'offeringRates': instructor.offeringRates.map(
        (key, value) => MapEntry(key, '\$${value.toStringAsFixed(0)}/hr'),
      ),
      'focus': instructor.levelsOffered,
      'rates': ratesLabel,
      'preferredLocations': preferredLocations,
      'preferredLocationsRaw':
          instructor.preferredPickupSpots.map((spot) => spot.toJson()).toList(),
      'age': instructor.age?.toString() ?? '',
      'gender': instructor.gender ?? '',
      'yearsOfExperience': instructor.yearsOfExperience,
      'pickupPreference': instructor.pickupPreference,
      'locationNotes': instructor.locationNotes,
      'isVerified': instructor.isVerified || instructor.user.isVerified,
      'licenseNumber': instructor.licenseNumber,
    };
  }

  bool _matchesSearchTerm(InstructorModel instructor, String term) {
    final lowerTerm = term.toLowerCase();
    final name = '${instructor.user.firstName} ${instructor.user.lastName}'
        .trim()
        .toLowerCase();
    if (name.contains(lowerTerm)) return true;
    if (instructor.user.email.toLowerCase().contains(lowerTerm)) return true;
    if ((instructor.serviceArea ?? '').toLowerCase().contains(lowerTerm)) {
      return true;
    }
    if (instructor.address.toLowerCase().contains(lowerTerm)) {
      return true;
    }
    for (final area in _areasOfOperation(instructor)) {
      final city = area.city?.toLowerCase();
      if (city != null && city.contains(lowerTerm)) return true;
      final areaName = area.areaName?.toLowerCase();
      if (areaName != null && areaName.contains(lowerTerm)) return true;
      final mapped = OntarioLocations.areaForCity(area.city)?.toLowerCase();
      if (mapped != null && mapped.contains(lowerTerm)) return true;
    }
    return false;
  }

  bool _matchesAreaSelection(InstructorModel instructor, String areaName) {
    final target = areaName.toLowerCase();
    final serviceArea = instructor.serviceArea?.toLowerCase();
    if (serviceArea != null && serviceArea.contains(target)) return true;
    for (final area in _areasOfOperation(instructor)) {
      final areaLabel = area.areaName?.toLowerCase();
      if (areaLabel != null && areaLabel.contains(target)) return true;
      final mapped = OntarioLocations.areaForCity(area.city)?.toLowerCase();
      if (mapped != null && mapped.contains(target)) return true;
    }
    return false;
  }

  Future<void> _initializeLearnerContext() async {
    final user = SupabaseService.currentUser;
    String? queryCity;
    String? normalizedCity;

    if (user != null) {
      try {
        final detail = await SupabaseService.getLearnerProfileDetail(user.id);
        final profile = detail?['profile'];
        final rawCity = profile is Map ? profile['city']?.toString() : null;
        final cleanedCity = rawCity?.trim();
        if (cleanedCity != null && cleanedCity.isNotEmpty) {
          queryCity = cleanedCity;
          normalizedCity = _normalizeCityName(cleanedCity);
        }
      } catch (_) {
        // Ignore failures; we can still load all instructors.
      }
    }

    if (mounted && normalizedCity != null) {
      setState(() {
        _homeCity = normalizedCity;
        if (_selectedCityFilter == null || _selectedCityFilter!.isEmpty) {
          _selectedCityFilter = normalizedCity;
        }
      });
    }

    await _loadInstructors(overrideCity: normalizedCity ?? queryCity);
  }

  String? _normalizeCityName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final city in OntarioLocations.allCities) {
      if (city.toLowerCase() == lower) {
        return city;
      }
    }
    return null;
  }

  bool _matchesCitySelection(InstructorModel instructor, String cityName) {
    final target = cityName.toLowerCase();
    if ((instructor.serviceArea ?? '').toLowerCase().contains(target)) {
      return true;
    }
    if (instructor.address.toLowerCase().contains(target)) {
      return true;
    }
    for (final area in _areasOfOperation(instructor)) {
      final city = area.city?.toLowerCase();
      if (city != null && city.contains(target)) return true;
    }
    return false;
  }

  bool _matchesRadiusCriteria(InstructorModel instructor) {
    if (_searchRadiusKm >= _maxRadiusKm) {
      return true;
    }
    final areas = _areasOfOperation(instructor);
    if (areas.isEmpty) {
      return true;
    }
    double? maxRadius;
    for (final area in areas) {
      final radius = area.radiusKm;
      if (radius == null || radius <= 0) {
        continue;
      }
      if (radius >= _searchRadiusKm) {
        return true;
      }
      if (maxRadius == null || radius > maxRadius) {
        maxRadius = radius;
      }
    }
    if (maxRadius != null) {
      return _searchRadiusKm <= maxRadius + 5;
    }
    return true;
  }

  List<InstructorArea> _areasOfOperation(InstructorModel instructor) {
    return instructor.areasOfOperation;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Instructors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Car Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in ['all', ...AppConstants.carTypes]) ...[
                    _buildFilterOption(
                      type == 'all' ? 'All' : _formatCarTypeLabel(type),
                      type,
                      _selectedCarType,
                      (value) => setModalState(() => _selectedCarType = value),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Transmission',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption('All', 'all', _selectedTransmission,
                      (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                  _buildFilterOption(
                      'Automatic', 'automatic', _selectedTransmission, (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                  _buildFilterOption('Manual', 'manual', _selectedTransmission,
                      (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                ],
              ),
              const Text(
                'Area of operation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedAreaFilter,
                decoration: const InputDecoration(
                  labelText: 'Area',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All areas'),
                  ),
                  ...OntarioLocations.areaNames.map(
                    (area) => DropdownMenuItem<String>(
                      value: area,
                      child: Text(area),
                    ),
                  ),
                ],
                onChanged: (value) => setModalState(() {
                  _selectedAreaFilter = value;
                  if (value == null) {
                    _selectedCityFilter = null;
                  } else if (_selectedCityFilter != null &&
                      !OntarioLocations.citiesForArea(value)
                          .contains(_selectedCityFilter)) {
                    _selectedCityFilter = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCityFilter,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All cities'),
                  ),
                  ...(_selectedAreaFilter == null
                          ? OntarioLocations.allCities
                          : OntarioLocations.citiesForArea(_selectedAreaFilter))
                      .map(
                    (city) => DropdownMenuItem<String>(
                      value: city,
                      child: Text(city),
                    ),
                  ),
                ],
                onChanged: (value) => setModalState(() {
                  _selectedCityFilter = value;
                }),
              ),
              const SizedBox(height: 24),
              const Text(
                'Search radius',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Within ${_searchRadiusKm.round()} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ocean,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setModalState(() => _searchRadiusKm = 20),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              Slider(
                value: _searchRadiusKm,
                onChanged: (value) =>
                    setModalState(() => _searchRadiusKm = value),
                min: _minRadiusKm,
                max: _maxRadiusKm,
                divisions: (_maxRadiusKm - _minRadiusKm).round(),
                label: '${_searchRadiusKm.round()} km',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadInstructors();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    String label,
    String value,
    String groupValue,
    ValueChanged<String> onSelected,
  ) {
    final isActive = groupValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primaryBlue.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isActive ? AppColors.primaryBlue : Colors.grey[700],
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _loadInstructors({String? overrideCity}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final filterCity = overrideCity ??
          (_selectedCityFilter != null && _selectedCityFilter!.isNotEmpty
              ? _selectedCityFilter
              : null);
      final instructors =
          await SupabaseService.getInstructors(city: filterCity);
      if (!mounted) return;
      setState(() {
        _instructors = instructors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load instructors right now. Please try again soon.';
        _isLoading = false;
      });
    }
  }
}
