import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/branch_settings.dart';
import '../../../providers/branch_settings_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../utils/friendly_error.dart';
import '../../../utils/pick_profile_image.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/pharmacy_storefront_hero.dart';
import '../../../widgets/pharmacy/lto_renewal_guidance.dart';
import '../../../widgets/pharmacy/pharmacy_user_profile_card.dart' show PharmacySettingsSectionCard;
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Branch Settings screen (Ph-36)
// Branch-level details and FDA LTO (read-only). PRC licenses live under Profile.
class BranchSettingsScreen extends ConsumerStatefulWidget {
  const BranchSettingsScreen({super.key});

  @override
  ConsumerState<BranchSettingsScreen> createState() =>
      _BranchSettingsScreenState();
}

class _BranchSettingsScreenState extends ConsumerState<BranchSettingsScreen> {
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _hoursController = TextEditingController();

  bool _isSaving = false;
  bool _storefrontUploading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    _contactController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _populate(BranchSettings settings) {
    if (_initialized) return;
    _addressController.text = settings.address;
    _contactController.text = settings.contactNumber;
    _hoursController.text = settings.operatingHours;
    _initialized = true;
  }

  String _mimeFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _uploadStorefront() async {
    final picked = await pickProfileImageBytes(context);
    if (picked == null || !mounted) return;

    setState(() => _storefrontUploading = true);
    try {
      await ref.read(branchStorefrontServiceProvider).uploadStorefront(
            fileName: picked.fileName,
            bytes: picked.bytes,
            mimeType: _mimeFromFileName(picked.fileName),
          );
      ref.invalidate(branchSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pharmacy picture updated. Customers will see it on maps and your branch page.',
          ),
        ),
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _storefrontUploading = false);
    }
  }

  Future<void> _save(BranchSettings settings) async {
    setState(() => _isSaving = true);
    try {
      final service = ref.read(branchSettingsServiceProvider);
      final isOwner = ref.read(sessionProvider)?.role == 'owner';
      await service.updateSettings(
        branchId: settings.branchId,
        address: _addressController.text.trim(),
        contactNumber: _contactController.text.trim(),
        operatingHours: _hoursController.text.trim(),
        updateBranchDetails: isOwner,
      );

      ref.invalidate(branchSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      await showFriendlyErrorDialog(context, e, action: 'save settings');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _ltoSummary(BranchSettings settings) {
    final lto = settings.fdaLto;
    final expiry = settings.fdaLtoExpiry;
    final verified = 'verified by the Administrator';
    if (expiry == null) return 'FDA License to Operate: $lto · $verified';
    final expiryLabel =
        '${expiry.month.toString().padLeft(2, '0')}/'
        '${expiry.day.toString().padLeft(2, '0')}/'
        '${expiry.year}';
    return 'FDA License to Operate: $lto · expires $expiryLabel · $verified';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _ltoExpired(DateTime? expiry) {
    if (expiry == null) return false;
    return !_dateOnly(expiry).isAfter(_dateOnly(DateTime.now()));
  }

  static bool _ltoNeedsAttention(DateTime? expiry) {
    if (expiry == null) return false;
    final expDay = _dateOnly(expiry);
    final day = _dateOnly(DateTime.now());
    if (!expDay.isAfter(day)) return true;
    return expDay.difference(day).inDays <= 60;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(branchSettingsProvider);
    final account = ref.watch(sessionProvider);
    final isOwner = account?.role == 'owner';
    final isPharmacist = account?.role == 'pharmacist';
    final canChangePharmacyPicture = isOwner || isPharmacist;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncView<BranchSettings>(
        value: settingsAsync,
        onRetry: () {
          _initialized = false;
          ref.invalidate(branchSettingsProvider);
        },
        builder: (settings) {
          _populate(settings);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Title (matching wireframe: "Branch settings", no white box)
                    Text(
                      'Branch settings',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.normal,
                        color: const Color(0xFF1A2E22),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main Branch Details Card (matching wireframe layout)
                    PharmacySettingsSectionCard(
                      children: [
                        _buildPharmacyPictureSection(
                          settings: settings,
                          canChange: canChangePharmacyPicture,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildReadOnlyField(
                                label: 'Pharmacy name',
                                value: settings.pharmacyName,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildReadOnlyField(
                                label: 'Branch name',
                                value: settings.branchName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildEditableField(
                          label: 'Address',
                          controller: _addressController,
                          enabled: isOwner,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditableField(
                                label: 'Contact number',
                                controller: _contactController,
                                enabled: isOwner,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildEditableField(
                                label: 'Operating hours',
                                controller: _hoursController,
                                enabled: isOwner,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Map pin area matching wireframe
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EFEA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD8E8DE),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: Color(0xFF4B5563),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Map pin used for patient directions (drag to adjust)',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // FDA LTO (branch permit — not individual PRC)
                        Text(
                          _ltoSummary(settings),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        if (isOwner && _ltoNeedsAttention(settings.fdaLtoExpiry)) ...[
                          const SizedBox(height: 12),
                          LtoRenewalPrepPanel.branchSettings(
                            ltoExpired: _ltoExpired(settings.fdaLtoExpiry),
                          ),
                        ],
                        if (isOwner) ...[
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving ? null : () => _save(settings),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E6B46),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Save changes',
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPharmacyPictureSection({
    required BranchSettings settings,
    required bool canChange,
  }) {
    final hasPhoto = settings.storefrontPath != null &&
        settings.storefrontPath!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pharmacy picture',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A2E22),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Storefront photo shown to patients on maps, search, and your branch page.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 160,
                height: 120,
                child: hasPhoto
                    ? PharmacyStorefrontHero(
                        storefrontPath: settings.storefrontPath,
                        height: 120,
                      )
                    : Container(
                        color: const Color(0xFFE9EFEA),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canChange) ...[
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed:
                            _storefrontUploading ? null : _uploadStorefront,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E6B46),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _storefrontUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          hasPhoto ? 'Change pharmacy picture' : 'Upload pharmacy picture',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'JPEG, PNG, or WebP · up to 5 MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ] else
                    const Text(
                      'Only the branch owner or a licensed pharmacist on duty '
                      'can change the pharmacy picture.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: const Color(0xFF1A2E22),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD8E8DE),
              width: 1.2,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: const Color(0xFF1A2E22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: const Color(0xFF1A2E22),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            enabled: enabled,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: const Color(0xFF1A2E22),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                color: const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD8E8DE),
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD8E8DE),
                  width: 1.2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD8E8DE),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF2E6B46),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
