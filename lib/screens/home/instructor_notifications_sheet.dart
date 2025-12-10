import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';

class InstructorNotification {
  const InstructorNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
}

class InstructorNotificationsSheet extends StatelessWidget {
  const InstructorNotificationsSheet({
    super.key,
    required this.notifications,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onMarkRead,
    required this.isUnread,
  });

  final List<InstructorNotification> notifications;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onMarkRead;
  final bool Function(InstructorNotification) isUnread;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + media.viewInsets.bottom,
        ),
        child: SizedBox(
          height: media.size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed:
                    isLoading || notifications.isEmpty ? null : onMarkRead,
                child: const Text('Mark read'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: _buildBody(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _EmptyState(
            icon: Icons.cloud_off,
            title: 'Unable to load notifications',
            message: error!,
          ),
        ],
      );
    }

    if (notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'No notifications yet',
            message:
                'We\'ll let you know when new learner requests or lesson updates arrive.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          showUnreadDot: isUnread(notification),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.showUnreadDot,
  });

  final InstructorNotification notification;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    final timestampLabel =
        DateFormat('MMM d • h:mm a').format(notification.timestamp.toLocal());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notification.color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notification.icon, color: notification.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notification.message,
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  timestampLabel,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (showUnreadDot)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 8, top: 6),
              decoration: const BoxDecoration(
                color: AppColors.ocean,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.primaryBlue),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
