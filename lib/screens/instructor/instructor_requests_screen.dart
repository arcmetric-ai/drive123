import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';

class InstructorRequestsScreen extends StatefulWidget {
  const InstructorRequestsScreen({super.key});

  @override
  State<InstructorRequestsScreen> createState() => _InstructorRequestsScreenState();
}

class _InstructorRequestsScreenState extends State<InstructorRequestsScreen> {
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _requests = [];

  String? get _userId => SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
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
      final results = await SupabaseService.getLessonRequestsForInstructor(userId);
      setState(() {
        _requests = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _respond(String id, String status) async {
    await SupabaseService.respondToLessonRequest(requestId: id, status: status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status')),
      );
    }
    await _loadRequests();
  }

  Future<void> _acceptAndSchedule(Map<String, dynamic> request) async {
    final now = DateTime.now().add(const Duration(days: 2));
    await SupabaseService.respondToLessonRequest(requestId: request['id'] as String, status: 'accepted');
    await SupabaseService.createLessonFromRequest(
      requestId: request['id'] as String,
      scheduledAt: now,
      durationMinutes: 90,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted and provisional lesson created.')),
      );
    }
    await _loadRequests();
    if (mounted) {
      GoRouter.of(context).push(AppRoutes.instructorLessonDetail, extra: {
        ...request,
        'scheduled_at': now.toIso8601String(),
        'duration_minutes': 90,
        'status': 'scheduled',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson requests'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? const Center(child: Text('Unable to load requests'))
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: _requests.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No new requests right now.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _requests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            return _RequestTile(
                              request: request,
                              onAccept: () => _acceptAndSchedule(request),
                              onDecline: () => _respond(request['id'] as String, 'declined'),
                            );
                          },
                        ),
                ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  const _RequestTile({
    required this.request,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = request['created_at'] as String?;
    final createdLabel = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(DateTime.parse(createdAt))
        : 'Recently';
    final learner = request['learner'];
    final learnerName = () {
      if (learner is Map<String, dynamic>) {
        final first = learner['first_name'] ?? '';
        final last = learner['last_name'] ?? '';
        final name = '$first $last'.trim();
        if (name.isNotEmpty) return name;
        if (learner['email'] != null) return learner['email'] as String;
      }
      return (request['name'] ?? 'Learner').toString();
    }();
    final initials = learnerName.isNotEmpty ? learnerName[0].toUpperCase() : 'L';

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
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                child: Text(
                  initials,
                  style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learnerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      request['focus']?.toString() ?? 'Driving lesson request',
                      style: const TextStyle(color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
              Text(
                createdLabel,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request['message']?.toString() ?? 'No additional notes provided.',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text('Accept & schedule'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
