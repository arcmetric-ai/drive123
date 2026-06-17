import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

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
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Coming soon'),
                  content:
                      const Text('We\'re preparing a detailed FAQ for you.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
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
          const SizedBox(height: 12),
          _SupportTile(
            icon: Icons.chat_bubble_outline,
            title: 'Live chat',
            description: 'Chat with us Monday–Friday, 9 AM – 6 PM EST.',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Live chat'),
                  content: const Text('Live chat will be available soon.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
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
