import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../../services/supabase_service.dart';

class InstructorBookingsHistoryScreen extends StatefulWidget {
  const InstructorBookingsHistoryScreen({super.key});

  @override
  State<InstructorBookingsHistoryScreen> createState() =>
      _InstructorBookingsHistoryScreenState();
}

class _InstructorBookingsHistoryScreenState
    extends State<InstructorBookingsHistoryScreen> {
  bool _loading = true;
  String? _error;
  final List<_BookingHistoryItem> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool showLoader = true}) async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your bookings history.';
        _bookings.clear();
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final rows = await SupabaseService.getInstructorBookingsHistory(
        userId: instructorId,
      );
      final parsed = rows
          .map(_BookingHistoryItem.fromMap)
          .whereType<_BookingHistoryItem>()
          .toList();
      if (!mounted) return;
      setState(() {
        _bookings
          ..clear()
          ..addAll(parsed);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load bookings history. Please try again.';
      });
    }
  }

  Future<void> _refresh() => _loadHistory(showLoader: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings History'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey[500],
              ),
              const SizedBox(height: 12),
              const Text(
                'No bookings yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your completed or cancelled lessons will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return _BookingCard(booking: booking);
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final _BookingHistoryItem booking;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
      case 'finished':
        return AppColors.success;
      case 'cancelled':
      case 'canceled':
        return AppColors.error;
      case 'scheduled':
      case 'in_progress':
        return AppColors.primaryBlue;
      default:
        return Colors.grey[600]!;
    }
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Scheduled';
    final normalized = status.replaceAll('_', ' ');
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(booking.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(booking.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              booking.learnerName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              booking.focus,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  booking.timeRangeLabel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            if (booking.pickupLocation != null &&
                booking.pickupLocation!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.pickupLocation!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingHistoryItem {
  _BookingHistoryItem({
    required this.id,
    required this.start,
    required this.end,
    required this.status,
    required this.focus,
    required this.learnerName,
    this.pickupLocation,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String status;
  final String focus;
  final String learnerName;
  final String? pickupLocation;

  static _BookingHistoryItem? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = (map['id'] ?? '').toString();
    final scheduledStr = map['scheduled_at'] as String?;
    if (id.isEmpty || scheduledStr == null) return null;
    final scheduled = DateTime.tryParse(scheduledStr)?.toLocal();
    if (scheduled == null) return null;

    DateTime start = scheduled;
    DateTime end = scheduled.add(const Duration(hours: 1));
    final startTime = map['start_time'] as String?;
    final endTime = map['end_time'] as String?;
    double durationHours = 1.0;
    if (startTime != null && endTime != null) {
      final parsedStart = _parseTime(scheduled, startTime);
      final parsedEnd = _parseTime(scheduled, endTime);
      if (parsedStart != null && parsedEnd != null) {
        start = parsedStart;
        end = parsedEnd;
        final diffMinutes = end.difference(start).inMinutes;
        if (diffMinutes > 0) {
          durationHours = diffMinutes / 60.0;
        }
      }
    } else if (map['duration_hours'] is num) {
      durationHours = (map['duration_hours'] as num).toDouble();
      final durationMinutes =
          (durationHours * 60).clamp(30, 240).round();
      end = start.add(Duration(minutes: durationMinutes));
    } else if (map['duration_minutes'] is num) {
      durationHours = (map['duration_minutes'] as num).toDouble() / 60.0;
      end = start.add(
        Duration(minutes: durationHours > 0 ? (durationHours * 60).round() : 60),
      );
    }

    String _clean(dynamic value) {
      if (value == null) return '';
      final text = value.toString().trim();
      return text;
    }

    String _composeName(Map<String, dynamic>? profile) {
      if (profile == null) return '';
      final first = _clean(profile['first_name']);
      final last = _clean(profile['last_name']);
      final combined = [first, last].where((v) => v.isNotEmpty).join(' ').trim();
      if (combined.isNotEmpty) return combined;
      final email = _clean(profile['email']);
      if (email.isNotEmpty) return email;
      final name = _clean(profile['name']);
      return name;
    }

    Map<String, dynamic>? learnerMap = map['learner'] is Map
        ? Map<String, dynamic>.from(map['learner'] as Map)
        : null;
    Map<String, dynamic>? learnerProfile = map['learner_profile'] is Map
        ? Map<String, dynamic>.from(map['learner_profile'] as Map)
        : null;
    Map<String, dynamic>? nestedProfile = learnerProfile != null &&
            learnerProfile['profile'] is Map
        ? Map<String, dynamic>.from(learnerProfile['profile'] as Map)
        : null;

    final learnerName = () {
      final fromLearner = _composeName(learnerMap);
      if (fromLearner.isNotEmpty) return fromLearner;
      final fromNested = _composeName(nestedProfile ?? learnerProfile);
      if (fromNested.isNotEmpty) return fromNested;
      final requestedFirst = _clean(map['requested_first_name']);
      final requestedLast = _clean(map['requested_last_name']);
      final requestedName =
          [requestedFirst, requestedLast].where((v) => v.isNotEmpty).join(' ');
      if (requestedName.trim().isNotEmpty) return requestedName.trim();
      final requestedEmail = _clean(map['learner_email']);
      if (requestedEmail.isNotEmpty) return requestedEmail;
      return 'Learner';
    }();

    final status = LessonModel.deriveStatus(
      scheduledDate: scheduled,
      startTime: startTime ?? '',
      endTime: endTime ?? '',
      durationHours: durationHours,
      fallbackStatus:
          LessonModel.parseStatus((map['status'] ?? 'scheduled').toString()),
    );

    return _BookingHistoryItem(
      id: id,
      start: start,
      end: end,
      status: status.name,
      focus: (map['focus'] ?? 'Driving lesson').toString(),
      learnerName: learnerName,
      pickupLocation: (map['pickup_location'] as String?)?.trim(),
    );
  }

  static DateTime? _parseTime(DateTime base, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  String get formattedDate =>
      DateFormat('EEE, MMM d, yyyy • h:mm a').format(start);

  String get timeRangeLabel =>
      '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';
}
