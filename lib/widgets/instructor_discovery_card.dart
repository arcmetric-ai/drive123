import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../models/instructor_model.dart';
import 'verified_profile_badge.dart';

class InstructorDiscoveryCard extends StatelessWidget {
  const InstructorDiscoveryCard({
    super.key,
    required this.instructor,
    required this.onViewProfile,
    this.requestStatusLabel,
    this.displayedRate,
  });

  final InstructorModel instructor;
  final VoidCallback onViewProfile;
  final String? requestStatusLabel;
  final double? displayedRate;

  @override
  Widget build(BuildContext context) {
    final profileImage = instructor.user.profileImageUrl?.trim();
    final hasProfileImage = profileImage != null && profileImage.isNotEmpty;
    final name =
        '${instructor.user.firstName} ${instructor.user.lastName}'.trim();
    final vehicle = (instructor.vehicles.isNotEmpty
            ? instructor.vehicles.first.summary()
            : 'Vehicle details not provided')
        .replaceAll(' �- ', ' - ');
    final experienceText = '${instructor.yearsOfExperience} YEARS EXP.';
    final effectiveRate = displayedRate ??
        (instructor.hourlyRate > 0
            ? instructor.hourlyRate
            : (instructor.offeringRates.isNotEmpty
                ? instructor.offeringRates.values.first
                : 0.0));
    final rateText = '\$${effectiveRate.toStringAsFixed(0)}';
    final pickupText = instructor.pickupPreference == true
        ? 'OFFERS LEARNER PICKUP'
        : 'MEETUP LOCATION';
    final transmissionText = instructor.transmissionTypes.isNotEmpty
        ? instructor.transmissionTypes.first.toUpperCase()
        : 'TRANSMISSION N/A';
    final languageText = instructor.languages.isNotEmpty
        ? instructor.languages.take(2).join(', ').toUpperCase()
        : 'LANGUAGE N/A';
    final serviceAreaText = _serviceArea(instructor);
    final isVerified = instructor.isVerified || instructor.user.isVerified;
    final ratingText = instructor.rating > 0
        ? instructor.rating.toStringAsFixed(1)
        : 'NEW PROFILE';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: hasProfileImage
                          ? Image.network(profileImage, fit: BoxFit.cover)
                          : DecoratedBox(
                              decoration: const BoxDecoration(
                                color: AppColors.secondary,
                              ),
                              child: Center(
                                child: Text(
                                  _initials(name, instructor.user.email),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (isVerified)
                    const Positioned(
                      right: -2,
                      top: -2,
                      child: VerifiedProfileBadge(size: 32, showCutout: true),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        if (requestStatusLabel != null &&
                            requestStatusLabel!.trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _StatusBadge(label: requestStatusLabel!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Pill(
                  label: pickupText,
                  background: const Color(0xFFE6EEFF),
                  foreground: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _Pill(
                  label: experienceText,
                  background: AppColors.secondary,
                  foreground: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MetaRow(
            leading: _MetaItem(
              icon: Icons.pin_drop_outlined,
              text: serviceAreaText,
            ),
            trailing: _MetaItem(
              icon: Icons.settings_outlined,
              text: transmissionText,
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(
            leading: _MetaItem(
              icon: Icons.language_rounded,
              text: languageText,
            ),
            trailing: _MetaItem(icon: Icons.star_rounded, text: ratingText),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                rateText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const Text(
                '/hr',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: onViewProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                  child: const Text(
                    'View Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name, String email) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  String _serviceArea(InstructorModel instructor) {
    final city = instructor.serviceAreaCity?.trim();
    if (city != null && city.isNotEmpty) {
      return city.toUpperCase();
    }
    final area = instructor.serviceArea?.trim();
    if (area != null && area.isNotEmpty) {
      return area.toUpperCase();
    }
    return 'ONTARIO';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: leading),
        const SizedBox(width: 10),
        Expanded(child: trailing),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
