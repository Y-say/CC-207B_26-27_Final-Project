import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/branch_reservation_providers.dart';
import '../../providers/pharmacy_staff_providers.dart';
import '../../providers/session_providers.dart';
import 'dashboard/pharmacy_dashboard_screen.dart';

/// Dashboard tab inside the pharmacy shell (navigation via [GoRouter]).
class PharmacyDashboardRoute extends ConsumerWidget {
  const PharmacyDashboardRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider)?.role ?? 'staff';
    final roleLabel = switch (role) {
      'owner' => 'Owner',
      'pharmacist' => 'Pharmacist',
      _ => 'Staff',
    };
    final profile = ref.watch(pharmacyStaffProfileProvider).value;
    final displayName = profile?.displayName?.trim();

    return PharmacyDashboardScreen(
      staffRoleLabel: roleLabel,
      staffDisplayName: displayName != null && displayName.isNotEmpty ? displayName : null,
      onGoToInventory: () => context.go('/inventory'),
      onOpenReservations: () => context.go('/reservations'),
      onPendingReservationTap: (reservationId) {
        ref.read(selectedReservationIdProvider.notifier).select(reservationId);
        context.go('/reservations?open=$reservationId');
      },
    );
  }
}