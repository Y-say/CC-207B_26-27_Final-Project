import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/customer_profile_overview.dart';
import '../../../providers/cart_providers.dart';
import '../../../providers/customer_nav_provider.dart';
import '../../../providers/notification_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/reservation_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../utils/relative_time.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/guest_auth_gate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final overview = ref.watch(customerProfileOverviewProvider);

    Widget body;
    if (session == null) {
      body = _GuestProfileBody(
        onSignIn: () => showGuestAuthGate(
          context,
          title: 'Sign in to view your profile',
          message: 'Your name, saved addresses, and preferences are tied to your account.',
        ),
      );
    } else {
      body = AsyncView<CustomerProfileOverview?>(
        value: overview,
        isEmpty: (data) => data == null,
        emptyMessage: 'We could not load your profile.',
        onRetry: () => ref.invalidate(customerProfileOverviewProvider),
        builder: (data) => _SignedInProfileBody(
          overview: data!,
          onAvatarTap: () => _pickAvatar(context, ref),
          onEdit: () async {
            final changed = await context.push<bool>(
              '/profile/edit',
              extra: data.profile,
            );
            if (changed == true) {
              ref.invalidate(customerProfileOverviewProvider);
              ref.invalidate(customerProfileProvider);
            }
          },
          onSavedAddresses: () async {
            await context.push('/profile/addresses');
            ref.invalidate(customerProfileOverviewProvider);
          },
          onNotificationPrefs: () async {
            await context.push('/profile/notification-preferences');
            ref.invalidate(customerProfileOverviewProvider);
          },
          onChangePassword: () async {
            await context.push('/profile/change-password');
            ref.invalidate(customerProfileOverviewProvider);
          },
          onLogout: () => _logout(context, ref),
        ),
      );
    }

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const CustomerLocationAppBarTitle(heading: 'Profile'),
      ),
      body: body,
    );
  }

  static Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty || !context.mounted) return;
    final file = picked.single;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    try {
      await ref.read(profileServiceProvider).uploadAvatar(
            fileName: file.name,
            bytes: bytes,
          );
      ref.invalidate(customerProfileOverviewProvider);
    } on AppFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  static Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to reserve medicines.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(sessionProvider.notifier).signOut();
    if (!context.mounted) return;
    // Reset to home tab so the next sign-in always starts there
    ref.read(customerTabProvider.notifier).select(0);
    context.go('/');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(cartProvider);
      ref.invalidate(myReservationsProvider);
      ref.invalidate(notificationListProvider);
    });
  }
}

class _GuestProfileBody extends StatelessWidget {
  const _GuestProfileBody({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.person_outline, size: 72, color: AppColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Sign in to see your profile',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Save addresses, manage notifications, and keep your details up to date.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: onSignIn,
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

class _SignedInProfileBody extends StatelessWidget {
  const _SignedInProfileBody({
    required this.overview,
    required this.onAvatarTap,
    required this.onEdit,
    required this.onSavedAddresses,
    required this.onNotificationPrefs,
    required this.onChangePassword,
    required this.onLogout,
  });

  final CustomerProfileOverview overview;
  final VoidCallback onAvatarTap;
  final VoidCallback onEdit;
  final VoidCallback onSavedAddresses;
  final VoidCallback onNotificationPrefs;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final profile = overview.profile;
    final addressLabel = overview.savedAddressCount == 1
        ? '1 saved address'
        : '${overview.savedAddressCount} saved addresses';

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 120),
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(child: _Avatar(photoUrl: overview.avatarPublicUrl, onTap: onAvatarTap)),
        const SizedBox(height: AppSpacing.xl),
        _InfoCard(
          rows: [
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: profile.fullName,
            ),
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'Email',
              value: profile.email,
            ),
            _InfoRow(
              icon: Icons.smartphone_outlined,
              label: 'Mobile Number',
              value: profile.displayMobile,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onEdit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Edit Profile'),
        ),
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
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              subtitle: addressLabel,
              onTap: onSavedAddresses,
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notification Preferences',
              subtitle: overview.notificationPreferences.summary,
              onTap: onNotificationPrefs,
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: relativeTimeAgo(overview.passwordLastUpdatedAt),
              onTap: onChangePassword,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: onLogout,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFFFFE8E8),
            foregroundColor: AppColors.danger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text(
            'Log out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.onTap});

  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Icon(Icons.person, size: 48, color: AppColors.primary.withValues(alpha: 0.7))
                : null,
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(children: rows),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}