import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Branch-level FDA LTO renewal: prepare early, upload only after admin deactivates the branch.
class LtoRenewalPrepPanel extends StatelessWidget {
  const LtoRenewalPrepPanel.branchSettings({
    super.key,
    required this.ltoExpired,
  }) : _uploadStep = false;

  const LtoRenewalPrepPanel.uploadStep({super.key}) : ltoExpired = false, _uploadStep = true;

  final bool ltoExpired;
  final bool _uploadStep;

  List<String> get _steps {
    if (_uploadStep) {
      return const [
        'Use the renewed license from the FDA—the new number and expiry—not the expired LTO on file.',
        'Attach a clear photo or PDF (up to 5 MB).',
        'After you send it, an administrator verifies it against the registry and reactivates your pharmacy.',
      ];
    }
    return [
      'Renew your License to Operate with the FDA.',
      'Keep a photo or PDF of the renewed license ready (PDF, JPG, or PNG, up to 5 MB).',
      if (ltoExpired)
        'If this branch is still online, wait for the MediTech administrator to take it offline.'
      else
        'You can keep using the dashboard until the administrator deactivates the branch near expiry.',
      'Upload only after deactivation: sign in as owner and submit the renewed LTO on the renewal screen—not here, and not while the pharmacy is still online.',
    ];
  }

  String get _title {
    if (_uploadStep) return 'Submit your renewed LTO';
    return ltoExpired ? 'LTO expired — prepare your renewal' : 'LTO expiring soon — prepare your renewal';
  }

  @override
  Widget build(BuildContext context) {
    final bg = _uploadStep ? AppColors.primary.withValues(alpha: 0.08) : AppColors.warningLight;
    final border = _uploadStep ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border;
    final titleColor = _uploadStep ? AppColors.primary : AppColors.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(_steps.length, (i) {
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}