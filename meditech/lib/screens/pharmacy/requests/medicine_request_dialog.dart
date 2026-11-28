import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/medicine_request_providers.dart';
import '../../../services/medicine_request_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Opens the "Request a medicine" form; returns the request number if sent
Future<String?> showMedicineRequestDialog(BuildContext context, {String? searchedName}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _MedicineRequestDialog(searchedName: searchedName),
  );
}

// Opens the dialog and confirms success to the user
Future<void> openMedicineRequestFlow(BuildContext context, {String? searchedName}) async {
  final number = await showMedicineRequestDialog(context, searchedName: searchedName);
  if (!context.mounted || number == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Request $number sent to the MediTech administrator. '
        'You’ll be notified when it’s reviewed.',
      ),
    ),
  );
}

class _MedicineRequestDialog extends ConsumerStatefulWidget {
  const _MedicineRequestDialog({this.searchedName});

  final String? searchedName; // what they searched for, to save retyping

  @override
  ConsumerState<_MedicineRequestDialog> createState() => _MedicineRequestDialogState();
}

class _MedicineRequestDialogState extends ConsumerState<_MedicineRequestDialog> {
  final _form = GlobalKey<FormState>();
  late final _generic = TextEditingController(text: widget.searchedName ?? '');
  final _brand = TextEditingController();
  final _strength = TextEditingController();
  final _dosageForm = TextEditingController();
  final _registration = TextEditingController();
  final _notes = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_generic, _brand, _strength, _dosageForm, _registration, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  // Send the request
  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final number = await ref.read(medicineRequestServiceProvider).submit({
        'generic_name': _generic.text,
        'brand_name': _brand.text,
        'strength': _strength.text,
        'dosage_form': _dosageForm.text,
        'registration_number': _registration.text,
        'notes': _notes.text,
      });
      if (mounted) Navigator.pop(context, number);
    } catch (e) {
      setState(() => _error = MedicineRequestService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.md);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Request a medicine',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  "Can't find it in the catalogue? Tell us what it is, and the MediTech "
                  "administrator will check it with the FDA and add it. You'll be notified.",
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  label: 'Generic name',
                  hint: 'e.g. Cefalexin',
                  controller: _generic,
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Enter the generic name.' : null,
                ),
                gap,
                AppTextField(label: 'Brand name (optional)', hint: 'e.g. Keflex', controller: _brand),
                gap,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: AppTextField(label: 'Strength (optional)', hint: 'e.g. 500 mg',
                        controller: _strength),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(label: 'Dosage form (optional)', hint: 'e.g. Capsule',
                        controller: _dosageForm),
                  ),
                ]),
                gap,
                AppTextField(label: 'FDA registration number (optional)',
                    hint: 'If you know it, e.g. DR-XY12345', controller: _registration),
                gap,
                AppTextField(label: 'Notes (optional)', hint: 'e.g. Patients ask for this often',
                    controller: _notes, maxLines: 3, maxLength: 500),

                // A problem from the server
                if (_error != null) ...[
                  gap,
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],

                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send request'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}