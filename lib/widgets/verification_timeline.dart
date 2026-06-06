import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum VerificationTimelineStepState {
  complete,
  current,
  upcoming,
}

class VerificationTimeline extends StatelessWidget {
  const VerificationTimeline({
    super.key,
    required this.items,
  });

  final List<VerificationTimelineItemData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (index) {
        return VerificationTimelineItem(
          data: items[index],
          isLast: index == items.length - 1,
        );
      }),
    );
  }
}

class VerificationTimelineItemData {
  const VerificationTimelineItemData({
    required this.title,
    required this.subtitle,
    required this.state,
    this.emphasisColor,
  });

  final String title;
  final String subtitle;
  final VerificationTimelineStepState state;
  final Color? emphasisColor;
}

class VerificationTimelineItem extends StatelessWidget {
  const VerificationTimelineItem({
    super.key,
    required this.data,
    required this.isLast,
  });

  final VerificationTimelineItemData data;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isComplete = data.state == VerificationTimelineStepState.complete;
    final isCurrent = data.state == VerificationTimelineStepState.current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 52 : 40,
                  height: isCurrent ? 52 : 40,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFFE8F0FF)
                        : isCurrent
                            ? AppColors.accent.withValues(alpha: 0.78)
                            : AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isComplete
                        ? Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: AppColors.primaryForeground,
                            ),
                          )
                        : Container(
                            width: isCurrent ? 14 : 12,
                            height: isCurrent ? 14 : 12,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.grey700
                                  : AppColors.grey400.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppColors.grey200,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      color: isCurrent
                          ? AppColors.foreground
                          : isComplete
                              ? AppColors.foreground
                              : AppColors.grey300,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      height: 1.35,
                      color: data.emphasisColor ??
                          (isCurrent
                              ? AppColors.primary
                              : isComplete
                                  ? AppColors.mutedForeground
                                  : AppColors.grey300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
