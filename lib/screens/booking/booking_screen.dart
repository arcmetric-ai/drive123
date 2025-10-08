import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
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
  final TextEditingController _notesController = TextEditingController();

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

  final List<String> _locations = [
    'Pick up from home',
    'Meet at instructor location',
    'Driving school parking lot',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
                color: AppColors.primaryBlue,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
              child: const Text(
                'JS',
                style: TextStyle(
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
                  const Text(
                    'John Smith',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: AppColors.accentYellow,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text('4.8 (250 lessons)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '10 years experience',
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
                const Text(
                  '\$45/hr',
                  style: TextStyle(
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
                    ? AppColors.primaryBlue
                    : Colors.grey[300]!,
                width: _selectedDate != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: _selectedDate != null
                      ? AppColors.primaryBlue
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
                  color: isSelected ? AppColors.primaryBlue : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primaryBlue : Colors.grey[300]!,
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
          final isSelected = _selectedDuration == duration;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(duration),
              value: duration,
              groupValue: _selectedDuration,
              onChanged: (value) => setState(() => _selectedDuration = value),
              activeColor: AppColors.primaryBlue,
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
        ..._locations.map((location) {
          final isSelected = _selectedLocation == location;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(location),
              value: location,
              groupValue: _selectedLocation,
              onChanged: (value) => setState(() => _selectedLocation = value),
              activeColor: AppColors.primaryBlue,
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
                    color: AppColors.primaryBlue,
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

    // TODO: Implement booking logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lesson Booked!'),
        content: Text(
          'Your lesson with John Smith has been booked for ${DateFormat('EEEE, MMMM d').format(_selectedDate!)} at $_selectedTime.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/my-lessons');
            },
            child: const Text('View Lessons'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
