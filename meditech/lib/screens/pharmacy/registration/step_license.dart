import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/pharmacy_application.dart';
import '../../../utils/validators.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Step 2: FDA License to Operate and storefront photo (wireframe Ph-05)
class StepLicense extends StatefulWidget {
  const StepLicense({super.key, required this.draft, required this.errors});

  final RegistrationDraft draft;
  final Map<String, String> errors;

  @override
  State<StepLicense> createState() => _StepLicenseState();
}

class _StepLicenseState extends State<StepLicense> {
  static const _maxBytes = 5 * 1024 * 1024;

  RegistrationDraft get d => widget.draft;

  // Pick the LTO expiry date (today or later)
  Future<void> _pickExpiry(FormFieldState<DateTime> field) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: d.ltoExpiry ?? today.add(const Duration(days: 365)),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
    );
    if (picked == null) return;
    setState(() => d.ltoExpiry = picked);
    field.didChange(picked);
  }

  // Pick a photo or PDF, up to 5 MB
  Future<PickedDocument?> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null) return null;

    // Read the file's contents (works on phones and in Chrome)
    final bytes = await file.readAsBytes();

    // Files over 5 MB are refused
    if (bytes.length > _maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That file is over 5 MB. Choose a smaller one.')));
      }
      return null;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final type = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
    return PickedDocument(name: file.name, bytes: bytes, mimeType: type);
  }

  // A file box: pick button, or the chosen file with a remove button
  Widget _fileField({
    required String label,
    required PickedDocument? value,
    required void Function(PickedDocument?) onChanged,
    required String? serverError,
  }) {
    return FormField<PickedDocument>(
      initialValue: value,
      validator: (v) => v == null ? 'Upload this file.' : null,
      builder: (field) {
        final error = field.errorText ?? serverError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: error != null ? AppColors.danger : AppColors.border),
              ),
              child: field.value == null
                  ? TextButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose photo or PDF'),
                      onPressed: () async {
                        final picked = await _pickFile();
                        if (picked != null) {
                          setState(() => onChanged(picked));
                          field.didChange(picked);
                        }
                      },
                    )
                  : Row(children: [
                      const Icon(Icons.check_circle, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(field.value!.name, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        tooltip: 'Remove file',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() => onChanged(null));
                          field.didChange(null);
                        },
                      ),
                    ]),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(error, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.errors;
    const gap = SizedBox(height: AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload your FDA License to Operate',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'We use this to check that your pharmacy is licensed. '
          'Your documents are seen only by the MediTech administrator.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        // LTO number
        AppTextField(label: 'FDA LTO number', controller: d.ltoNumber,
            errorText: e['lto_number'], validator: (v) => Validators.required(v)),
        gap,

        // LTO expiry date
        FormField<DateTime>(
          initialValue: d.ltoExpiry,
          validator: (v) => v == null ? 'Pick the expiry date.' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LTO expiry date', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(d.ltoExpiry == null
                    ? 'Pick a date'
                    : MaterialLocalizations.of(context).formatMediumDate(d.ltoExpiry!)),
                onPressed: () => _pickExpiry(field),
              ),
              if (field.errorText != null || e['lto_expiry'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(field.errorText ?? e['lto_expiry']!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
        ),
        gap,

        // The two files
        _fileField(
          label: 'Photo or PDF of your FDA License to Operate',
          value: d.ltoFile,
          onChanged: (f) => d.ltoFile = f,
          serverError: e['lto_file'],
        ),
        gap,
        _fileField(
          label: 'Photo of your storefront',
          value: d.storefrontFile,
          onChanged: (f) => d.storefrontFile = f,
          serverError: e['storefront_file'],
        ),
        gap,
        const Text(
          'JPG, PNG, or PDF, max 5 MB each. The administrator checks your LTO on the FDA '
          "verification portal. You'll add your staff and their PRC licenses after approval.",
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}