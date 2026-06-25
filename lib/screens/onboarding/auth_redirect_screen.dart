import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/signup_flow_state.dart';
import '../../services/supabase_service.dart';

class AuthRedirectScreen extends StatefulWidget {
  const AuthRedirectScreen({
    super.key,
    this.flow = 'signup',
  });

  final String flow;

  @override
  State<AuthRedirectScreen> createState() => _AuthRedirectScreenState();
}

class _AuthRedirectScreenState extends State<AuthRedirectScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _hasNavigated = false;
  String? _errorMessage;

  bool get _isRecoveryFlow => widget.flow == 'recovery';

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final user = data.session?.user;
        if (user != null) {
          unawaited(_continueToPassword(user.email));
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveRedirect();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveRedirect() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser != null) {
      _continueToPassword(currentUser.email);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted || _hasNavigated) return;

    final retryUser = SupabaseService.currentUser;
    if (retryUser != null) {
      _continueToPassword(retryUser.email);
      return;
    }

    setState(() {
      _errorMessage = _isRecoveryFlow
          ? 'We could not verify your password reset session yet. Open the latest reset email again, or return to login.'
          : 'We could not confirm your session yet. Open the latest confirmation link again, or return to sign up.';
    });
  }

  Future<void> _continueToPassword(String? email) async {
    if (!mounted || _hasNavigated) return;
    SignupFlowState? flowState;
    if (!_isRecoveryFlow) {
      flowState = await SupabaseService.getPendingSignUpFlow(
        email: email,
        authUserId: SupabaseService.currentUser?.id,
      );
    }
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    context.go(
      AppRoutes.newPassword,
      extra: {
        if (flowState != null) ...flowState.toMap() else 'email': email,
        'flow': widget.flow,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isRecoveryFlow
                      ? 'Opening password reset...'
                      : 'Confirming your account...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ??
                      (_isRecoveryFlow
                          ? 'Please wait while we open your secure password reset link.'
                          : 'Please wait while we finish your email confirmation.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go(
                      _isRecoveryFlow ? AppRoutes.auth : AppRoutes.signUpEmail,
                    ),
                    child: Text(
                      _isRecoveryFlow ? 'Back to Login' : 'Back to Sign Up',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
