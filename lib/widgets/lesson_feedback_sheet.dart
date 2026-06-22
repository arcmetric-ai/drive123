import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/supabase_service.dart';

Future<bool?> showLessonFeedbackSheet(
  BuildContext context, {
  required String lessonId,
  required String revieweeId,
  required String reviewerRole,
  required String revieweeName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LessonFeedbackSheet(
      lessonId: lessonId,
      revieweeId: revieweeId,
      reviewerRole: reviewerRole,
      revieweeName: revieweeName,
    ),
  );
}

Future<bool?> showUserReportSheet(
  BuildContext context, {
  required String reportedUserId,
  required String reportedUserName,
  String? lessonId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _UserReportSheet(
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      lessonId: lessonId,
    ),
  );
}

class _LessonFeedbackSheet extends StatefulWidget {
  const _LessonFeedbackSheet({
    required this.lessonId,
    required this.revieweeId,
    required this.reviewerRole,
    required this.revieweeName,
  });

  final String lessonId;
  final String revieweeId;
  final String reviewerRole;
  final String revieweeName;

  @override
  State<_LessonFeedbackSheet> createState() => _LessonFeedbackSheetState();
}

class _LessonFeedbackSheetState extends State<_LessonFeedbackSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool? _onTime;
  bool? _friendly;
  bool _noShow = false;
  int? _cleanliness;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a star rating first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.submitLessonFeedback(
        lessonId: widget.lessonId,
        revieweeId: widget.revieweeId,
        reviewerRole: widget.reviewerRole,
        rating: _rating,
        wasOnTime: _noShow ? false : _onTime,
        wasFriendly: _noShow ? null : _friendly,
        vehicleCleanliness:
            widget.reviewerRole == 'learner' && !_noShow ? _cleanliness : null,
        wasNoShow: _noShow,
        comment: _commentController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save feedback: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How was your lesson?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text('Share private feedback about ${widget.revieweeName}.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  tooltip: '$value star${value == 1 ? '' : 's'}',
                  onPressed: () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating ? Icons.star_rounded : Icons.star_border,
                    color: AppColors.accent,
                    size: 38,
                  ),
                );
              }),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('No-show'),
              value: _noShow,
              onChanged: (value) => setState(() => _noShow = value),
            ),
            if (!_noShow) ...[
              _ChoiceRow(
                label: 'On time',
                value: _onTime,
                onChanged: (value) => setState(() => _onTime = value),
              ),
              _ChoiceRow(
                label: 'Friendly and respectful',
                value: _friendly,
                onChanged: (value) => setState(() => _friendly = value),
              ),
              if (widget.reviewerRole == 'learner') ...[
                const SizedBox(height: 12),
                const Text(
                  'Vehicle cleanliness',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: (_cleanliness ?? 3).toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '${_cleanliness ?? 3}/5',
                  onChanged: (value) =>
                      setState(() => _cleanliness = value.round()),
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 2000,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: 'Additional comments (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Submitting...' : 'Submit feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        ChoiceChip(
          label: const Text('Yes'),
          selected: value == true,
          onSelected: (_) => onChanged(true),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('No'),
          selected: value == false,
          onSelected: (_) => onChanged(false),
        ),
      ],
    );
  }
}

class _UserReportSheet extends StatefulWidget {
  const _UserReportSheet({
    required this.reportedUserId,
    required this.reportedUserName,
    this.lessonId,
  });

  final String reportedUserId;
  final String reportedUserName;
  final String? lessonId;

  @override
  State<_UserReportSheet> createState() => _UserReportSheetState();
}

class _UserReportSheetState extends State<_UserReportSheet> {
  static const _reasons = <String, String>{
    'no_show': 'No-show',
    'unsafe_behaviour': 'Unsafe behaviour',
    'harassment': 'Harassment',
    'discrimination': 'Discrimination',
    'inappropriate_conduct': 'Inappropriate conduct',
    'vehicle_cleanliness': 'Vehicle cleanliness',
    'identity_concern': 'Identity concern',
    'other': 'Other',
  };

  final _commentController = TextEditingController();
  String? _reason;
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.submitUserReport(
        reportedUserId: widget.reportedUserId,
        lessonId: widget.lessonId,
        reason: _reason!,
        comment: _commentController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit report: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report ${widget.reportedUserName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Comments (minimum 25 characters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ||
                        _reason == null ||
                        _commentController.text.trim().length < 25
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: Text(_saving ? 'Submitting...' : 'Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
