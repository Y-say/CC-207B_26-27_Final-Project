import 'package:flutter/material.dart';

import '../../../widgets/theme/app_colors.dart';

/// Success modal after pharmacy application submit or resubmit (customer sign-up style).
Future<void> showPharmacyApplicationSubmittedModal(
  BuildContext context, {
  required String applicationId,
  required String email,
  required bool resubmitted,
  required VoidCallback onContinue,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
      title: Text(resubmitted ? 'Application resubmitted' : 'Application submitted'),
      content: Text(
        resubmitted
            ? 'Application ID: $applicationId\n\n'
                "We've received your updated application. "
                "We'll notify you once it's reviewed."
            : 'Application ID: $applicationId\n\n'
                "We've received your pharmacy application. "
                "We'll email $email once it's reviewed.",
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) onContinue();
          },
          child: Text(resubmitted ? 'Back to status' : 'Back to sign in'),
        ),
      ],
    ),
  );
}