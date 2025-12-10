import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_panel.dart';

enum _AuthStage { choice, signUp, signIn }

class AuthScreen extends ConsumerStatefulWidget {
  final String role;

  const AuthScreen({
    super.key,
    required this.role,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _signUpFormKey = GlobalKey<FormState>();
  final _signInFormKey = GlobalKey<FormState>();

  // Sign up controllers
  final _signUpFirstNameController = TextEditingController();
  final _signUpLastNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPhoneController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  // Sign in controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  bool _isSignUpLoading = false;
  bool _isSignInLoading = false;
  bool _signUpObscurePassword = true;
  bool _signInObscurePassword = true;
  _AuthStage _stage = _AuthStage.choice;

  @override
  void dispose() {
    _signUpFirstNameController.dispose();
    _signUpLastNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPhoneController.dispose();
    _signUpPasswordController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    super.dispose();
  }

  Color get _primaryRoleColor =>
      widget.role == 'learner' ? AppColors.ocean : AppColors.golden;

  String get _roleLabel => widget.role == 'learner' ? 'Learner' : 'Instructor';

  void _goToStage(_AuthStage stage) {
    FocusScope.of(context).unfocus();
    setState(() => _stage = stage);
  }

  void _returnToRoleSelection() {
    FocusScope.of(context).unfocus();
    context.go(AppRoutes.roleSelection);
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() => _isSignUpLoading = true);

    try {
      final response = await SupabaseService.signUp(
        email: _signUpEmailController.text.trim(),
        password: _signUpPasswordController.text,
        firstName: _signUpFirstNameController.text.trim(),
        lastName: _signUpLastNameController.text.trim(),
        role: widget.role,
        phone: _signUpPhoneController.text.trim(),
      );

      if (!mounted) return;

      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Check your email for verification before logging in.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.role == 'learner') {
          context.go(AppRoutes.learnerQuestionnaire, extra: widget.role);
        } else {
          context.go(AppRoutes.instructorQuestionnaire, extra: widget.role);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSignUpLoading = false);
      }
    }
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _isSignInLoading = true);

    try {
      final response = await SupabaseService.signIn(
        email: _signInEmailController.text.trim(),
        password: _signInPasswordController.text,
      );

      if (!mounted) return;

      final role =
          response.user?.userMetadata?['role'] as String? ?? widget.role;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome back!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (role == 'instructor') {
        context.go(AppRoutes.instructorHome);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSignInLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _stage == _AuthStage.choice
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goToStage(_AuthStage.choice),
              ),
              title: Text(
                _stage == _AuthStage.signUp
                    ? '$_roleLabel Sign Up'
                    : '$_roleLabel Sign In',
              ),
            ),
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: () {
                switch (_stage) {
                  case _AuthStage.choice:
                    return _buildChoiceView(key: const ValueKey('choice'));
                  case _AuthStage.signUp:
                    return _buildSignUpForm(key: const ValueKey('signUp'));
                  case _AuthStage.signIn:
                    return _buildSignInForm(key: const ValueKey('signIn'));
                }
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceView({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.black87,
              tooltip: 'Back to role selection',
              onPressed: _returnToRoleSelection,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: _AuthHeader(
              role: widget.role,
              title: 'Hi $_roleLabel!',
              subtitle: 'How would you like to continue?',
            ),
          ),
          const SizedBox(height: 40),
          _ChoiceCard(
            title: 'Create Account',
            subtitle: _roleLabel == 'Learner'
                ? 'New to Drive T? Start your journey as a learner.'
                : 'Join Drive T as an instructor and connect with learners.',
            iconAsset: 'assets/icons/signup.svg',
            onTap: () => _goToStage(_AuthStage.signUp),
          ),
          const SizedBox(height: 20),
          _ChoiceCard(
            title: 'Sign In',
            subtitle: 'Already have an account? Pick up where you left off.',
            iconAsset: 'assets/icons/signin.svg',
            onTap: () => _goToStage(_AuthStage.signIn),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _AuthHeader(
                role: widget.role,
                title: 'Create Your Account',
                subtitle: 'Join Drive T as a ${widget.role}',
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _signUpFirstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _signUpLastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _signUpEmailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _signUpPhoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _signUpPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: _signUpObscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _signUpObscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(() {
                  _signUpObscurePassword = !_signUpObscurePassword;
                }),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSignUpLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRoleColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSignUpLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _AuthHeader(
                role: widget.role,
                title: 'Welcome Back',
                subtitle: 'Sign in to continue as a ${widget.role}',
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _signInEmailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _signInPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: _signInObscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _signInObscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(() {
                  _signInObscurePassword = !_signInObscurePassword;
                }),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSignInLoading ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRoleColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSignInLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => _goToStage(_AuthStage.signUp),
                child: const Text('Need an account? Create one'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ocean, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;

  const _AuthHeader({
    required this.role,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isLearner = role == 'learner';
    final Color accentColor = isLearner ? AppColors.ocean : AppColors.golden;
    final Color titleColor =
        isLearner ? const Color(0xFF162660) : const Color(0xFFF0C845);
    final String iconAsset =
        isLearner ? 'assets/icons/learner.svg' : 'assets/icons/instructor.svg';

    return Column(
      children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(28),
          opacity: 0.14,
          padding: const EdgeInsets.all(22),
          child: SizedBox(
            width: 110,
            height: 110,
            child: SvgPicture.asset(
              iconAsset,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconAsset;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(24),
      opacity: 0.12,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 18, color: Colors.black.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5FAFF),
                Color(0xFFEBF8FF),
                Color(0xFFF4F5FF),
              ],
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: _AuthBlurOrb(
            diameter: 280,
            color: const Color(0xFFBEE2FF).withOpacity(0.7),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -60,
          child: _AuthBlurOrb(
            diameter: 320,
            color: const Color(0xFFD7F8ED).withOpacity(0.65),
          ),
        ),
      ],
    );
  }
}

class _AuthBlurOrb extends StatelessWidget {
  const _AuthBlurOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 120,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

