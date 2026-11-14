import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

// Asks before any important action; returns true if the user confirms
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? subject,
  required List<String> whatWillHappen,
  required String actionLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and title
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: destructive ? AppColors.dangerLight : AppColors.primaryLight,
                  child: Icon(Icons.error_outline,
                      color: destructive ? AppColors.danger : AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ]),
              // What it's about, like "Grace Villanueva · Amoxil × 21"
              if (subject != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(subject, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              // The list of what will happen
              const SizedBox(height: AppSpacing.md),
              const Text('WHAT WILL HAPPEN',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: AppSpacing.sm),
              for (final point in whatWillHappen)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('•  $point'),
                ),
              // Go back and the action button
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border)),
                    child: const Text('Go back'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: destructive ? AppTheme.dangerButton : null,
                    child: Text(actionLabel),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}