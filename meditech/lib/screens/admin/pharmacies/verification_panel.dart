import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/application_details.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../providers/official_link_providers.dart';
import '../../../services/admin_pharmacy_service.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import 'pharmacy_approved_modal.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// FDA check results and how they look
const _results = <String, (String, BadgeTone)>{
  'matched': ('Matched and valid', BadgeTone.success),
  'not_found': ('Not found', BadgeTone.danger),
  'details_mismatch': ("Details don't match", BadgeTone.danger),
  'expired': ('Expired', BadgeTone.danger),
  'unreadable': ("Couldn't check", BadgeTone.neutral),
};

// Manual FDA check, history, and the Approve / Reject buttons
class VerificationPanel extends ConsumerStatefulWidget {
  const VerificationPanel({super.key, required this.details});

  final ApplicationDetails details;

  @override
  ConsumerState<VerificationPanel> createState() => _VerificationPanelState();
}

class _VerificationPanelState extends ConsumerState<VerificationPanel> {
  final _notes = TextEditingController();
  String? _result; // the result being recorded
  bool _busy = false;

  ApplicationDetails get d => widget.details;
  AdminPharmacyService get _service => ref.read(adminPharmacyServiceProvider);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // Reload everything this panel and the table show
  void _refresh() {
    ref.invalidate(branchChecksProvider(d.id));
    ref.invalidate(branchHasMatchProvider(d.id));
    ref.invalidate(applicationDetailsProvider(d.id));
    ref.invalidate(pharmacyListProvider);
  }

  // Run an action with a spinner and a friendly error
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      _tell(success);
    } catch (e) {
      _tell(AdminPharmacyService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Copy the LTO number for pasting into the FDA portal
  Future<void> _copyLto() async {
    await Clipboard.setData(ClipboardData(text: d.ltoNumber));
    _tell('LTO number copied.');
  }

  Future<void> _openPortal() async {
    final portal = await ref.read(fdaVerificationPortalProvider.future);
    if (portal == null) {
      _tell('No verification portal is configured in the database yet.');
      return;
    }
    try {
      await launchUrl(Uri.parse(portal.url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _tell('Could not open ${portal.label}.');
    }
  }

  // Save the chosen result
  Future<void> _record() async {
    final result = _result;
    if (result == null) {
      _tell('Choose a result first.');
      return;
    }
    await _run(() => _service.recordCheck(d.id, result, _notes.text), 'FDA check recorded.');
    setState(() {
      _result = null;
      _notes.clear();
    });
  }

  // Ask first, then approve
  Future<void> _approve() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve ${d.pharmacyName}?',
      subject: '${d.branchName} · ${d.displayId}',
      whatWillHappen: const [
        'The pharmacy goes live and patients can find it once it adds inventory.',
        "The owner's account is unlocked and they're notified.",
        'The approval is saved in the audit records.',
      ],
      actionLabel: 'Approve pharmacy',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await _service.approve(d.id);
      _refresh();
      if (!mounted) return;
      await showPharmacyApprovedModal(
        context,
        pharmacyName: d.pharmacyName,
        branchName: d.branchName,
        displayId: d.displayId,
      );
    } catch (e) {
      _tell(AdminPharmacyService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Ask for a reason, then reject
  Future<void> _reject() async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject application',
      description: 'The owner sees this reason and can fix the details and resubmit.',
      actionLabel: 'Reject application',
      hint: "e.g. The address on your LTO doesn't match the address you entered.",
    );
    if (reason != null) await _run(() => _service.reject(d.id, reason), 'Application rejected.');
  }

  @override
  Widget build(BuildContext context) {
    final checks = ref.watch(branchChecksProvider(d.id));
    final canApprove = ref.watch(branchHasMatchProvider(d.id)).value ?? false;
    final pending = d.status == 'pending_approval';
    final date = DateFormat('MMM d, yyyy · h:mm a');
    final portal = ref.watch(fdaVerificationPortalProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FDA VERIFICATION',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: AppSpacing.sm),

        // Step 1 and 2: copy the number, open the portal
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          OutlinedButton.icon(
            onPressed: _copyLto,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy LTO Number'),
            style: TabletControls.actionOutlined(),
          ),
          if (portal != null)
            OutlinedButton.icon(
              onPressed: _openPortal,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(portal.label),
              style: TabletControls.actionOutlined(),
            ),
        ]),
        if (portal != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Opens ${portal.label} in your browser. Compare the name, address, '
            'and expiry with this application, then record what you found.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],

        // Step 3: record the result (only while waiting)
        if (pending) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final entry in _results.entries)
              ChoiceChip(
                label: Text(entry.value.$1),
                selected: _result == entry.key,
                onSelected: (_) => setState(() => _result = entry.key),
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notes,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Notes (optional), e.g. what didn\'t match'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _record,
              style: TabletControls.actionFilled(),
              child: const Text('Save check'),
            ),
          ),
        ],

        // History of checks
        const SizedBox(height: AppSpacing.md),
        checks.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load the check history.',
              style: TextStyle(color: AppColors.danger)),
          data: (list) => list.isEmpty
              ? const Text('No FDA checks recorded yet.', style: TextStyle(color: AppColors.textMuted))
              : Column(children: [
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        StatusBadge(_results[c.result]?.$1 ?? c.result,
                            tone: _results[c.result]?.$2 ?? BadgeTone.neutral),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Manually checked against FDA records on ${date.format(c.checkedAt)}',
                                style: const TextStyle(fontSize: 13)),
                            Text('${c.checkedByLabel} · LTO ${c.checkedNumber}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            if (c.notes != null)
                              Text(c.notes!, style: const TextStyle(fontSize: 12)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
        ),

        // Approve and reject (only while waiting)
        if (pending) ...[
          const Divider(height: AppSpacing.xl),
          if (!canApprove)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Approve unlocks after a "Matched and valid" check on the current LTO details.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _reject,
                style: TabletControls.dangerOutlined(),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _busy || !canApprove ? null : _approve,
                style: TabletControls.actionFilled(),
                child: const Text('Approve'),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}