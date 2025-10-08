import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../constants/app_colors.dart';
import '../../models/instructor_model.dart';

class FindInstructorScreen extends StatefulWidget {
  const FindInstructorScreen({super.key});

  @override
  State<FindInstructorScreen> createState() => _FindInstructorScreenState();
}

class _FindInstructorScreenState extends State<FindInstructorScreen> {
  String _selectedFilter = 'all';
  String _selectedCarType = 'all';
  String _selectedTransmission = 'all';
  double _minRating = 0.0;

  final List<InstructorModel> _instructors = [
    // Dummy data
    InstructorModel(
      id: '1',
      user: UserModel(
        id: '1',
        email: 'john@example.com',
        firstName: 'John',
        lastName: 'Smith',
        role: 'instructor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      bio:
          'Experienced driving instructor with 10+ years of teaching experience. Specialized in defensive driving and highway skills.',
      yearsOfExperience: 10,
      hourlyRate: 45.0,
      rating: 4.8,
      totalLessons: 250,
      carTypes: ['sedan', 'suv'],
      transmissionTypes: ['automatic', 'manual'],
      latitude: 43.6532,
      longitude: -79.3832,
      address: '123 Main St, Toronto, ON',
      availableDays: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      startTime: '09:00',
      endTime: '17:00',
      languages: ['english'],
    ),
    InstructorModel(
      id: '2',
      user: UserModel(
        id: '2',
        email: 'sarah@example.com',
        firstName: 'Sarah',
        lastName: 'Johnson',
        role: 'instructor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      bio:
          'Patient and friendly instructor focused on building confidence in new drivers.',
      yearsOfExperience: 5,
      hourlyRate: 40.0,
      rating: 4.9,
      totalLessons: 180,
      carTypes: ['sedan', 'hatchback'],
      transmissionTypes: ['automatic'],
      latitude: 43.6532,
      longitude: -79.3832,
      address: '456 Queen St, Toronto, ON',
      availableDays: [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday'
      ],
      startTime: '08:00',
      endTime: '18:00',
      languages: ['english', 'french'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          // Search Bar
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

          // Filter Chips
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

          // Instructors List
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _instructors.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildInstructorCard(_instructors[index]),
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
        onTap: () => context.go('/booking', extra: instructor.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Profile Image
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

                  // Instructor Info
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
                              '${instructor.rating} (${instructor.totalLessons} lessons)',
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

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${instructor.hourlyRate.toInt()}/hr',
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

              // Bio
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

              // Car Types and Transmission
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...instructor.carTypes
                      .map((type) => _buildTag(type.toUpperCase())),
                  ...instructor.transmissionTypes
                      .map((type) => _buildTag(type.toUpperCase())),
                ],
              ),

              const SizedBox(height: 12),

              // Location and Availability
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      instructor.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${instructor.startTime} - ${instructor.endTime}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Show instructor details
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/booking', extra: instructor.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Book Lesson'),
                    ),
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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

              // Car Type Filter
              const Text(
                'Car Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption('All', 'all', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('Sedan', 'sedan', _selectedCarType,
                      (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('SUV', 'suv', _selectedCarType, (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                  _buildFilterOption('Hatchback', 'hatchback', _selectedCarType,
                      (value) {
                    setModalState(() => _selectedCarType = value);
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // Transmission Filter
              const Text(
                'Transmission',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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

              const SizedBox(height: 24),

              // Rating Filter
              const Text(
                'Minimum Rating',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _minRating,
                      max: 5.0,
                      divisions: 10,
                      label: _minRating.toStringAsFixed(1),
                      onChanged: (value) {
                        setModalState(() => _minRating = value);
                      },
                    ),
                  ),
                  Text(
                    _minRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Apply filters
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    String selectedValue,
    Function(String) onChanged,
  ) {
    final isSelected = selectedValue == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onChanged(value),
      selectedColor: AppColors.primaryBlue.withOpacity(0.2),
      checkmarkColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryBlue : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
