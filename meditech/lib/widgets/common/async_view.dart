import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Shows loading, error, empty, or the real content for any screen's data
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Still loading
      loading: () => const Center(child: CircularProgressIndicator()),
      // Something went wrong
      error: (_, _) => StateMessage(
        icon: Icons.error_outline,
        message: 'Something went wrong. Please try again.',
        onRetry: onRetry,
      ),
      // Loaded: nothing to show, or the content
      data: (data) => (isEmpty?.call(data) ?? false)
          ? StateMessage(icon: Icons.inbox_outlined, message: emptyMessage)
          : builder(data),
    );
  }
}

// A centred icon and message, with an optional Retry button
class StateMessage extends StatelessWidget {
  const StateMessage({super.key, required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

// Strip shown at the top when the phone is offline
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: const Text(
        "You're offline. Showing the last loaded data.",
        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
      ),
    );
  }
}