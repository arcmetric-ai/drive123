import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';

class LearnerAvailabilityScreen extends StatefulWidget {
  const LearnerAvailabilityScreen({super.key});

  @override
  State<LearnerAvailabilityScreen> createState() =>
      _LearnerAvailabilityScreenState();
}

class _LearnerAvailabilityScreenState extends State<LearnerAvailabilityScreen> {
  static const List<String> _dayOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const Map<String, String> _slotLabels = {
    'early': 'Early (7am-8am)',
    'morning': 'Morning (9am-12pm)',
    'afternoon': 'Afternoon (1pm-4pm)',
    'evening': 'Evening (5pm-8pm)',
  };

  final Map<String, Set<String>> _availability = {
    for (final day in _dayOrder) day: <String>{},
  };
  bool _recurring = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      final detail = await SupabaseService.getLearnerProfileDetail(userId);
      if (detail != null) {
        final raw = detail['weekly_availability'];
        final map = _normalizeWeeklyAvailability(raw);
        setState(() {
          for (final day in _dayOrder) {
            _availability[day] = Set<String>.from(map[day] ?? const []);
          }
          _recurring = detail['availability_recurring'] == true;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null || _saving) return;
    final payload = _availability.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => {
              'day': entry.key,
              'slots': entry.value.toList(),
            })
        .toList();
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one availability slot before saving.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.upsertLearnerProfile(
        userId: userId,
        weeklyAvailability: payload,
        availabilityRecurring: _recurring,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save availability: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _toggleSlot(String day, String slot) {
    final selections = _availability[day]!;
    setState(() {
      if (selections.contains(slot)) {
        selections.remove(slot);
      } else {
        selections.add(slot);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Availability'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const Text(
                  'Select the time windows you are available for each day. '
                  'Your instructor can only schedule lessons during these windows.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                ..._dayOrder.map(_buildDaySection),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _recurring,
                  onChanged: (value) => setState(() => _recurring = value),
                  title: const Text('Repeat weekly'),
                  subtitle: const Text(
                    'Keep this availability for upcoming weeks automatically.',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDaySection(String day) {
    final displayDay = day[0].toUpperCase() + day.substring(1).toLowerCase();
    final selections = _availability[day]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayDay,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _slotLabels.entries.map((entry) {
              final slotKey = entry.key;
              final label = entry.value;
              final selected = selections.contains(slotKey);
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => _toggleSlot(day, slotKey),
                selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                checkmarkColor: AppColors.primaryBlue,
              );
            }).toList(),
          ),
        ],
      ),
    );
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
}
