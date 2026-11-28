import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/catalogue_medicine.dart';
import '../../../models/drug_registration.dart';
import '../../../providers/catalogue_providers.dart';
import '../../../providers/official_link_providers.dart';
import '../../../services/catalogue_service.dart';
import '../../../utils/pick_profile_image.dart';
import '../../../utils/public_media_urls.dart';
import '../../../utils/validators.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'catalogue_screen.dart';
import 'medicine_activated_modal.dart';

// Product FDA check results and how they look
const _results = <String, (String, BadgeTone)>{
  'matched': ('Matched and valid', BadgeTone.success),
  'not_found': ('Not found', BadgeTone.danger),
  'details_mismatch': ("Details don't match", BadgeTone.danger),
  'expired': ('Expired', BadgeTone.danger),
  'unreadable': ("Couldn't check", BadgeTone.neutral),
};

// Right-side panel to add or edit a medicine, check it, and activate it
class MedicineDrawer extends ConsumerStatefulWidget {
  const MedicineDrawer({super.key, this.medicine, required this.onClose});

  final CatalogueMedicine? medicine; // null when adding
  final VoidCallback onClose;

  @override
  ConsumerState<MedicineDrawer> createState() => _MedicineDrawerState();
}

class _MedicineDrawerState extends ConsumerState<MedicineDrawer> {
  final _form = GlobalKey<FormState>();
  final _regNumber = TextEditingController();
  final _generic = TextEditingController();
  final _brand = TextEditingController();
  final _strength = TextEditingController();
  final _manufacturer = TextEditingController();
  final _pack = TextEditingController();
  final _notes = TextEditingController();
  int? _formId;
  int? _unitId;
  bool _isRx = false;
  String? _result;
  bool _busy = false;
  bool _filled = false;
  String? _imagePath;
  Uint8List? _pendingImageBytes;
  String? _pendingImageFileName;
  int _imageVersion = 0;

  CatalogueMedicine? get m => widget.medicine;
  CatalogueService get _service => ref.read(catalogueServiceProvider);

  @override
  void initState() {
    super.initState();
    // Start from what the table already knows
    if (m != null) {
      _regNumber.text = m!.registrationNumber ?? '';
      _generic.text = m!.genericName;
      _brand.text = m!.brandName;
      _strength.text = m!.strength;
      _pack.text = m!.packDescription ?? '';
      _isRx = m!.isRx;
      _imagePath = m!.imagePath;
    }
  }

