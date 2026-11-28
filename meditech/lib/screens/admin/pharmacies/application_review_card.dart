import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/application_details.dart';
import '../../../models/official_link.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../providers/official_link_providers.dart';
import '../../../services/admin_pharmacy_service.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import 'pharmacy_approved_modal.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

/// Admin-facing labels; values are stored in `verification_checks.result`.
const _licenseOutcomes = <String, String>{
  'matched': 'Accept — matches application',
  'details_mismatch': 'Details do not match upload',
  'not_found': 'LTO missing from documents',
  'expired': 'LTO is expired',
  'unreadable': 'Documents unclear',
};

class _LicenseChecklistStep {
  const _LicenseChecklistStep(this.id, this.label, {this.opensLicenseUpload = false});

  final String id;
  final String label;
  final bool opensLicenseUpload;
}

const _licenseChecklist = <_LicenseChecklistStep>[
  _LicenseChecklistStep('viewed_license', 'Reviewed the uploaded license document', opensLicenseUpload: true),
  _LicenseChecklistStep('expiry_ok', 'License expiry is visible and not expired'),
  _LicenseChecklistStep('name_ok', 'Business name on the license matches this application'),
  _LicenseChecklistStep('address_ok', 'Address on the license matches this application'),
  _LicenseChecklistStep('review_saved', 'Recorded Accept under License review'),
];

// Pending application review (wireframe: waiting card, documents, map check, approve / reject)
class ApplicationReviewCard extends ConsumerStatefulWidget {
  const ApplicationReviewCard({
    super.key,
    required this.details,
    required this.onOpenDocument,
  });

  final ApplicationDetails details;
  final Future<void> Function(DocumentInfo doc) onOpenDocument;

  @override
  ConsumerState<ApplicationReviewCard> createState() => _ApplicationReviewCardState();
}

class _ApplicationReviewCardState extends ConsumerState<ApplicationReviewCard> {
  final _notes = TextEditingController();
  String? _result;
  bool _busy = false;
  final Set<String> _checklistDone = {};

  ApplicationDetails get d => widget.details;
  AdminPharmacyService get _service => ref.read(adminPharmacyServiceProvider);

