import 'package:flutter/material.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Step 4: summary with Edit links, and the agreement checkbox (wireframe Ph-07)
class StepReview extends StatefulWidget {
  const StepReview({super.key, required this.draft, required this.onEdit});

  final RegistrationDraft draft;
  final void Function(int step) onEdit;

  @override
  State<StepReview> createState() => _StepReviewState();
}

class _StepReviewState extends State<StepReview> {
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  RegistrationDraft get d => widget.draft;

  // One summary box with an Edit link
  Widget _section(String title, int step, List<(String, String)> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              TextButton(onPressed: () => widget.onEdit(step), child: const Text('Edit')),
            ]),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 140,
                      child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
                  Expanded(child: Text(value, textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = (d.openDays.toList()..sort()).map((i) => _days[i]).join(', ');
    final hours = '$days · ${d.opensAt.format(context)} – ${d.closesAt.format(context)}';
    final expiry = d.ltoExpiry == null
        ? '-'
        : MaterialLocalizations.of(context).formatMediumDate(d.ltoExpiry!);
    final middle = d.middleName.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review and submit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('Check everything before you submit. You can still edit any part.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),

        _section('Pharmacy', 0, [
          ('Name', '${d.pharmacyName.text} · ${d.branchName.text}'),
          ('Address', d.address.text),
          ('Contact', '${d.contactNumber.text} · ${d.pharmacyEmail.text}'),
          ('Hours', hours),
          ('Location', 'Pin set · ${d.latitude.text}, ${d.longitude.text}'),
        ]),
        const SizedBox(height: AppSpacing.md),
        _section('License', 1, [
          ('FDA LTO number', d.ltoNumber.text),
          ('Expires', expiry),
          ('Documents', '${d.ltoFile?.name ?? '-'}, ${d.storefrontFile?.name ?? '-'}'),
        ]),
        const SizedBox(height: AppSpacing.md),
        _section('Owner account', 2, [
          ('Name', [d.firstName.text, middle, d.lastName.text].where((s) => s.isNotEmpty).join(' ')),
          ('Mobile', d.mobile.text),
          ('Email', d.email.text),
          ('Username', d.username.text),
        ]),
        const SizedBox(height: AppSpacing.lg),

        // The required agreement
        FormField<bool>(
          initialValue: d.agreed,
          validator: (v) => v == true ? null : 'Tick this box to submit.',
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: d.agreed,
                onChanged: (v) {
                  setState(() => d.agreed = v ?? false);
                  field.didChange(d.agreed);
                },
                title: const Text(
                  'I confirm these details are true and match our FDA License to Operate. '
                  'I agree to the MediTech Terms and Privacy Notice (Data Privacy Act of 2012).',
                ),
              ),
              if (field.errorText != null)
                Text(field.errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}