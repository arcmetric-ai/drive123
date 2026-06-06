import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class LearnerBottomNavBar extends StatelessWidget {
  const LearnerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <({String label, IconData icon, IconData activeIcon})>[
    (label: 'HOME', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    (
      label: 'FIND',
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on_rounded,
    ),
    (
      label: 'SCHEDULE',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    (
      label: 'PROGRESS',
      icon: Icons.local_offer_outlined,
      activeIcon: Icons.local_offer_rounded,
    ),
    (
      label: 'PROFILE',
      icon: Icons.account_circle_outlined,
      activeIcon: Icons.account_circle_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isActive ? item.activeIcon : item.icon,
                              size: 34,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                            ),
                            if (isActive)
                              const Positioned(
                                right: -2,
                                top: -2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 12, height: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                            letterSpacing: 0.8,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
