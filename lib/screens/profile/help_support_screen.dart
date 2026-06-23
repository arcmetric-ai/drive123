import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

const _faqItems = <_FaqItem>[
  _FaqItem(
    question: 'How do I book a lesson?',
    answer:
        'Learners can search instructors, open an instructor profile, choose a vehicle or focus area where available, add an optional message, and send a lesson request. The instructor must accept or schedule the lesson before it is confirmed.',
  ),
  _FaqItem(
    question: 'Why do I need licence or identity verification?',
    answer:
        'Drive Tutor uses Ontario licence and identity checks to keep learner, instructor, and guardian accounts safer. Learners provide a G1, G2, or G licence. Instructors provide an Ontario G licence. Guardians may provide government ID when they manage a learner account.',
  ),
  _FaqItem(
    question: 'Why does my profile show pending verification?',
    answer:
        'Your profile can show pending when email, phone, licence, selfie, profile photo, or admin approval is not complete yet. Open Edit Profile or the credentials portal to finish missing steps.',
  ),
  _FaqItem(
    question: 'How do instructors manage schedules?',
    answer:
        'Instructors use the Schedule tab to mark available hours, add draft lessons, split hours into shorter bookings, edit lesson notes, and send schedules to learners.',
  ),
  _FaqItem(
    question: 'Can I cancel or change a lesson?',
    answer:
        'Use the lesson details or bookings screen to review the lesson. If a change is needed, contact the instructor or support depending on the booking status and timing.',
  ),
  _FaqItem(
    question: 'How do I contact support?',
    answer:
        'Use Email Support from this screen or email info@drivetutor.ca. Include your account email, the learner or instructor name, and the booking date if the issue is lesson-related.',
  ),
];

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(color: AppColors.foreground),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Need assistance?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Browse quick answers or reach out and we\'ll get back to you soon.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 24),
          _SupportTile(
            icon: Icons.question_answer_outlined,
            title: 'FAQ',
            description: 'Common questions about booking, passes, and lessons.',
            onTap: () => _showFaq(context),
          ),
          const SizedBox(height: 12),
          _SupportTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            description:
                'Send us a message and we\'ll respond within 1 business day.',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Email support'),
                  content: const Text('Email us at info@drivetutor.ca'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFaq(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQ'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in _faqItems) ...[
                  Text(
                    item.question,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.answer,
                    style: const TextStyle(color: AppColors.mutedForeground),
                  ),
                  if (item != _faqItems.last) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.white,
      leading: Icon(icon, color: AppColors.ocean),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(color: AppColors.mutedForeground),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: AppColors.mutedForeground,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}
