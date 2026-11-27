import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/pharmacy_staff_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../utils/pick_profile_image.dart';
import '../../../utils/staff_avatar_refresh.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/network_avatar_image.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

/// Profile for every pharmacy user: photo, name, and password.
class PharmacyProfileScreen extends ConsumerStatefulWidget {
  const PharmacyProfileScreen({super.key});

  @override
  ConsumerState<PharmacyProfileScreen> createState() =>
      _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends ConsumerState<PharmacyProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final picked = await pickProfileImageBytes(context);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final path = await ref.read(staffAvatarServiceProvider).uploadOwn(
            fileName: picked.fileName,
            bytes: picked.bytes,
          );
      await applyStaffAvatarRefresh(ref, storedPath: path);
      if (!mounted) return;
      await showTabletMessageDialog(
        context: context,
        title: 'Profile photo updated',
        bullets: const [
          'Your photo appears in the app header.',
          'PRC license is read-only on Profile—owners edit it under Employees.',
        ],
        isWarning: false,
        buttonLabel: 'Done',
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _edit() async {
    final changed = await context.push<bool>('/profile/edit');
    if (changed == true) {
      ref.invalidate(pharmacyStaffProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(pharmacyStaffProfileProvider);
    final photoUrl = ref.watch(staffHeaderPhotoUrlProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncView<PharmacyStaffProfile?>(
        value: profileAsync,
        isEmpty: (profile) => profile == null,
        emptyMessage: 'We could not load your profile.',
        onRetry: () => ref.invalidate(pharmacyStaffProfileProvider),
        builder: (profile) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.normal,
                        color: const Color(0xFF1A2E22),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your name and photo are shown in the header. '
                      'Edit profile opens a full page to change name, username, and Gmail.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_uploading) const LinearProgressIndicator(),
                    if (_uploading) const SizedBox(height: AppSpacing.md),
                    Center(
                      child: _PhotoButton(
                        name: profile!.fullName,
                        photoUrl: photoUrl,
                        onTap: _uploading ? null : _changePhoto,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Center(
                      child: Text(
                        'Tap your photo to change it',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _InfoCard(profile: profile),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _edit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Edit profile'),
                    ),
                    if (profile.showsPrcLicenseSection) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _PrcLicenseCard(profile: profile),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/change-password'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: () async {
                        await ref.read(sessionProvider.notifier).signOut();
                        if (context.mounted) context.go('/');
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFFFFE8E8),
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Log out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.name,
    required this.photoUrl,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.primary,
            child: photoUrl != null
                ? NetworkAvatarImage(
                    url: photoUrl!,
                    radius: 52,
                    backgroundColor: AppColors.primary,
                    fallback: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});

  final PharmacyStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final username = profile.username?.isNotEmpty == true
        ? profile.username!
        : '—';
    final contactEmail = profile.contactEmail;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(icon: Icons.person_outline, label: 'Full Name', value: profile.fullName),
          const Divider(height: 1),
          _Row(icon: Icons.badge_outlined, label: 'Role', value: profile.roleLabel),
          const Divider(height: 1),
          _Row(icon: Icons.alternate_email, label: 'Username', value: username),
          const Divider(height: 1),
          _Row(
            icon: Icons.mail_outline,
            label: 'Email',
            value: contactEmail ?? 'Not on file',
          ),
          const Divider(height: 1),
          _Row(
            icon: Icons.tag,
            label: 'Employee ID',
            value: profile.employeeId.isNotEmpty ? profile.employeeId : '—',
          ),
        ],
      ),
    );
  }
}

class _PrcLicenseCard extends StatelessWidget {
  const _PrcLicenseCard({required this.profile});

  final PharmacyStaffProfile profile;

  @override
  Widget build(BuildContext context) {
    final expiry = profile.prcLicenseExpiry;
    final expiryText = expiry == null
        ? '—'
        : '${expiry.month.toString().padLeft(2, '0')}/'
            '${expiry.day.toString().padLeft(2, '0')}/'
            '${expiry.year}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'PRC license (personal)',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Read-only on Profile. The branch owner adds or verifies licenses under Employees.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const Divider(height: 1),
          _Row(
            icon: Icons.numbers,
            label: 'License number',
            value: profile.prcLicenseNo ?? 'Not on file',
          ),
          const Divider(height: 1),
          _Row(icon: Icons.event_outlined, label: 'Expiry', value: expiryText),
          const Divider(height: 1),
          _Row(
            icon: Icons.verified_outlined,
            label: 'Status',
            value: profile.licenseStatusLabel,
          ),
          if (profile.role == 'pharmacist' &&
              profile.licenseStatus == 'pending') ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pending owner verification under Employees.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
          if (profile.role == 'owner') ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Employees → your row → Update my license.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
