import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';

class InstructorAvailabilityScreen extends StatefulWidget {
  const InstructorAvailabilityScreen({super.key});

  @override
  State<InstructorAvailabilityScreen> createState() => _InstructorAvailabilityScreenState();
}

class _InstructorAvailabilityScreenState extends State<InstructorAvailabilityScreen> {
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _blocks = [];

  final List<String> _weekdays = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String? get _userId => SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _error = true;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final slots = await SupabaseService.getInstructorAvailability(userId);
      final blocks = await SupabaseService.getAvailabilityBlocks(userId);
      setState(() {
        _slots = slots;
        _blocks = blocks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _addSlot() async {
    final userId = _userId;
    if (userId == null) return;

    int weekday = 0;
    TimeOfDay? start;
    TimeOfDay? end;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add availability slot'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: weekday,
                    onChanged: (value) => setModalState(() => weekday = value ?? 0),
                    items: List.generate(
                      _weekdays.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(_weekdays[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(start == null ? 'Select start time' : start!.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: start ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setModalState(() => start = picked);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_off),
                    title: Text(end == null ? 'Select end time' : end!.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: end ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setModalState(() => end = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (start != null && end != null) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (start == null || end == null) return;

    final startTime = _formatTimeOfDay(start!);
    final endTime = _formatTimeOfDay(end!);

    await SupabaseService.addAvailabilitySlot(
      userId: userId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved')), 
      );
    }
    await _loadData();
  }

  Future<void> _removeSlot(String slotId) async {
    await SupabaseService.deleteAvailabilitySlot(slotId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot removed')),
      );
    }
    await _loadData();
  }

  Future<void> _addBlockedDate() async {
    final userId = _userId;
    if (userId == null) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    String? reason;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Block date'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            onChanged: (value) => reason = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    await SupabaseService.addAvailabilityBlock(
      userId: userId,
      date: pickedDate,
      reason: reason,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date blocked')), 
      );
    }
    await _loadData();
  }

  Future<void> _removeBlockedDate(String blockId) async {
    await SupabaseService.removeAvailabilityBlock(blockId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Block removed')),
      );
    }
    await _loadData();
  }

  Map<String, List<Map<String, dynamic>>> _groupSlotsByDay() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final slot in _slots) {
      final weekday = slot['weekday'] as int? ?? 0;
      final dayName = _weekdays[weekday % 7];
      grouped.putIfAbsent(dayName, () => []).add(slot);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calendar sync coming soon.')),
              );
            },
            icon: const Icon(Icons.sync_alt),
            label: const Text('Sync calendar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add),
        label: const Text('Add time slot'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? const Center(child: Text('Unable to load availability'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Set your recurring availability so learners can request lessons. You can update these slots anytime.',
                          style: TextStyle(color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._groupSlotsByDay().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _AvailabilityCard(
                            day: entry.key,
                            slots: entry.value,
                            onRemove: _removeSlot,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _OneOffSection(
                        blockedDates: _blocks,
                        onAddBlock: _addBlockedDate,
                        onRemoveBlock: _removeBlockedDate,
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    return DateFormat.Hm().format(dt);
  }
}

class _AvailabilityCard extends StatelessWidget {
  final String day;
  final List<Map<String, dynamic>> slots;
  final void Function(String slotId) onRemove;

  const _AvailabilityCard({
    required this.day,
    required this.slots,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              Text('${slots.length} slot${slots.length == 1 ? '' : 's'}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slots
                .map(
                  (slot) => Chip(
                    label: Text('${slot['start_time']} - ${slot['end_time']}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => onRemove(slot['id'] as String),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OneOffSection extends StatelessWidget {
  final List<Map<String, dynamic>> blockedDates;
  final VoidCallback onAddBlock;
  final void Function(String blockId) onRemoveBlock;

  const _OneOffSection({
    required this.blockedDates,
    required this.onAddBlock,
    required this.onRemoveBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'One-off adjustments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              TextButton(
                onPressed: onAddBlock,
                child: const Text('Add block date'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (blockedDates.isEmpty)
            const Text(
              'No upcoming blocked dates.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...blockedDates.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat.yMMMd().format(DateTime.parse(item['block_date'] as String))),
                subtitle: Text(item['reason'] as String? ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemoveBlock(item['id'] as String),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
