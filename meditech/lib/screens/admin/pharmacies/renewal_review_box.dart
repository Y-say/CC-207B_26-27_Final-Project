import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/lto_renewal.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../providers/lto_renewal_providers.dart';
import '../../../services/lto_renewal_service.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// A suspended owner's renewed LTO, with Accept and Reject
class RenewalReviewBox extends ConsumerStatefulWidget {
  const RenewalReviewBox({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<RenewalReviewBox> createState() => _RenewalReviewBoxState();
}

class _RenewalReviewBoxState extends ConsumerState<RenewalReviewBox> {
  bool _busy = false;

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // Reload the box, the drawer, and the FDA check state (the LTO may have changed)
  void _refresh() {
    ref.invalidate(latestRenewalProvider(widget.branchId));
    ref.invalidate(applicationDetailsProvider(widget.branchId));
    ref.invalidate(branchHasMatchProvider(widget.branchId));
    ref.invalidate(pharmacyListProvider);
  }

  // Open the renewal file
  Future<void> _openFile(LtoRenewal r) async {
    try {
      final link = await ref.read(ltoRenewalServiceProvider).fileLink(r.storagePath);
      if (!mounted) return;
      if (r.isImage) {
        await showTabletImageViewer(
          context: context,
          imageUrl: link,
          title: 'Renewed LTO',
        );
      } else {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _tell('Could not open the file.');
    }
  }

  // Run a review, then refresh
  Future<void> _review(LtoRenewal r, bool accept, [String? reason]) async {
    setState(() => _busy = true);
    try {
      await ref.read(ltoRenewalServiceProvider).review(r.id, accept: accept, reason: reason);
      _refresh();
      _tell(accept
          ? 'Renewal accepted. Record a "Matched" FDA check, then activate the pharmacy.'
          : 'Renewal rejected. The owner was told why.');
    } catch (e) {
      _tell(LtoRenewalService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Confirm before accepting
  Future<void> _accept(LtoRenewal r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Accept LTO renewal?',
      message: 'Are you sure you want to accept this renewed LTO?',
      actionLabel: 'Accept',
      cancelLabel: 'Cancel',
    );
    if (ok) await _review(r, true);
  }

  // Confirm before asking for the required rejection reason
  Future<void> _reject(LtoRenewal r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reject LTO renewal?',
      message: 'Are you sure you want to reject this renewed LTO? The owner will be notified.',
      actionLabel: 'Reject',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final reason = await showReasonDialog(
      context,
      title: 'Reason for rejecting renewal',
      description: 'Enter the reason that will be sent to the owner.',
      actionLabel: 'Reject',
      cancelLabel: 'Cancel',
    );
    if (reason != null) await _review(r, false, reason);
  }

  @override
  Widget build(BuildContext context) {
    final renewal = ref.watch(latestRenewalProvider(widget.branchId)).value;
    if (renewal == null || renewal.status != 'pending') return const SizedBox.shrink();

    final date = DateFormat('MMM d, yyyy');
    final r = renewal;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Renewed LTO received',
            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Text('LTO ${r.ltoNumber} · expires ${date.format(r.ltoExpiry)}'),
        Text('Sent ${date.format(r.createdAt)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        TextButton.icon(
          onPressed: () => _openFile(r),
          icon: Icon(r.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
          label: const Text('Open the renewed LTO'),
        ),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _reject(r),
              style: TabletControls.dangerOutlined(),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _accept(r),
              style: TabletControls.actionFilled(),
              child: const Text('Accept'),
            ),
          ),
        ]),
      ]),
    );
  }
}
