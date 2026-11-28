import 'package:flutter/material.dart';

import '../../../widgets/theme/app_colors.dart';

/// Success modal after a catalogue medicine is approved or reactivated.
Future<void> showMedicineActivatedModal(
  BuildContext context, {
  required String brandName,
  required bool firstApproval,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
      title: Text(firstApproval ? 'Medicine approved' : 'Medicine reactivated'),
      content: Text(
        firstApproval
            ? '$brandName is now active in the MediTech catalogue. '
                'Pharmacies can add it to inventory and customers can search for it.'
            : '$brandName is active again in search and the pharmacy catalogue picker.',
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