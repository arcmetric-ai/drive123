import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../widgets/glass_panel.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  void _selectRole(String role) {
    setState(() => selectedRole = role);
    context.go(AppRoutes.auth, extra: role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              _buildHero(),
              const SizedBox(height: 36),
              _buildRoleCard(
                title: 'I\'m a Learner',
                subtitle: 'Looking for Driving Lessons',
                iconAsset: 'assets/icons/learner.svg',
                role: 'learner',
                accentColor: const Color(0xFF4EA8DE),
              ),
              const SizedBox(height: 18),
              _buildRoleCard(
                title: 'I\'m an Instructor',
                subtitle: 'Teaching Driving Skills',
                iconAsset: 'assets/icons/instructor.svg',
                role: 'instructor',
                accentColor: const Color(0xFF63E6BE),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(28),
          opacity: 0.14,
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 160,
            height: 160,
            child: SvgPicture.asset(
              'assets/images/role.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Choose your role to get started',
          style: TextStyle(
            fontFamily: 'MartianMono',
            fontSize: 16,
            color: Colors.black.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required String iconAsset,
    required String role,
    required Color accentColor,
  }) {
    final isSelected = selectedRole == role;

    return GlassPanel(
      borderRadius: BorderRadius.circular(24),
      opacity: 0.12,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectRole(role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor.withOpacity(0.4)
                    : Colors.black.withOpacity(0.06),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: SvgPicture.asset(
                      iconAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'MartianMono',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accentColor : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'MartianMono',
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle,
                      color: accentColor,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
