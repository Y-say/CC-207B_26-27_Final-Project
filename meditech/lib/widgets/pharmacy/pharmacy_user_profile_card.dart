import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/pharmacy_staff_providers.dart';
import '../common/profile_photo_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class PharmacySettingsSectionCard extends StatelessWidget {
  const PharmacySettingsSectionCard({
    super.key,
    this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E22),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
                color: const Color(0xFF1A2E22),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }
}

class PharmacyUserProfileCard extends StatelessWidget {
  const PharmacyUserProfileCard({
    super.key,
    required this.profile,
    required this.onChangePassword,
    this.onPhotoTap,
    this.photoUrl,
  });

  final PharmacyStaffProfile profile;
  final VoidCallback onChangePassword;
  final Future<void> Function()? onPhotoTap;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final signIn = profile.username?.isNotEmpty == true
        ? profile.username!
        : (profile.email ?? '—');
    final displayPhotoUrl = photoUrl ?? profile.avatarPublicUrl;

    return PharmacySettingsSectionCard(
      title: 'Your profile',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfilePhotoAvatar(
              displayName: profile.fullName,
              photoUrl: displayPhotoUrl,
              radius: 36,
              onTap: onPhotoTap == null ? null : () => onPhotoTap!(),
              showCameraBadge: onPhotoTap != null,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      profile.roleLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap your photo on Profile to change it.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PharmacyProfileInfoRow(
          label: 'Employee ID',
          value: profile.employeeId.isNotEmpty ? profile.employeeId : '—',
        ),
        const SizedBox(height: AppSpacing.sm),
        PharmacyProfileInfoRow(label: 'Sign-in username', value: signIn),
        if (profile.email != null && profile.email!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          PharmacyProfileInfoRow(label: 'Email', value: profile.email!),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onChangePassword,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Change password'),
        ),
      ],
    );
  }
}

class PharmacyProfileInfoRow extends StatelessWidget {
  const PharmacyProfileInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}