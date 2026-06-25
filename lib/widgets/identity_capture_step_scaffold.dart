import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class IdentityCaptureStepScaffold extends StatelessWidget {
  const IdentityCaptureStepScaffold({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
    this.error,
    this.onRetry,
    this.isBusy = false,
  });

  final String title;
  final String message;
  final VoidCallback onClose;
  final String? error;
  final VoidCallback? onRetry;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final errorText = error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filled(
                  onPressed: isBusy ? null : onClose,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                errorText == null
                    ? Icons.photo_camera_outlined
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 54,
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                errorText ?? message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (isBusy) ...[
                const SizedBox(height: 28),
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ],
              if (errorText != null && onRetry != null) ...[
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('Try again'),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
