import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class PickupLocationEditorCard extends StatelessWidget {
  const PickupLocationEditorCard({
    super.key,
    required this.label,
    required this.icon,
    required this.addressLine1Controller,
    required this.addressLine2Controller,
    required this.postalCodeController,
    required this.isDefault,
    required this.cityLabel,
    required this.onDefaultSelected,
  });

  final String label;
  final IconData icon;
  final TextEditingController addressLine1Controller;
  final TextEditingController addressLine2Controller;
  final TextEditingController postalCodeController;
  final bool isDefault;
  final String? cityLabel;
  final VoidCallback onDefaultSelected;

  @override
  Widget build(BuildContext context) {
    final effectiveCity = cityLabel?.trim();

    InputDecoration decoration(String labelText, {String? hintText}) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        filled: true,
        fillColor: const Color(0xFFF9FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDefault ? AppColors.primary : AppColors.border,
          width: isDefault ? 1.6 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDefault
                      ? const Color(0xFFE9F0FF)
                      : const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color:
                      isDefault ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDefault
                          ? 'Default pickup address'
                          : 'Optional saved location',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDefaultSelected,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDefault
                        ? const Color(0xFFE9F0FF)
                        : const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDefault
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 16,
                        color: isDefault
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDefault
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: addressLine1Controller,
            decoration: decoration('Street Address', hintText: '123 Main St'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressLine2Controller,
            decoration: decoration(
              'Unit / Building / Landmark',
              hintText: 'Unit 4, Apt 1203, or lobby entrance',
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  enabled: false,
                  decoration: decoration(
                    'City',
                    hintText: effectiveCity ?? 'Selected city',
                  ).copyWith(
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  controller: TextEditingController(text: effectiveCity ?? ''),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: postalCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: decoration('Postal Code', hintText: 'M5V 2A9'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
