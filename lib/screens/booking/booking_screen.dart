import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/location_preference.dart';
import '../../services/supabase_service.dart';
import '../../models/instructor_model.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    this.instructorId,
  });
  final String? instructorId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _selectedDuration;
  String? _selectedLocation;
  String? _selectedLocationOption;
  final TextEditingController _notesController = TextEditingController();
  final List<PreferredLocation> _preferredLocations = [];

  final List<String> _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00'
  ];

  final List<String> _durations = ['1 hour', '1.5 hours', '2 hours'];

  final List<String> _fallbackLocations = [
    'Pick up from home',
    'Meet at instructor location',
    'Driving school parking lot',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferredLocations();
  }

  InstructorModel? _instructor;
  bool _loadingInstructor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If an instructorId was provided, load their profile
    final id = widget.instructorId;
    if (id != null && _instructor == null && !_loadingInstructor) {
      _loadingInstructor = true;
      SupabaseService.getInstructor(id).then((result) {
        if (!mounted) return;
        setState(() {
          _instructor = result;
          _loadingInstructor = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _loadingInstructor = false);
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferredLocations() async {
    final stored = await LocationPreferenceStorage.load();
    final parsedLocations = <PreferredLocation>[];

    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      try {
        final detail = await SupabaseService.getLearnerProfileDetail(userId);
        final rawLocations = detail?['preferred_locations'];
        if (rawLocations is List) {
          for (final entry in rawLocations) {
            if (entry is Map) {
              final location = PreferredLocation.fromMap(entry);
              if (location.displayText.trim().isNotEmpty) {
                parsedLocations.add(location);
              }
            }
          }
        }
      } catch (_) {
        // ignore profile lookup errors here
      }
    }

    PreferredLocation? matched;
    if (stored.key != null) {
      matched = _findPreferredByKey(parsedLocations, stored.key!);
    }

    if (!mounted) return;

    setState(() {
      _preferredLocations
        ..clear()
        ..addAll(parsedLocations);
      if (matched != null) {
        _selectedLocationOption = 'saved:${matched.storageKey}';
        _selectedLocation = matched.displayText;
      } else if (stored.display != null && stored.display!.isNotEmpty) {
        _selectedLocationOption = null;
        _selectedLocation = stored.display;
      }
    });
  }

  PreferredLocation? _findPreferredByKey(
    List<PreferredLocation> locations,
    String key,
  ) {
    for (final location in locations) {
      if (location.storageKey == key) {
        return location;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Lesson'),
        actions: [
          TextButton(
            onPressed: _isFormValid() ? _bookLesson : null,
            child: const Text(
              'Book',
              style: TextStyle(
                color: AppColors.ocean,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructor Info Card
            _buildInstructorCard(),

            const SizedBox(height: 24),

            // Date Selection
            _buildDateSelection(),

            const SizedBox(height: 24),

            // Time Selection
            _buildTimeSelection(),

            const SizedBox(height: 24),

            // Duration Selection
            _buildDurationSelection(),

            const SizedBox(height: 24),

            // Location Selection
            _buildLocationSelection(),

            const SizedBox(height: 24),

            // Notes
            _buildNotesSection(),

            const SizedBox(height: 24),

            // Price Summary
            _buildPriceSummary(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCard() {
    final instr = _instructor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.ocean.withAlpha((0.1 * 255).round()),
              child: Text(
                instr != null
                    ? '${instr.user.firstName.isNotEmpty ? instr.user.firstName[0] : 'J'}${instr.user.lastName.isNotEmpty ? instr.user.lastName[0] : 'S'}'
                    : 'JS',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ocean,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instr != null
                        ? '${instr.user.firstName} ${instr.user.lastName}'.trim()
                        : 'John Smith',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Ratings temporarily hidden on booking page
                  const SizedBox.shrink(),
                  const SizedBox(height: 4),
                  Text(
                    instr != null ? '${instr.yearsOfExperience} years experience' : '10 years experience',
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
                  instr != null ? '\$${instr.hourlyRate.toStringAsFixed(0)}/hr' : '\$45/hr',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ocean,
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
      ),
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDate != null
                    ? AppColors.ocean
                    : Colors.grey[300]!,
                width: _selectedDate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: _selectedDate != null
                      ? AppColors.ocean
                      : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat('EEEE, MMMM d, y').format(_selectedDate!)
                      : 'Choose a date',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Time',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _timeSlots.map((time) {
            final isSelected = _selectedTime == time;
            return GestureDetector(
              onTap: () => setState(() => _selectedTime = time),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.ocean : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.ocean : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lesson Duration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._durations.map((duration) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(duration),
              value: duration,
              groupValue: _selectedDuration,
              onChanged: (value) => setState(() => _selectedDuration = value),
              activeColor: AppColors.ocean,
              contentPadding: EdgeInsets.zero,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meeting Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_preferredLocations.isNotEmpty) ...[
          const Text(
            'Saved pickup locations',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._preferredLocations.map((location) {
            final value = 'saved:${location.storageKey}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                title: Text(location.displayText),
                value: value,
                groupValue: _selectedLocationOption,
                onChanged: (selected) {
                  if (selected == null) return;
                  setState(() {
                    _selectedLocationOption = selected;
                    _selectedLocation = location.displayText;
                  });
                },
                activeColor: AppColors.ocean,
                contentPadding: EdgeInsets.zero,
              ),
            );
          }),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
        ],
        const Text(
          'Other options',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ..._fallbackLocations.map((location) {
          final value = 'fallback:$location';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(location),
              value: value,
              groupValue: _selectedLocationOption,
              onChanged: (selected) {
                if (selected == null) return;
                setState(() {
                  _selectedLocationOption = selected;
                  _selectedLocation = location;
                });
              },
              activeColor: AppColors.ocean,
              contentPadding: EdgeInsets.zero,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Notes (Optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any specific skills you want to focus on?',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary() {
    final duration = _selectedDuration ?? '1 hour';
    final durationHours = duration == '1 hour'
        ? 1.0
        : duration == '1.5 hours'
            ? 1.5
            : 2.0;
    final totalPrice = 45.0 * durationHours;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$duration × \$45/hr'),
                Text('\$${totalPrice.toStringAsFixed(0)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ocean,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _isFormValid() {
    return _selectedDate != null &&
        _selectedTime != null &&
        _selectedDuration != null &&
        _selectedLocation != null;
  }

  void _bookLesson() {
    if (!_isFormValid()) return;

    // Build lesson parameters
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to book a lesson.')),
      );
      return;
    }

    final instructorId = widget.instructorId ?? _instructor?.id;
    if (instructorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine instructor.')),
      );
      return;
    }

    // Parse duration into hours
    final durationHours = _selectedDuration == '1 hour'
        ? 1.0
        : _selectedDuration == '1.5 hours'
            ? 1.5
            : 2.0;

    // Compute start/end times (simple approximation using selected time + duration)
    final startParts = (_selectedTime ?? '09:00').split(':');
    final startHour = int.tryParse(startParts[0]) ?? 9;
    final startMinute = int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0;
    final scheduledDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    final startTime = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, startHour, startMinute).add(Duration(minutes: (durationHours * 60).toInt()));
    final endTime = '${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';

    // Prepare UI state and strings before async call to avoid using BuildContext across async gaps
  final confirmationInstructorName = _instructor != null
    ? ('${_instructor!.user.firstName} ${_instructor!.user.lastName}').trim()
    : 'John Smith';
    final confirmationWhen = DateFormat('EEEE, MMMM d').format(_selectedDate!);
    final confirmationTime = _selectedTime ?? '';
    final confirmationDuration = _selectedDuration != null ? ' (${_selectedDuration})' : '';
    final confirmationLocation = _selectedLocation != null ? '\nLocation: $_selectedLocation' : '';

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    SupabaseService.createLesson(
      learnerId: learnerId,
      instructorId: instructorId,
      scheduledDate: scheduledDate,
      startTime: startTime,
      endTime: endTime,
      duration: durationHours,
      cost: (_instructor?.hourlyRate ?? 45.0) * durationHours,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      location: _selectedLocation,
    ).then((lesson) {
      if (!mounted) return;
      Navigator.pop(context); // remove loading
      if (lesson == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create lesson. Please try again.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lesson Booked!'),
          content: Text(
            'Your lesson with $confirmationInstructorName has been booked for $confirmationWhen at $confirmationTime$confirmationDuration$confirmationLocation.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) context.go('/my-lessons');
              },
              child: const Text('View Lessons'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) context.go('/home');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }).catchError((e) {
      if (!mounted) return;
      Navigator.pop(context); // remove loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating lesson: $e')),
      );
    });
  }
}

