import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/lto_renewal.dart';
import '../../../models/pharmacy_application.dart';
import '../../../providers/lto_renewal_providers.dart';
import '../../../services/lto_renewal_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// What a suspended owner sees: why the pharmacy is offline, and the renewal form
class LtoRenewalScreen extends ConsumerWidget {
  const LtoRenewalScreen({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(ownBranchProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                child: AsyncView<OwnBranch?>(
                  value: branch,
                  onRetry: () => ref.invalidate(ownBranchProvider),
                  isEmpty: (b) => b == null,
                  emptyMessage: 'No pharmacy found for this account.',
                  builder: (b) => _Content(branch: b!, onSignOut: onSignOut),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.branch, this.onSignOut});

  final OwnBranch branch;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = branch;
    final date = DateFormat('MMM d, yyyy');
    final renewal = ref.watch(latestRenewalProvider(b.id));

    // Reactivated: the owner just needs to sign in again for full access
    if (b.status == 'active') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 48),
        const SizedBox(height: AppSpacing.md),
        const Text('Your pharmacy is back online',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        const Text('Sign in again to open your dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onSignOut, child: const Text('Sign in again')),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/Meditech Logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text('MediTech Pharmacy',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      const Text('Your pharmacy is offline',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: AppSpacing.xs),
      Text('${b.pharmacyName} · ${b.branchName} (${b.displayId}) is hidden from customers.',
          style: const TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.md),

      // Why it was taken offline
      if (b.deactivationReason != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Deactivation reason',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(b.deactivationReason!),
          ]),
        ),
      const SizedBox(height: AppSpacing.md),
      Text('Current LTO: ${b.ltoNumber} · Expires ${date.format(b.ltoExpiry)}',
          style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      const Divider(height: AppSpacing.xl),

      // The renewal: waiting, accepted, or the form
      renewal.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => StateMessage(
          icon: Icons.error_outline,
          message: 'Could not load your renewal.',
          onRetry: () => ref.invalidate(latestRenewalProvider(b.id)),
        ),
        data: (r) => switch (r?.status) {
          'pending' => _Notice(
              icon: Icons.hourglass_top,
              color: AppColors.warning,
              title: 'Renewed LTO sent',
              body: 'LTO ${r!.ltoNumber} · Expires ${date.format(r.ltoExpiry)}\n'
                  'Waiting for admin review.',
            ),
          'accepted' => const _Notice(
              icon: Icons.verified_outlined,
              color: AppColors.primary,
              title: 'Renewed LTO accepted',
              body: 'Your pharmacy will be reactivated shortly.',
            ),
          _ => _RenewalForm(branchId: b.id, rejected: r),
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      Center(child: TextButton(onPressed: onSignOut, child: const Text('Sign out'))),
    ]);
  }
}

// A coloured status box
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(body),
          ]),
        ),
      ]),
    );
  }
}

// The renewal form: new LTO number, expiry, and the file
class _RenewalForm extends ConsumerStatefulWidget {
  const _RenewalForm({required this.branchId, this.rejected});

  final String branchId;
  final LtoRenewal? rejected; // the last renewal, if it was rejected

  @override
  ConsumerState<_RenewalForm> createState() => _RenewalFormState();
}

class _RenewalFormState extends ConsumerState<_RenewalForm> {
  static const _maxBytes = 5 * 1024 * 1024;

  final _form = GlobalKey<FormState>();
  final _ltoNumber = TextEditingController();
  DateTime? _expiry;
  PickedDocument? _file;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ltoNumber.dispose();
    super.dispose();
  }

  // Pick the new expiry date (today or later)
  Future<void> _pickExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? today.add(const Duration(days: 365)),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  // Pick a photo or PDF of the renewed LTO, up to 5 MB
  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxBytes) {
      setState(() => _error = 'That file is over 5 MB. Choose a smaller one.');
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    final type = ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _file = PickedDocument(name: file.name, bytes: bytes, mimeType: type);
      _error = null;
    });
  }

  // Send the renewal
  Future<void> _send() async {
    final valid = _form.currentState?.validate() ?? false;
    if (!valid || _expiry == null || _file == null) {
      setState(() => _error = 'Fill in the LTO number, expiry date, and file.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(ltoRenewalServiceProvider).submit(
            branchId: widget.branchId,
            ltoNumber: _ltoNumber.text,
            ltoExpiry: _expiry!,
            file: _file!,
          );
      ref.invalidate(latestRenewalProvider(widget.branchId)); // shows "waiting for review"
    } catch (e) {
      setState(() => _error = LtoRenewalService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy');

    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Why the last renewal wasn't accepted
        if (widget.rejected != null) ...[
          _Notice(
            icon: Icons.cancel_outlined,
            color: AppColors.danger,
            title: 'Renewal not accepted',
            body: widget.rejected!.reviewReason ?? 'Please submit a clearer copy.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        const Text('Submit renewed LTO',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.md),

        AppTextField(
          label: 'New FDA LTO number',
          controller: _ltoNumber,
          validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the LTO number.' : null,
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New expiry date', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickExpiry,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_expiry == null ? 'Pick a date' : date.format(_expiry!)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LTO document (max 5 MB)', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: Icon(_file == null ? Icons.upload_file : Icons.check_circle,
                          color: _file == null ? null : AppColors.primary),
                      label: Text(
                        _file?.name ?? 'Choose photo or PDF',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send renewed LTO'),
          ),
        ),
      ]),
    );
  }
}