import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../utils/constants.dart';
import '../../constants/ontario_locations.dart';
import '../../models/instructor_model.dart';
import '../../services/supabase_service.dart';

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
  String _selectedFilter = 'all';
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
  final Set<String> _requestingInstructors = {};
  bool _syncingRequests = false;
  Timer? _requestStatusTimer;
  bool _isOpeningProfile = false;

  @override
  void initState() {
    super.initState();
    _focusFilter = widget.selectedFocus;
    _initializeLearnerContext();
    _loadActiveRequests();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Instructor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.location_on),
                        onPressed: () {
                          // TODO: Get current location
                        },
                      ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Nearby', 'nearby'),
                const SizedBox(width: 8),
                _buildFilterChip('Available Now', 'available'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(
                  Icons.radar_outlined,
                  size: 18,
                  color: AppColors.ocean.withOpacity(0.8),
                ),
                label: Text(
                  'Radius: ${_searchRadiusKm.round()} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                backgroundColor: AppColors.ocean.withOpacity(0.08),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : instructors.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'No instructors match your filters yet. Try adjusting the focus or filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : AnimationLimiter(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: instructors.length,
                              itemBuilder: (context, index) {
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 600),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: _buildInstructorCard(
                                          instructors[index]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      selectedColor: AppColors.primaryBlue.withOpacity(0.2),
      checkmarkColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryBlue : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildInstructorCard(InstructorModel instructor) {
    final requestState = _requestStates[instructor.id];
    final bool isProcessing = _requestingInstructors.contains(instructor.id);
    String buttonLabel = 'Request Lesson';
    Color buttonBackground = AppColors.primaryBlue;
    Color buttonDisabledBackground = AppColors.primaryBlue.withOpacity(0.7);
    Color buttonForeground = Colors.white;
    Color buttonDisabledForeground = Colors.white70;
    VoidCallback? buttonAction = () => _toggleRequestFromList(instructor);
    String? statusMessage;
    Color? statusMessageColor;
    Color? statusMessageBackground;

    if (requestState != null) {
      final status = requestState.status;
      if (status == 'accepted') {
        buttonLabel = 'Accepted';
        buttonAction = null;
        buttonBackground = AppColors.success;
        buttonDisabledBackground = AppColors.success;
        buttonForeground = Colors.white;
        buttonDisabledForeground = Colors.white;
        statusMessage =
            'Request accepted. Your instructor will reach out soon.';
        statusMessageColor = AppColors.success;
        statusMessageBackground = AppColors.success.withOpacity(0.1);
      } else if (status == 'pending') {
        buttonLabel = 'Pending';
        buttonAction = null;
        buttonBackground = AppColors.golden;
        buttonDisabledBackground = AppColors.golden.withOpacity(0.85);
        buttonForeground = Colors.black87;
        buttonDisabledForeground = Colors.black54;
        statusMessage = 'Awaiting instructor response.';
        statusMessageColor = Colors.orange.shade700;
        statusMessageBackground = AppColors.golden.withOpacity(0.15);
      } else if (status == 'declined') {
        final bool coolingDown = requestState.isCoolingDown;
        if (coolingDown) {
          buttonLabel = 'Declined';
          buttonAction = null;
          buttonBackground = AppColors.error.withOpacity(0.85);
          buttonDisabledBackground = AppColors.error.withOpacity(0.7);
          buttonForeground = Colors.white;
          buttonDisabledForeground = Colors.white;
          final remaining = requestState.cooldownRemaining;
          final remainingDays = remaining.inDays;
          final remainingHours = remaining.inHours.remainder(24);
          String remainingText;
          if (remainingDays >= 1) {
            remainingText =
                '$remainingDays day${remainingDays == 1 ? '' : 's'}';
          } else if (remainingHours > 0) {
            remainingText =
                '$remainingHours hour${remainingHours == 1 ? '' : 's'}';
          } else {
            remainingText = 'less than an hour';
          }
          statusMessage =
              'Request declined. You can try again in $remainingText.';
          statusMessageColor = AppColors.error;
          statusMessageBackground = AppColors.error.withOpacity(0.12);
        } else {
          buttonLabel = 'Request Again';
          buttonBackground = AppColors.primaryBlue;
          buttonDisabledBackground = AppColors.primaryBlue.withOpacity(0.7);
          buttonForeground = Colors.white;
          buttonDisabledForeground = Colors.white70;
          buttonAction = () => _toggleRequestFromList(instructor);
          statusMessage =
              'Previously declined. You can submit a new request now.';
          statusMessageColor = AppColors.primaryBlue;
          statusMessageBackground = AppColors.primaryBlue.withOpacity(0.1);
        }
      }
    }

    final bool isButtonEnabled = buttonAction != null && !isProcessing;
    final VoidCallback? effectiveAction = isButtonEnabled ? buttonAction : null;
    final locationLabel = _formatServiceArea(instructor);

    final Widget actionButton = ElevatedButton(
      onPressed: effectiveAction,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonBackground,
        disabledBackgroundColor: buttonDisabledBackground,
        foregroundColor: buttonForeground,
        disabledForegroundColor: buttonDisabledForeground,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isProcessing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: buttonForeground,
              ),
            )
          : Text(buttonLabel),
    );

    final profileImageUrl = instructor.user.profileImageUrl?.trim();
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _openInstructorProfile(instructor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  backgroundImage:
                      hasProfileImage ? NetworkImage(profileImageUrl) : null,
                  child: hasProfileImage
                      ? null
                      : Text(
                          '${instructor.user.firstName.isNotEmpty ? instructor.user.firstName[0] : ''}'
                                  '${instructor.user.lastName.isNotEmpty ? instructor.user.lastName[0] : ''}'
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${instructor.user.firstName} ${instructor.user.lastName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const SizedBox(height: 4),
                        Text(
                          '${instructor.yearsOfExperience} years experience',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${instructor.hourlyRate.toStringAsFixed(0)}/hr',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      Text(
                        'per hour',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                instructor.bio,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...instructor.carTypes
                      .map((type) => _buildTag(type.toUpperCase())),
                  ...instructor.transmissionTypes
                      .map((type) => _buildTag(type.toUpperCase())),
                  ...instructor.levelsOffered.map(_buildTag),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locationLabel,
                                style: TextStyle(color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.language,
                                size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                instructor.languages.join(', '),
                                style: TextStyle(color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: actionButton),
                ],
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusMessageBackground ??
                        Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusMessageColor ?? Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }


  String _formatServiceArea(InstructorModel instructor) {
    String? composed;
    final serviceArea = instructor.serviceArea?.trim();
    if (serviceArea != null && serviceArea.isNotEmpty) {
      composed = serviceArea;
    } else {
      final area = instructor.serviceAreaArea?.trim() ?? '';
      final city = instructor.serviceAreaCity?.trim() ?? '';
      if (area.isNotEmpty && city.isNotEmpty) {
        composed = '$area - $city';
      } else if (area.isNotEmpty) {
        composed = area;
      } else if (city.isNotEmpty) {
        composed = city;
      }
    }

    return (composed != null && composed.isNotEmpty)
        ? composed
        : instructor.address;
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

  void _scheduleRequestPolling() {
    _requestStatusTimer?.cancel();
    _requestStatusTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadActiveRequests());
  }

  Future<void> _toggleRequestFromList(InstructorModel instructor) async {
    final requestState = _requestStates[instructor.id];
    if (requestState != null) {
      switch (requestState.status) {
        case 'pending':
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Your request is still pending. The instructor will respond soon.'),
                backgroundColor: AppColors.golden,
              ),
            );
          }
          return;
        case 'accepted':
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This instructor has already accepted you.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return;
        case 'declined':
          if (requestState.isCoolingDown) {
            if (mounted) {
              final remaining = requestState.cooldownRemaining;
              final days = remaining.inDays;
              final hours = remaining.inHours.remainder(24);
              String remainingText;
              if (days >= 1) {
                remainingText = '$days day${days == 1 ? '' : 's'}';
              } else if (hours > 0) {
                remainingText = '$hours hour${hours == 1 ? '' : 's'}';
              } else {
                remainingText = 'less than an hour';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Please wait $remainingText before requesting again.'),
                  backgroundColor: AppColors.golden,
                ),
              );
            }
            return;
          }
          break;
      }
    }
    await _sendLessonRequest(instructor);
  }

  Future<void> _sendLessonRequest(InstructorModel instructor) async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to request a lesson.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_requestingInstructors.contains(instructor.id)) return;

    final note = await _promptRequestMessage(instructor);
    if (note == null) return;

    setState(() => _requestingInstructors.add(instructor.id));
    try {
      await SupabaseService.createLessonRequest(
        instructorId: instructor.id,
        learnerId: learnerId,
        focus: _focusFilter,
        message: note.isEmpty ? null : note,
      );
      await _loadActiveRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lesson request sent to ${instructor.user.firstName}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString();
      final displayMessage =
          rawMessage.replaceFirst(RegExp(r'^Exception:\s?'), '');
      final isCooldown =
          displayMessage.contains('You can request this instructor again');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage.isNotEmpty
              ? displayMessage
              : 'Unable to send request. Please try again later.'),
          backgroundColor: isCooldown ? AppColors.golden : AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _requestingInstructors.remove(instructor.id));
      }
    }
  }

  Future<String?> _promptRequestMessage(InstructorModel instructor) async {
    final controller = TextEditingController();
    final focus = _focusFilter;
    final theme = Theme.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
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
              'Request ${instructor.user.firstName}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              focus != null && focus.isNotEmpty
                  ? 'Let ${instructor.user.firstName} know what you need help with for $focus.'
                  : 'Let ${instructor.user.firstName} know what you need help with.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
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
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(controller.text.trim()),
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

    controller.dispose();
    return result;
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

  Map<String, dynamic> _buildInstructorPreview(InstructorModel instructor) {
    final vehicleSummaries =
        instructor.vehicles.map((vehicle) => vehicle.summary()).toList();
    final vehiclesRaw =
        instructor.vehicles.map((vehicle) => vehicle.toJson()).toList();
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
      'vehiclePhotoUrl': instructor.vehiclePhotoUrl ?? '',
      'serviceArea': instructor.serviceArea ?? instructor.address,
      'serviceAreaArea': instructor.serviceAreaArea,
      'serviceAreaCity': instructor.serviceAreaCity,
      'car': instructor.vehicles.isNotEmpty
          ? instructor.vehicles.first.summary()
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
    if ((instructor.address ?? '').toLowerCase().contains(lowerTerm)) {
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
    if ((instructor.address ?? '').toLowerCase().contains(target)) {
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
                  for (final type
                      in ['all', ...AppConstants.carTypes]) ...[
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
                value: _selectedAreaFilter,
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
                value: _selectedCityFilter,
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
