import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/instructor_model.dart';
import '../../services/supabase_service.dart';

class FindInstructorScreen extends StatefulWidget {
  const FindInstructorScreen({super.key, this.selectedFocus});

  final String? selectedFocus;

  @override
  State<FindInstructorScreen> createState() => _FindInstructorScreenState();
}

class _FindInstructorScreenState extends State<FindInstructorScreen> {
  String _selectedFilter = 'all';
  String _selectedCarType = 'all';
  String _selectedTransmission = 'all';
  double _minRating = 0.0;
  String? _focusFilter;

  List<InstructorModel> _instructors = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusFilter = widget.selectedFocus;
    _loadInstructors();
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
              decoration: InputDecoration(
                hintText: 'Search by name or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
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
                _buildFilterChip('High Rating', 'high_rating'),
                const SizedBox(width: 8),
                _buildFilterChip('Nearby', 'nearby'),
                const SizedBox(width: 8),
                _buildFilterChip('Available Now', 'available'),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'No instructors match your filters yet. Try adjusting the focus or filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : AnimationLimiter(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: instructors.length,
                              itemBuilder: (context, index) {
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 600),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: _buildInstructorCard(instructors[index]),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.go(AppRoutes.booking, extra: instructor.id),
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
                    child: Text(
                      '${instructor.user.firstName[0]}${instructor.user.lastName[0]}',
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
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.accentYellow,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${instructor.rating.toStringAsFixed(1)} (${instructor.totalLessons} lessons)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
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
                  ...instructor.carTypes.map((type) => _buildTag(type.toUpperCase())),
                  ...instructor.transmissionTypes.map((type) => _buildTag(type.toUpperCase())),
                  ...instructor.levelsOffered.map(_buildTag),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(instructor.address, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.language, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(instructor.languages.join(', '), style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.booking, extra: instructor.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Book Lesson'),
                  ),
                ],
              ),
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

  List<InstructorModel> _filteredInstructors() {
    _focusFilter ??= widget.selectedFocus;

    return _instructors.where((instructor) {
      if (_focusFilter != null && _focusFilter!.isNotEmpty) {
        final focusLower = _focusFilter!.toLowerCase();
        final offersFocus = instructor.levelsOffered
            .map((level) => level.toLowerCase())
            .contains(focusLower);
        if (!offersFocus) return false;
      }
      if (_minRating > 0 && instructor.rating < _minRating) {
        return false;
      }
      if (_selectedCarType != 'all' &&
          !instructor.carTypes.map((e) => e.toLowerCase()).contains(_selectedCarType)) {
        return false;
      }
      if (_selectedTransmission != 'all' &&
          !instructor.transmissionTypes.map((e) => e.toLowerCase()).contains(_selectedTransmission)) {
        return false;
      }
      // TODO: apply more advanced filtering using location/availability.
      return true;
    }).toList();
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
                  _buildFilterOption('All', 'all', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('Sedan', 'sedan', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('SUV', 'suv', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('Hatchback', 'hatchback', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
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
                  _buildFilterOption('All', 'all', _selectedTransmission, (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                  _buildFilterOption('Automatic', 'automatic', _selectedTransmission, (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                  _buildFilterOption('Manual', 'manual', _selectedTransmission, (value) {
                    setModalState(() => _selectedTransmission = value);
                  }),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Minimum rating',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _minRating,
                onChanged: (value) => setModalState(() => _minRating = value),
                min: 0,
                max: 5,
                divisions: 10,
                label: _minRating.toStringAsFixed(1),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
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

  Future<void> _loadInstructors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final instructors = await SupabaseService.getInstructors();
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
