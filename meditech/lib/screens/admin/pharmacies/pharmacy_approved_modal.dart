import 'package:flutter/material.dart';

import '../../../widgets/theme/app_colors.dart';

/// Success modal after an admin approves a pharmacy application.
Future<void> showPharmacyApprovedModal(
  BuildContext context, {
  required String pharmacyName,
  required String branchName,
  required String displayId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
      title: const Text('Pharmacy approved'),
      content: Text(
        '$pharmacyName · $branchName ($displayId) is now on MediTech.\n\n'
        'The owner can sign in and add inventory. Patients can find the branch '
        'once stock is listed.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}