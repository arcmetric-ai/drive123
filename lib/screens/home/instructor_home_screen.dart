import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_panel.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  int _selectedIndex = 0;

  void _onTabTap(int index) {
    setState(() => _selectedIndex = index);
  }

  String get _instructorName {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata;
    final first = metadata?['first_name'] as String?;
    final last = metadata?['last_name'] as String?;
    if (first != null && first.isNotEmpty) {
      return last != null && last.isNotEmpty ? '$first $last' : first;
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardTab(name: _instructorName),
      const _ScheduleTab(),
      const _StudentsTab(),
      const _ProfileTabPlaceholder(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: Colors.grey[500],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: 'Learners',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  final String name;

  const _DashboardTab({required this.name});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _upcomingLessons = [];
  List<Map<String, dynamic>> _requests = [];

  String? get _userId => SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final lessons = await SupabaseService.getUpcomingLessonsForInstructor(userId);
    final requests = await SupabaseService.getLessonRequestsForInstructor(userId);

    setState(() {
      _upcomingLessons = lessons;
      _requests = requests;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive T Instructor'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _WelcomeCard(name: widget.name),
                  const SizedBox(height: 20),
                  _StatsRow(
                    activeLearners: _upcomingLessons
                        .map((lesson) => lesson['learner']?['id'] ?? lesson['learner_id'])
                        .where((id) => id != null)
                        .toSet()
                        .length,
                    sessionsThisWeek: _upcomingLessons.length,
                    pendingRequests: _requests.where((r) => r['status'] == 'pending').length,
                  ),
                  const SizedBox(height: 20),
                  _UpcomingLessonsCard(
                    lessons: _upcomingLessons,
                    onLessonSelected: (lesson) {
                      GoRouter.of(context)
                          .push(AppRoutes.instructorLessonDetail, extra: lesson);
                    },
                  ),
                  const SizedBox(height: 20),
                  _RequestsCard(
                    requests: _requests,
                    onManage: () => GoRouter.of(context).push(AppRoutes.instructorRequests),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();

  List<Map<String, String>> get _todaySessions => const [
        {
          'learner': 'Alice Lee',
          'time': '09:30 - 11:00',
          'focus': 'G2 practice downtown',
          'location': 'Union Station',
          'pickup': 'Instructor vehicle',
          'notes': 'Focus on mirror checks before lane changes.',
          'status': 'Scheduled',
        },
        {
          'learner': 'Michael Chan',
          'time': '13:00 - 14:30',
          'focus': 'Highway merging',
          'location': 'Highway 404 & Finch',
          'pickup': 'Learner vehicle',
          'notes': 'Review ramp speed control and blind spot checks.',
          'status': 'Scheduled',
        },
      ];

  List<Map<String, dynamic>> get _upcomingWeek => const [
        {
          'date': 'Mon, Oct 14',
          'sessions': [
            {
              'learner': 'David Kim',
              'time': '10:00 - 11:30',
              'focus': 'Parallel parking',
              'location': 'Scarborough Town Ctr',
              'pickup': 'Instructor vehicle',
              'notes': 'Work on wheel positioning and signal timing.',
              'status': 'Scheduled',
            },
          ],
        },
        {
          'date': 'Wed, Oct 16',
          'sessions': [
            {
              'learner': 'Maria Gomez',
              'time': '09:00 - 10:30',
              'focus': 'G test rehearsal',
              'location': 'Etobicoke Test Centre',
              'pickup': 'Learner vehicle',
              'notes': 'Simulate test route and commentary driving.',
              'status': 'Scheduled',
            },
            {
              'learner': 'John Patel',
              'time': '15:00 - 16:30',
              'focus': 'Downtown navigation',
              'location': 'King & Bay',
              'pickup': 'Instructor vehicle',
              'notes': 'Focus on 4-way stops and pedestrian awareness.',
              'status': 'Scheduled',
            },
          ],
        },
      ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schedule'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryBlue,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'This Week'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                GoRouter.of(context).push(AppRoutes.instructorAvailability);
              },
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Availability'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ScheduleList(sessions: _todaySessions, emptyLabel: 'No lessons scheduled today'),
            _WeeklySchedule(weekData: _upcomingWeek),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            GoRouter.of(context).push(AppRoutes.instructorLessonDetail, extra: {
              'learner': 'New learner',
              'time': 'Select date & time',
              'focus': 'Custom lesson',
              'location': 'TBD',
              'pickup': 'Instructor vehicle',
              'notes': 'Create a lesson and assign to learner.',
              'status': 'Draft',
            });
          },
          backgroundColor: AppColors.primaryBlue,
          icon: const Icon(Icons.add),
          label: const Text('New Lesson'),
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<Map<String, String>> sessions;
  final String emptyLabel;

  const _ScheduleList({required this.sessions, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: emptyLabel,
        description: 'Update your availability so learners can book new sessions.',
        primaryActionText: 'Manage Availability',
        onPrimaryAction: () {
          GoRouter.of(context).push(AppRoutes.instructorAvailability);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _ScheduleCard(
          learner: session['learner']!,
          time: session['time']!,
          focus: session['focus']!,
          location: session['location']!,
          onTap: () => GoRouter.of(context)
              .push(AppRoutes.instructorLessonDetail, extra: session),
          onStart: () => GoRouter.of(context)
              .push(AppRoutes.instructorLessonDetail, extra: session),
          onReschedule: () => GoRouter.of(context)
              .push(AppRoutes.instructorLessonDetail, extra: session),
        );
      },
    );
  }
}

class _WeeklySchedule extends StatelessWidget {
  final List<Map<String, dynamic>> weekData;

  const _WeeklySchedule({required this.weekData});

  @override
  Widget build(BuildContext context) {
    if (weekData.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No lessons scheduled this week',
        description: 'Your calendar is open. Accept new requests to fill your schedule.',
        primaryActionText: 'View Requests',
        onPrimaryAction: () {
          GoRouter.of(context).push(AppRoutes.instructorRequests);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: weekData.length,
      itemBuilder: (context, index) {
        final day = weekData[index];
        final sessions = day['sessions'] as List<Map<String, String>>;

        return Padding(
          padding: EdgeInsets.only(bottom: index == weekData.length - 1 ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day['date'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 10),
              ...sessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScheduleCard(
                    learner: session['learner']!,
                    time: session['time']!,
                    focus: session['focus']!,
                    location: session['location']!,
                    onTap: () => GoRouter.of(context)
                        .push(AppRoutes.instructorLessonDetail, extra: session),
                    onStart: () => GoRouter.of(context)
                        .push(AppRoutes.instructorLessonDetail, extra: session),
                    onReschedule: () => GoRouter.of(context)
                        .push(AppRoutes.instructorLessonDetail, extra: session),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String learner;
  final String time;
  final String focus;
  final String location;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onReschedule;

  const _ScheduleCard({
    required this.learner,
    required this.time,
    required this.focus,
    required this.location,
    this.onTap,
    this.onStart,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
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
                backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                child: Text(
                  learner[0],
                  style: const TextStyle(color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learner,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                color: AppColors.primaryBlue,
                onPressed: onTap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  focus,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReschedule,
                  child: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text('Start Lesson'),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab();

  List<Map<String, String>> get _activeLearners => const [
        {
          'name': 'Alice Lee',
          'level': 'G2 practice',
          'progress': '3 / 6 sessions',
          'upcoming': 'Next: Oct 14 • 2:00 pm',
        },
        {
          'name': 'David Kim',
          'level': 'G prep',
          'progress': '1 / 4 sessions',
          'upcoming': 'Needs scheduling',
        },
      ];

  List<Map<String, String>> get _pendingRequests => const [
        {
          'name': 'Rachel Adams',
          'submitted': '2 hrs ago',
          'note': 'Looking for evening lessons downtown.',
        },
        {
          'name': 'Kevin Zhou',
          'submitted': 'Yesterday',
          'note': 'Needs highway practice before G test.',
        },
      ];

  List<Map<String, String>> get _pastLearners => const [
        {
          'name': 'Maria Gomez',
          'status': 'Completed G2',
          'note': 'Passed on Sept 25',
          'email': 'maria.gomez@example.com',
          'phone': '+1 647-555-4020',
        },
        {
          'name': 'Noah Singh',
          'status': 'Completed G',
          'note': 'Available for refreshers',
          'email': 'noah.singh@example.com',
          'phone': '+1 437-555-8844',
        },
      ];

  Map<String, dynamic> _detailForLearner(Map<String, String> base) {
    return {
      'name': base['name'] ?? 'Learner',
      'email': base['email'] ?? 'learner@example.com',
      'phone': base['phone'] ?? '+1 647-555-0000',
      'level': base['level'] ?? base['status'] ?? 'Driving practice',
      'progress': base['progress'] ?? base['note'] ?? 'Progress not tracked yet',
      'upcoming': base['upcoming'] ?? 'No lesson scheduled',
      'notes':
          'Add personalised coaching notes for ${base['name'] ?? 'the learner'}. Keep progress updated after each session.',
      'focusAreas': const ['City driving', 'Parking', 'Confidence building'],
      'recentLessons': const [
        {
          'date': 'Oct 5, 2024',
          'summary': 'Practised lane positioning and stop sign approach.',
          'feedback': 'Continue focusing on smooth braking before stops.',
        },
      ],
      'testPrep': const {
        'targetDate': 'Nov 18, 2024',
        'testCentre': 'Etobicoke DriveTest',
        'readiness': 'On track',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learners'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter options coming soon.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LearnerSection(
            title: 'Active learners',
            items: _activeLearners,
            builder: (learner) => _LearnerCard(
              name: learner['name']!,
              subtitle: learner['level']!,
              detail: learner['progress']!,
              trailing: learner['upcoming']!,
              accentColor: AppColors.primaryBlue,
              onTap: () => router.push(
                AppRoutes.instructorLearnerDetail,
                extra: _detailForLearner(learner),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _LearnerSection(
            title: 'Pending requests',
            actionLabel: 'Manage',
            onAction: () => router.push(AppRoutes.instructorRequests),
            items: _pendingRequests,
            builder: (request) => _LearnerRequestCard(
              name: request['name']!,
              submitted: request['submitted']!,
              note: request['note']!,
              onView: () => router.push(AppRoutes.instructorRequests),
            ),
          ),
          const SizedBox(height: 20),
          _LearnerSection(
            title: 'Past learners',
            items: _pastLearners,
            builder: (learner) => _LearnerCard(
              name: learner['name']!,
              subtitle: learner['status']!,
              detail: learner['note']!,
              accentColor: AppColors.success,
              trailing: 'Send follow-up',
              showAction: true,
              onTap: () => router.push(
                AppRoutes.instructorLearnerDetail,
                extra: _detailForLearner(learner),
              ),
              onAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Follow-up sent to ${learner['name']}')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Map<String, String>> items;
  final Widget Function(Map<String, String>) builder;

  const _LearnerSection({
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.items,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _SectionEmptyMessage()
        else
          ...items.map(builder),
      ],
    );
  }
}

class _LearnerCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String detail;
  final String? trailing;
  final bool showAction;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  const _LearnerCard({
    required this.name,
    required this.subtitle,
    required this.detail,
    this.trailing,
    this.showAction = false,
    this.accentColor = AppColors.primaryBlue,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                backgroundColor: accentColor.withOpacity(0.16),
                child: Text(
                  name[0],
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (showAction)
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(trailing ?? 'Message'),
                )
              else if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
          ),
          ],
        ),
      ),
    );
  }
}

class _LearnerRequestCard extends StatelessWidget {
  final String name;
  final String submitted;
  final String note;
  final VoidCallback? onView;

  const _LearnerRequestCard({
    required this.name,
    required this.submitted,
    required this.note,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(
                  name[0],
                  style: const TextStyle(color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    Text(
                      submitted,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Declined $name\'s request')),
                    );
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accepted $name\'s request')),
                    );
                    onView?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyMessage extends StatelessWidget {
  const _SectionEmptyMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Nothing here yet. Check back soon.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

class _ProfileTabPlaceholder extends StatefulWidget {
  const _ProfileTabPlaceholder();

  @override
  State<_ProfileTabPlaceholder> createState() => _ProfileTabPlaceholderState();
}

class _ProfileTabPlaceholderState extends State<_ProfileTabPlaceholder> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _instructor;

  String? get _userId => SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final profile = await SupabaseService.getRawProfile(userId);
    final instructor = await SupabaseService.getInstructorProfileDetail(userId);
    setState(() {
      _profile = profile;
      _instructor = instructor;
      _loading = false;
    });
  }

  Map<String, dynamic> get _profileData {
    final profile = _profile ?? {};
    final instructor = _instructor ?? {};
    final fallbackName = SupabaseService.currentUser?.userMetadata?['first_name'] ?? 'Instructor';

    return {
      'name': '${profile['first_name'] ?? fallbackName} ${profile['last_name'] ?? ''}'.trim(),
      'email': profile['email'] ?? SupabaseService.currentUser?.email ?? 'instructor@example.com',
      'phone': profile['phone'] ?? '+1 000-000-0000',
      'license': instructor['licence_number'] ?? 'Add licence number',
      'expiry': instructor['licence_expiry'] ?? 'Set expiry date',
      'car': instructor['vehicle'] ?? 'Add vehicle details',
      'serviceArea': instructor['service_area'] ?? 'Define service area',
      'bio': instructor['bio'] ?? 'Describe your experience so learners know what to expect.',
      'focus': (instructor['levels_offered'] as List?)?.cast<String>() ?? const ['G2 preparation'],
      'languages': (instructor['languages'] as List?)?.cast<String>() ?? const ['English'],
      'rates': instructor['default_rate'] == null
          ? 'Add your rates'
          : 'Standard lesson: \$${instructor['default_rate']}/hr',
    };
  }

  Future<void> _editProfile() async {
    final userId = _userId;
    if (userId == null) return;

    final formKey = GlobalKey<FormState>();
    final data = _profileData;
    String name = data['name'] as String;
    String phone = data['phone'] as String;
    String serviceArea = data['serviceArea'] as String;
    String bio = data['bio'] as String;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSaved: (value) => name = value?.trim() ?? name,
                  ),
                  TextFormField(
                    initialValue: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    onSaved: (value) => phone = value?.trim() ?? phone,
                  ),
                  TextFormField(
                    initialValue: serviceArea,
                    decoration: const InputDecoration(labelText: 'Service area'),
                    onSaved: (value) => serviceArea = value?.trim() ?? serviceArea,
                  ),
                  TextFormField(
                    initialValue: bio,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Bio'),
                    onSaved: (value) => bio = value?.trim() ?? bio,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                formKey.currentState?.save();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final parts = name.split(' ');
    final firstName = parts.isNotEmpty ? parts.first : name;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await SupabaseService.upsertInstructorProfile(
      userId: userId,
      bio: bio,
      serviceArea: serviceArea,
    );
    await SupabaseService.updateProfileFields(userId, {
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')), 
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _profileData;
    final focus = (data['focus'] as List).cast<String>();
    final languages = (data['languages'] as List).cast<String>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProfileHeader(name: data['name'] as String, email: data['email'] as String),
            const SizedBox(height: 20),
            _ProfileInfoCard(
              title: 'Contact & credentials',
              rows: [
                _InfoRow(label: 'Phone', value: data['phone'] as String),
                _InfoRow(label: 'Licence', value: data['license'] as String),
                _InfoRow(label: 'Expiry', value: data['expiry'] as String),
              ],
            ),
            const SizedBox(height: 20),
            _ProfileInfoCard(
              title: 'Vehicle & service',
              rows: [
                _InfoRow(label: 'Vehicle', value: data['car'] as String),
                _InfoRow(label: 'Service area', value: data['serviceArea'] as String),
                _InfoRow(label: 'Rates', value: data['rates'] as String),
              ],
            ),
            const SizedBox(height: 20),
            _ProfileInfoCard(
              title: 'Focus & languages',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: focus
                        .map(
                          (item) => Chip(
                            label: Text(item),
                            backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                            labelStyle: const TextStyle(color: AppColors.primaryBlue),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Languages',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                  ),
                  Wrap(
                    spacing: 8,
                    children: languages
                        .map((lang) => Chip(label: Text(lang)))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ProfileInfoCard(
              title: 'About you',
              content: Text(
                data['bio'] as String,
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).push(AppRoutes.instructorLearnerDetail, extra: {
                  'name': data['name'],
                  'email': data['email'],
                  'phone': data['phone'],
                  'level': 'Instructor profile preview',
                  'progress': 'Availability shared with learners',
                  'upcoming': 'Next availability: Mon 9-11am',
                  'notes': data['bio'],
                  'focusAreas': focus,
                  'recentLessons': const [],
                  'testPrep': const {
                    'targetDate': 'N/A',
                    'testCentre': 'N/A',
                    'readiness': 'Ready to coach',
                  },
                });
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview public profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await SupabaseService.signOut();
                if (context.mounted) {
                  context.go(AppRoutes.roleSelection);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Log out',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;

  const _ProfileHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              name[0],
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Drive T Instructor',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow>? rows;
  final Widget? content;

  const _ProfileInfoCard({required this.title, this.rows, this.content});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          if (rows != null)
            ...rows!.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: row,
                )),
          if (content != null) content!,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionText,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppColors.primaryBlue),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (primaryActionText != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: Text(primaryActionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;

  const _WelcomeCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hey $name 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have 3 sessions booked this week. Keep inspiring safe drivers!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              GoRouter.of(context).push(AppRoutes.instructorAvailability);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text(
              'Manage Availability',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int activeLearners;
  final int sessionsThisWeek;
  final int pendingRequests;

  const _StatsRow({
    required this.activeLearners,
    required this.sessionsThisWeek,
    required this.pendingRequests,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        label: 'Active learners',
        value: activeLearners.toString(),
        icon: Icons.group,
        color: AppColors.primaryBlue,
      ),
      _StatItem(
        label: 'Sessions this week',
        value: sessionsThisWeek.toString(),
        icon: Icons.event,
        color: AppColors.accentYellow,
      ),
      _StatItem(
        label: 'Pending requests',
        value: pendingRequests.toString(),
        icon: Icons.inbox_outlined,
        color: AppColors.success,
      ),
    ];

    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: stat,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingLessonsCard extends StatelessWidget {
  final List<Map<String, dynamic>> lessons;
  final void Function(Map<String, dynamic> lesson) onLessonSelected;

  const _UpcomingLessonsCard({
    required this.lessons,
    required this.onLessonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.all(20),
        child: const Text('No upcoming lessons. Accept requests to fill your schedule.'),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  GoRouter.of(context).push(AppRoutes.instructorAvailability);
                },
                child: const Text('View calendar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lessons.map(
            (lesson) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ScheduleCard(
                learner: _lessonLearnerName(lesson),
                time: _lessonTimeLabel(lesson),
                focus: (lesson['focus'] ?? 'Driving lesson').toString(),
                location: (lesson['pickup_location'] ?? 'See details').toString(),
                onTap: () => onLessonSelected(lesson),
                onStart: () => onLessonSelected(lesson),
                onReschedule: () => onLessonSelected(lesson),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _lessonLearnerName(Map<String, dynamic> lesson) {
    final learner = lesson['learner'];
    if (learner is Map<String, dynamic>) {
      final first = learner['first_name'] ?? '';
      final last = learner['last_name'] ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
    }
    return (lesson['learner_name'] ?? 'Learner') as String;
  }

  static String _lessonTimeLabel(Map<String, dynamic> lesson) {
    final scheduled = lesson['scheduled_at'] as String?;
    if (scheduled == null) {
      return lesson['time']?.toString() ?? '';
    }
    final dt = DateTime.tryParse(scheduled);
    if (dt == null) return scheduled;
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }
}

class _RequestsCard extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onManage;

  const _RequestsCard({required this.requests, required this.onManage});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: onManage,
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('You have no pending requests.'),
          ],
        ),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onManage,
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...requests.take(2).map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestItem(
                    name: _requestLearnerName(request),
                    message: (request['focus'] ?? request['message'] ?? '').toString(),
                    submitted: _requestCreatedLabel(request),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _requestLearnerName(Map<String, dynamic> request) {
    final learner = request['learner'];
    if (learner is Map<String, dynamic>) {
      final first = learner['first_name'] ?? '';
      final last = learner['last_name'] ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
      if (learner['email'] != null) return learner['email'];
    }
    return (request['name'] ?? 'Learner').toString();
  }

  static String _requestCreatedLabel(Map<String, dynamic> request) {
    final createdAt = request['created_at'] as String?;
    if (createdAt == null) return 'Recently';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return 'Recently';
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }
}

class _RequestItem extends StatelessWidget {
  final String name;
  final String message;
  final String submitted;

  const _RequestItem({
    required this.name,
    required this.message,
    required this.submitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(name[0], style: const TextStyle(color: AppColors.primaryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              Text(
                submitted,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Declined $name\'s request')),
                    );
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accepted $name\'s request')),
                    );
                    GoRouter.of(context).push(AppRoutes.instructorLessonDetail, extra: {
                      'learner': name,
                      'time': 'Select date & time',
                      'focus': message,
                      'location': 'TBD',
                      'pickup': 'Instructor vehicle',
                      'notes': 'Created from request submitted $submitted.',
                      'status': 'Draft',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