  @override
  void didUpdateWidget(covariant ApplicationReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details.id != widget.details.id) {
      _checklistDone.clear();
      _result = null;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DocumentInfo? get _licenseUpload {
    for (final doc in d.documents) {
      if (doc.kind == 'lto') return doc;
    }
    return null;
  }

  bool _stepDone(String id, bool reviewSaved) {
    if (id == 'review_saved') return reviewSaved;
    return _checklistDone.contains(id);
  }

  bool _checklistComplete(bool reviewSaved) =>
      _licenseChecklist.every((step) => _stepDone(step.id, reviewSaved));

  void _toggleChecklistStep(String id, bool reviewSaved) {
    if (id == 'review_saved') return;
    setState(() {
      if (_checklistDone.contains(id)) {
        _checklistDone.remove(id);
      } else {
        _checklistDone.add(id);
      }
    });
  }

  Future<void> _tapChecklistStep(_LicenseChecklistStep step, bool reviewSaved) async {
    if (_busy) return;
    if (step.id == 'review_saved') {
      if (!reviewSaved) {
        _tell('Choose Accept and tap Save review or Accept from uploaded documents.');
      }
      return;
    }
    if (step.opensLicenseUpload) {
      final doc = _licenseUpload;
      if (doc == null) {
        _tell('No license document uploaded yet.');
        return;
      }
      await widget.onOpenDocument(doc);
      setState(() => _checklistDone.add(step.id));
      return;
    }
    _toggleChecklistStep(step.id, reviewSaved);
  }

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _refresh() {
    ref.invalidate(branchChecksProvider(d.id));
    ref.invalidate(branchHasMatchProvider(d.id));
    ref.invalidate(applicationDetailsProvider(d.id));
    ref.invalidate(pharmacyListProvider);
  }

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

  Future<void> _copyLto() async {
    await Clipboard.setData(ClipboardData(text: d.ltoNumber));
    _tell('LTO number copied.');
  }

  Future<void> _openPortal(OfficialPortalLink? portal) async {
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

  Future<void> _recordCheck() async {
    final result = _result;
    if (result == null) {
      _tell('Choose a license review outcome first.');
      return;
    }
    await _run(() => _service.recordCheck(d.id, result, _notes.text), 'License review saved.');
    setState(() {
      _result = null;
      _notes.clear();
    });
  }

  Future<void> _acceptFromDocuments() async {
    await _run(
      () => _service.recordCheck(
        d.id,
        'matched',
        _notes.text.isEmpty ? 'Accepted from uploaded application documents.' : _notes.text,
      ),
      'License accepted from application documents.',
    );
  }

  Future<void> _approve() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve pharmacy?',
      message: 'Are you sure you want to approve this pharmacy?',
      actionLabel: 'Approve',
      cancelLabel: 'Cancel',
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

  Future<void> _reject() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reject application?',
      message: 'Are you sure you want to reject this pharmacy application?',
      actionLabel: 'Reject',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final reason = await showReasonDialog(
      context,
      title: 'Reject application',
      description: 'The owner sees this reason and can fix the details and resubmit.',
      actionLabel: 'Reject application',
      hint: "e.g. The address on your LTO doesn't match the address you entered.",
    );
    if (reason != null) await _run(() => _service.reject(d.id, reason), 'Application rejected.');
  }

  String _docTitle(DocumentInfo doc) => switch (doc.kind) {
        'lto' => 'License to operate (upload)',
        'storefront' => 'Storefront photo',
        _ => 'Renewed LTO',
      };

  String _fileName(DocumentInfo doc) {
    final parts = doc.path.split('/');
    return parts.isNotEmpty ? parts.last : doc.path;
  }

  Widget _licenseSummary() {
    final date = DateFormat('MMM d, yyyy');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailLine('Pharmacy', d.pharmacyName),
          _detailLine('Branch', d.branchName),
          _detailLine('Address', d.address),
          _detailLine('Contact', d.contactNumber),
          _detailLine('Email', d.email),
          if (d.owner != null) _detailLine('Owner', d.owner!.name),
          _detailLine('License no. (claimed)', d.ltoNumber),
          _detailLine('License expires', date.format(d.ltoExpiry)),
        ],
      ),
    );
  }

  Widget _licenseOutcomePicker() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in _licenseOutcomes.entries)
          AppChip(
            label: entry.value,
            selected: _result == entry.key,
            onSelected: _busy
                ? null
                : (selected) => setState(() => _result = selected ? entry.key : null),
          ),
      ],
    );
  }

  Widget _reviewActions() {
    final saveReview = OutlinedButton(
      onPressed: _busy ? null : _recordCheck,
      style: TabletControls.actionOutlined(
        foreground: AppColors.text,
        border: AppColors.border,
        background: Colors.white,
      ),
      child: const Text('Save review'),
    );
    final accept = FilledButton.tonal(
      onPressed: _busy ? null : _acceptFromDocuments,
      style: TabletControls.actionFilled().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
      ),
      child: const Text('Accept from documents'),
    );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              accept,
              const SizedBox(height: AppSpacing.sm),
              saveReview,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: accept),
            const SizedBox(width: AppSpacing.sm),
            saveReview,
          ],
        );
      },
    );
  }

  Widget _decisionFooter({
    required bool canApprove,
    required bool checklistOk,
    required bool licenseExpired,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (licenseExpired)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'License expiry on the application is in the past. Approval stays blocked.',
                style: TextStyle(color: AppColors.danger, fontSize: 12, height: 1.35),
              ),
            ),
          FilledButton(
            onPressed: _busy || !canApprove || !checklistOk || licenseExpired ? null : _approve,
            style: TabletControls.actionFilled(),
            child: const Text('Approve pharmacy'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            style: TabletControls.dangerOutlined(),
            child: const Text('Reject application'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 124,
              child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _beforeApproveChecklist({required bool reviewSaved}) {
    final complete = _checklistComplete(reviewSaved);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Before you approve',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tap each line when done. Compare the upload to the application details above — '
            'no external registry lookup is required.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final step in _licenseChecklist)
            _checklistRow(step: step, reviewSaved: reviewSaved),
          if (!complete)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Complete every item to enable Approve.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checklistRow({required _LicenseChecklistStep step, required bool reviewSaved}) {
    final done = _stepDone(step.id, reviewSaved);
    final autoDone = step.id == 'review_saved';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _tapChecklistStep(step, reviewSaved),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: done,
                  tristate: false,
                  onChanged: autoDone
                      ? null
                      : _busy
                          ? null
                          : (_) => _tapChecklistStep(step, reviewSaved),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: done ? AppColors.text : AppColors.textMuted,
                  ),
                ),
              ),
              if (step.opensLicenseUpload)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs, top: 2),
                  child: Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentRow(DocumentInfo doc) {
    final viewButton = OutlinedButton(
      onPressed: () => widget.onOpenDocument(doc),
      style: TabletControls.actionOutlined(
        foreground: AppColors.text,
        border: AppColors.border,
        background: Colors.white,
      ).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(72, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      child: const Text('View'),
    );

    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_docTitle(doc), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          _fileName(doc),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labels,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: viewButton),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: labels),
              const SizedBox(width: AppSpacing.sm),
              viewButton,
            ],
          );
        },
      ),
    );
  }

  Widget _mapListingBox() {
    final duplicate = d.possibleDuplicate;
    final border = duplicate ? AppColors.warning : AppColors.primary;
    final bg = duplicate ? AppColors.warningLight.withValues(alpha: 0.35) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border.withValues(alpha: duplicate ? 0.5 : 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Owner claimed: ${d.pharmacyName}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${d.address} · Registered branch location',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            duplicate
                ? 'A pharmacy with a similar name is already registered nearby. '
                    'Review before approving.'
                : 'Name and location match. No registered pharmacy owns this pin.',
            style: TextStyle(
              color: duplicate ? AppColors.warning : AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApprove = ref.watch(branchHasMatchProvider(d.id)).value ?? false;
    final checklistOk = _checklistComplete(canApprove);
    final portal = ref.watch(fdaVerificationPortalProvider).asData?.value;
    final submitted = DateFormat('MMM d, yyyy').format(d.submittedAt);
    final licenseExpired = d.ltoExpiry.isBefore(DateUtils.dateOnly(DateTime.now()));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: const Color(0xFFFFF8ED),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pending_actions, size: 22, color: AppColors.warning),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Pending proposal',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Submitted $submitted',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Review uploads against the details below, complete the checklist, then approve or reject.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('DOCUMENTS'),
                    if (d.documents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          'No documents uploaded.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    for (final doc in d.documents) _documentRow(doc),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('APPLICATION DETAILS'),
                    _licenseSummary(),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _copyLto,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy license no.'),
                          style: TabletControls.toolbarOutlined(),
                        ),
                        if (portal != null)
                          OutlinedButton.icon(
                            onPressed: () => _openPortal(portal),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(portal.label),
                            style: TabletControls.toolbarOutlined(),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('LICENSE REVIEW'),
                    _licenseOutcomePicker(),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _notes,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Notes (optional)',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _reviewActions(),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('MAP LISTING'),
                    _mapListingBox(),
                    const SizedBox(height: AppSpacing.lg),
                    _beforeApproveChecklist(reviewSaved: canApprove),
                  ],
                ),
              ),
              _decisionFooter(
                canApprove: canApprove,
                checklistOk: checklistOk,
                licenseExpired: licenseExpired,
              ),
            ],
          ),
        ),
      ),
    );
  }
}