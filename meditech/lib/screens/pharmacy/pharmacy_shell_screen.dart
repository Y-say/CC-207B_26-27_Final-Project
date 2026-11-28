import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/lto_renewal_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/pharmacy_staff_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/tablet/pharmacy_frame.dart';
import '../../widgets/tablet/tablet_dialogs.dart';

/// Persistent tablet chrome: sidebar, header, and [child] from [ShellRoute].
class PharmacyShellScreen extends ConsumerStatefulWidget {
  const PharmacyShellScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<PharmacyShellScreen> createState() =>
      _PharmacyShellScreenState();
}

class _PharmacyShellScreenState extends ConsumerState<PharmacyShellScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        restoreSessionIfNeeded(
          currentSession: ref.read(sessionProvider),
          setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
        );
      }
    });
  }

  static String navigationIdFor(String matchedLocation) {
    if (matchedLocation.startsWith('/reservations')) return 'reservations';
    if (matchedLocation.startsWith('/inventory')) return 'inventory';
    if (matchedLocation.startsWith('/stock-alerts')) return 'stock_alerts';
    if (matchedLocation.startsWith('/employees')) return 'employees';
    if (matchedLocation.startsWith('/notifications')) return 'notifications';
    if (matchedLocation.startsWith('/profile')) return 'profile';
    if (matchedLocation.startsWith('/settings')) return 'settings';
    return 'dashboard';
  }

  void _go(BuildContext context, String id) {
    final path = switch (id) {
      'dashboard' => '/dashboard',
      'reservations' => '/reservations',
      'inventory' => '/inventory',
      'stock_alerts' => '/stock-alerts',
      'employees' => '/employees',
      _ => '/dashboard',
    };

    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final account = ref.watch(sessionProvider);
    final role = account?.role ?? 'staff';
    final location = GoRouterState.of(context).matchedLocation;
    final selected = navigationIdFor(location);
    final branch = ref.watch(ownBranchProvider).value;
    final branchTitle = branch == null
        ? 'Pharmacy branch'
        : '${branch.pharmacyName} • ${branch.branchName}';
    final branchMeta = branch == null
        ? null
        : '${branch.displayId} • ${branch.branchName}';

    final staffProfile = ref.watch(pharmacyStaffProfileProvider).value;
    final displayName = staffProfile?.displayName ??
        (role == 'owner' ? 'Branch Owner' : 'Staff Member');
    final userRole = staffProfile?.roleLabel ??
        switch (role) {
          'owner' => 'Owner',
          'pharmacist' => 'Pharmacist',
          _ => 'Staff',
        };
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final pendingCount = ref.watch(pharmacyPendingReservationsCountProvider);
    final stockAlertCount = ref.watch(pharmacyStockAlertsCountProvider);

    return PharmacyFrame(
      branchName: branchTitle,
      branchMeta: branchMeta,
      userName: displayName,
      userRole: userRole,
      userPhotoUrl: ref.watch(staffHeaderPhotoUrlProvider),
      unreadNotifications: unreadNotifications,
      pendingReservationsCount: pendingCount,
      stockAlertsCount: stockAlertCount,
      selectedNavigationId: selected,
      onNavigationSelected: (id) => _go(context, id),
      onNotificationsTap: () => context.go('/notifications'),
      onProfileTap: () => context.go('/profile'),
      onSettingsTap: () => context.go('/settings'),
      onLogoutTap: () async {
        final confirmed = await showTabletConfirmDialog(
          context: context,
          title: 'Log out?',
          message: 'Are you sure you want to log out of this branch?',
          cancelLabel: 'Cancel',
          confirmLabel: 'Log out',
          isDanger: true,
        );
        if (confirmed != true) return;
        await ref.read(sessionProvider.notifier).signOut();
        if (context.mounted) context.go('/');
      },
      body: widget.child,
    );
  }
}