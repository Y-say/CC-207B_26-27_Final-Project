import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';

// Shown after a password reset succeeds; only action is to open sign-in.
Future<void> showPasswordChangedModal(
  BuildContext context, {
  String signInPath = '/sign-in',
  String message =
      'Your password has been updated. Sign in with your email and new password.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
      title: const Text('Password changed'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) {
              context.go(signInPath);
            }
          },
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
}