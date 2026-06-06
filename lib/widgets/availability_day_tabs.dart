import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';

class AvailabilityDayTabs extends StatelessWidget {
  const AvailabilityDayTabs({
    super.key,
    required this.selectedDay,
    required this.onSelected,
  });

  final String selectedDay;
  final ValueChanged<String> onSelected;

  static const days = [
    ('monday', 'MON'),
    ('tuesday', 'TUE'),
    ('wednesday', 'WED'),
    ('thursday', 'THU'),
    ('friday', 'FRI'),
    ('saturday', 'SAT'),
    ('sunday', 'SUN'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: days.map((day) {
          final dayKey = day.$1;
          final isSelected = selectedDay == dayKey;
          final isWeekend = dayKey == 'saturday' || dayKey == 'sunday';
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(dayKey),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 56,
                margin: EdgeInsets.only(
                  right: dayKey == days.last.$1 ? 0 : 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: isSelected ? AppShadows.subtle : null,
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      day.$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isWeekend
                                ? const Color(0xFFF27676)
                                : AppColors.mutedForeground),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