  @override
  void didUpdateWidget(covariant MedicineDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medicine?.id != widget.medicine?.id) {
      _filled = false;
      _pendingImageBytes = null;
      _pendingImageFileName = null;
    }
  }

  String _mimeFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickPackImage() async {
    final picked = await pickProfileImageBytes(context);
    if (picked == null || !mounted) return;
    setState(() {
      _pendingImageBytes = picked.bytes;
      _pendingImageFileName = picked.fileName;
      _imageVersion++;
    });
  }

  @override
  void dispose() {
    for (final c in [_regNumber, _generic, _brand, _strength, _manufacturer, _pack, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // Fill in the registration's own details once loaded
  void _fillFrom(DrugRegistration r) {
    if (_filled) return;
    _filled = true;
    _regNumber.text = r.registrationNumber;
    _generic.text = r.genericName;
    _brand.text = m?.brandName ?? r.brandName ?? '';
    _strength.text = r.strength;
    _manufacturer.text = r.manufacturer ?? '';
    _formId = r.dosageFormId;
    _isRx = r.isRx;
  }

  // Reload everything that may have changed
  void _refresh(String? registrationId) {
    ref.invalidate(catalogueListProvider);
    if (registrationId != null) {
      ref.invalidate(registrationProvider(registrationId));
      ref.invalidate(registrationChecksProvider(registrationId));
      ref.invalidate(registrationMatchProvider(registrationId));
    }
  }

  // Run an action with a spinner and a friendly error
  Future<bool> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      _tell(success);
      return true;
    } catch (e) {
      _tell(CatalogueService.friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Save the registration, then the catalogue entry
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    String? regId = m?.registrationId;
    String? medId = m?.id;
    final pendingImage = _pendingImageBytes;
    final pendingImageName = _pendingImageFileName;

    final ok = await _run(() async {
      regId ??= await _service.registrationIdByNumber(_regNumber.text);
      regId = await _service.saveRegistration({
        'id': regId,
        'registration_number': _regNumber.text.trim(),
        'generic_name': _generic.text,
        'brand_name': _brand.text,
        'strength': _strength.text,
        'dosage_form_id': _formId,
        'manufacturer': _manufacturer.text,
        'is_rx': _isRx,
      });
      medId = await _service.saveMedicine({
        'id': medId,
        'registration_id': regId,
        'brand_name': _brand.text,
        'unit_sold_id': _unitId,
        'pack_description': _pack.text,
        if (_imagePath != null && pendingImage == null) 'image_path': _imagePath,
      });
    }, 'Medicine saved.');

    if (!ok || medId == null) return;
    final savedMedId = medId!;

    if (pendingImage != null) {
      try {
        final path = await _service.uploadMedicineImage(
          medicineId: savedMedId,
          bytes: pendingImage,
          mimeType: _mimeFromFileName(pendingImageName ?? 'upload.jpg'),
        );
        await _service.saveMedicine({
          'id': savedMedId,
          'registration_id': regId,
          'brand_name': _brand.text,
          'unit_sold_id': _unitId,
          'pack_description': _pack.text,
          'image_path': path,
        });
        if (mounted) {
          setState(() {
            _imagePath = path;
            _pendingImageBytes = null;
            _pendingImageFileName = null;
            _imageVersion++;
          });
        }
      } catch (e) {
        if (mounted) {
          _tell('Medicine saved, but pack image failed: ${CatalogueService.friendlyError(e)}');
        }
      }
    }

    if (mounted) setState(() {});
    _refresh(regId);
    ref.read(selectedMedicineProvider.notifier).select(savedMedId);
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

  // Save a product check
  Future<void> _record(String registrationId) async {
    final result = _result;
    if (result == null) {
      _tell('Choose a result first.');
      return;
    }
    final ok = await _run(() => _service.recordCheck(registrationId, result, _notes.text), 'FDA check recorded.');
    if (ok) {
      setState(() {
        _result = null;
        _notes.clear();
      });
      _refresh(registrationId);
    }
  }

  // Make it live for pharmacies and customers
  Future<void> _activate() async {
    final medicine = m!;
    final wasDraft = medicine.status == 'draft';
    final brandName = medicine.brandName;
    final regId = medicine.registrationId;

    setState(() => _busy = true);
    try {
      await _service.setStatus(medicine.id, 'active');
      _refresh(regId);
      if (!mounted) return;
      await showMedicineActivatedModal(
        context,
        brandName: brandName,
        firstApproval: wasDraft,
      );
    } catch (e) {
      _tell(CatalogueService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Take it down, with a reason
  Future<void> _deactivate() async {
    final stocking = m!.pharmaciesStocking;
    final reason = await showReasonDialog(
      context,
      title: 'Deactivate ${m!.brandName}?',
      description: stocking == 0
          ? 'It disappears from search and the pharmacy catalogue picker.'
          : '$stocking ${stocking == 1 ? 'pharmacy stocks' : 'pharmacies stock'} it. '
              'It disappears from search and customers can no longer reserve it.',
      actionLabel: 'Deactivate',
      hint: 'e.g. Registration expired or product recalled.',
    );
    if (reason == null) return;
    final ok = await _run(() => _service.setStatus(m!.id, 'inactive', reason), 'Medicine deactivated.');
    if (ok) _refresh(m!.registrationId);
  }

  @override
  Widget build(BuildContext context) {
    final forms = ref.watch(dosageFormsProvider).value ?? const <LookupItem>[];
    final units = ref.watch(unitsProvider).value ?? const <LookupItem>[];
    final regId = m?.registrationId;

    // Load the registration's details when editing
    if (regId != null) {
      final reg = ref.watch(registrationProvider(regId)).value;
      if (reg != null) _fillFrom(reg);
    }

    // Match the table's form and unit names to the drop-down items
    _formId ??= forms.where((f) => f.name == m?.dosageForm).firstOrNull?.id;
    _unitId ??= units.where((u) => u.name == m?.unitSold).firstOrNull?.id;

    final details = _detailsTab(forms, units);

    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: const Border(left: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: DefaultTabController(
        length: 2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),

          // New medicines only have details; the FDA check comes after the first save
          if (m == null) ...[
            const Divider(),
            Expanded(child: details),
          ] else ...[
            const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: [Tab(text: 'Details'), Tab(text: 'FDA check & status')],
            ),
            Expanded(
              child: TabBarView(children: [
                details,
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: regId != null
                      ? _checkSection(regId)
                      : const _Note(
                          icon: Icons.info_outline,
                          text: 'This medicine has no FDA registration yet. Fill in the registration '
                              'number on the Details tab and save to enable FDA checks.',
                        ),
                ),
              ]),
            ),
          ],
        ]),
        ),
      ),
    );
  }

  // Icon, name, ID, status, and close
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.md),
      child: Row(children: [
        _PackImageThumb(
          imagePath: _imagePath,
          pendingBytes: _pendingImageBytes,
          version: _imageVersion,
          placeholder: m == null ? Icons.add : Icons.medication_outlined,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m == null ? 'Add medicine' : m!.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(m == null ? 'New catalogue entry' : m!.displayId,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
        if (m != null) ...[medicineStatusBadge(m!.status), const SizedBox(width: AppSpacing.xs)],
        IconButton(tooltip: 'Close', onPressed: widget.onClose, icon: const Icon(Icons.close)),
      ]),
    );
  }

  // Registration, medicine, classification, and catalogue fields, with Cancel and Save below
  Widget _detailsTab(List<LookupItem> forms, List<LookupItem> units) {
    const gap = SizedBox(height: AppSpacing.md);
    const sectionGap = SizedBox(height: AppSpacing.xl);

    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          // A plain scroll view so every field is built and checked on save
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _SectionHeader(Icons.description_outlined, 'FDA registration'),
              AppTextField(label: 'Registration number', controller: _regNumber,
                  hint: 'As shown on the verification site', validator: (v) => Validators.required(v)),
              sectionGap,

              const _SectionHeader(Icons.medication_outlined, 'Medicine information'),
              AppTextField(label: 'Generic name', controller: _generic,
                  validator: (v) => Validators.required(v)),
              gap,
              AppTextField(label: 'Brand name (optional)', controller: _brand),
              gap,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: AppTextField(label: 'Strength', controller: _strength,
                      hint: 'e.g. 500 mg', validator: (v) => Validators.required(v)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Labeled(
                    'Dosage form',
                    DropdownButtonFormField<int>(
                      initialValue: _formId,
                      isExpanded: true,
                      hint: const Text('Choose'),
                      items: [for (final f in forms) DropdownMenuItem(value: f.id, child: Text(f.name))],
                      onChanged: (v) => setState(() => _formId = v),
                      validator: (v) => v == null ? 'Required.' : null,
                    ),
                  ),
                ),
              ]),
              gap,
              AppTextField(label: 'Manufacturer (optional)', controller: _manufacturer,
                  hint: 'Enter manufacturer name'),
              sectionGap,

              const _SectionHeader(Icons.verified_user_outlined, 'Classification'),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: SwitchListTile(
                  title: const Text('Prescription medicine (Rx)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Shown as ${medicineClassification(_isRx)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  value: _isRx,
                  onChanged: (v) => setState(() => _isRx = v),
                ),
              ),
              sectionGap,

              const _SectionHeader(Icons.inventory_2_outlined, 'Catalogue entry'),
              _Labeled(
                'Sold per',
                DropdownButtonFormField<int>(
                  initialValue: _unitId,
                  isExpanded: true,
                  hint: const Text('Choose a unit'),
                  items: [for (final u in units) DropdownMenuItem(value: u.id, child: Text(u.name))],
                  onChanged: (v) => setState(() => _unitId = v),
                  validator: (v) => v == null ? 'Required.' : null,
                ),
              ),
              gap,
              AppTextField(label: 'Pack description (optional)', controller: _pack, hint: 'e.g. Box of 100'),
              sectionGap,
              const _SectionHeader(Icons.image_outlined, 'Pack image'),
              const Text(
                'Shown to customers in search and on pharmacy inventories (JPEG, PNG, or WebP).',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PackImageThumb(
                    imagePath: _imagePath,
                    pendingBytes: _pendingImageBytes,
                    version: _imageVersion,
                    size: 72,
                    placeholder: Icons.medication_outlined,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickPackImage,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(_pendingImageBytes != null || _imagePath != null ? 'Replace photo' : 'Upload photo'),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),

        // Always-visible actions
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : widget.onClose,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(m == null ? 'Add to catalogue' : 'Save changes'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // Copy, open portal, record result, history, then approve / deactivate
  Widget _checkSection(String registrationId) {
    final checks = ref.watch(registrationChecksProvider(registrationId));
    final matched = ref.watch(registrationMatchProvider(registrationId)).value ?? false;
    final date = DateFormat('MMM d, yyyy · h:mm a');
    final portal = ref.watch(fdaVerificationPortalProvider).asData?.value;
    final siteName = portal?.label ?? 'the official verification site';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(Icons.fact_check_outlined, 'Product FDA check'),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          'Look up the registration number on $siteName, then record what you found.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _regNumber.text));
            _tell('Registration number copied.');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy registration number'),
        ),
        if (portal != null)
          OutlinedButton.icon(
            onPressed: _openPortal,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(portal.label),
          ),
      ]),
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
        decoration: const InputDecoration(hintText: 'Notes (optional)'),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _busy ? null : () => _record(registrationId),
          child: const Text('Save check'),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      // History of checks
      const _SectionHeader(Icons.history, 'Check history'),
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
                        child: Text(
                          'Manually checked against FDA records on ${date.format(c.checkedAt)} '
                          '· ${c.checkedByLabel}${c.notes != null ? '\n${c.notes}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
              ]),
      ),
      const SizedBox(height: AppSpacing.xl),

      // Approve (pending review), reactivate (inactive), or deactivate (active)
      const _SectionHeader(Icons.toggle_on_outlined, 'Catalogue status'),
      if (m!.status != 'active') ...[
        if (!matched)
          const _Note(
            icon: Icons.lock_outline,
            text: 'Unlocks after a "Matched and valid" FDA check on the current details.',
          ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy || !matched ? null : _activate,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(m!.status == 'draft' ? 'Approve and activate' : 'Reactivate'),
          ),
        ),
      ] else
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _deactivate,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: const Text('Deactivate'),
          ),
        ),
    ]);
  }
}

class _PackImageThumb extends StatelessWidget {
  const _PackImageThumb({
    required this.imagePath,
    required this.pendingBytes,
    required this.version,
    required this.placeholder,
    this.size = 48,
  });

  final String? imagePath;
  final Uint8List? pendingBytes;
  final int version;
  final IconData placeholder;
  final double size;

  @override
  Widget build(BuildContext context) {
  final url = pendingBytes == null
        ? medicineImagePublicUrl(imagePath, cacheBust: version)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: pendingBytes != null
            ? Image.memory(pendingBytes!, fit: BoxFit.cover, width: size, height: size)
            : url != null
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => Icon(placeholder, color: AppColors.primary),
                  )
                : Icon(placeholder, color: AppColors.primary),
      ),
    );
  }
}

// A section title with a green icon
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
      );
}

// A label above a drop-down, matching AppTextField
class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.field);

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        field,
      ]);
}

// A tinted note with an icon
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
        ]),
      );
}