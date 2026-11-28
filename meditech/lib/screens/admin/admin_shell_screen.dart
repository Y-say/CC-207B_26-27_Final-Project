import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/admin_pharmacy_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/tablet/admin_frame.dart';
import '../../providers/audit_providers.dart';
import 'audit/audit_drawer.dart';
import 'audit/audit_list_screen.dart';
import '../../providers/catalogue_providers.dart';
import 'catalogue/catalogue_medicine_shell_drawer.dart';
import 'catalogue/catalogue_screen.dart';
import 'overview/admin_overview_screen.dart';
import 'pharmacies/application_drawer.dart';
import 'pharmacies/pharmacies_screen.dart';
import 'requests/medicine_requests_screen.dart';

// Approved admins land in the tablet shell instead of the sign-in page
class AdminShellScreen extends ConsumerWidget {
  const AdminShellScreen({super.key, required this.section});

  final String section;

  void _clearDrawerSelections(WidgetRef ref, String leaving) {
    switch (leaving) {
      case 'catalogue':
        ref.read(selectedMedicineProvider.notifier).select(null);
      case 'pharmacies':
        ref.read(selectedPharmacyProvider.notifier).select(null);
      case 'audit':
        ref.read(selectedAuditProvider.notifier).select(null);
      default:
        break;
    }
  }

  void _go(BuildContext context, WidgetRef ref, String id) {
    final target = switch (id) {
      'overview' => 'overview',
      'pharmacies' => 'pharmacies',
      'listings' => 'pharmacies',
      'catalogue' => 'catalogue',
      'requests' => 'requests',
      'audit' => 'audit',
      _ => 'overview',
    };

    if (section != target) {
      _clearDrawerSelections(ref, section);
    }

    switch (id) {
      case 'overview':
        context.go('/overview');
      case 'pharmacies':
        context.go('/pharmacies');
      case 'listings':
        context.go('/listings');
      case 'catalogue':
        context.go('/catalogue');
      case 'requests':
        context.go('/requests');
      case 'audit':
        context.go('/audit');
      default:
        context.go('/overview');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final selected = switch (section) {
      'overview' ||
      'pharmacies' ||
      'catalogue' ||
      'requests' ||
      'audit' => section,
      // /listings now lives inside /pharmacies — redirect selection there
      'listings' => 'pharmacies',
      _ => 'overview',
    };

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final selectedPharmacy =
        (selected == 'pharmacies') && wide
            ? ref.watch(selectedPharmacyProvider)
            : null;
    final selectedAudit = selected == 'audit' && wide ? ref.watch(selectedAuditProvider) : null;
    final selectedMedicine =
        selected == 'catalogue' && wide ? ref.watch(selectedMedicineProvider) : null;

    final body = switch (selected) {
      'pharmacies' => const PharmaciesScreen(drawerInShell: true),
      'catalogue' => const CatalogueScreen(drawerInShell: true),
      'requests' => const MedicineRequestsScreen(),
      'audit' => const AuditListScreen(drawerInShell: true),
      _ => const AdminOverviewScreen(showHeader: false),
    };

    return AdminFrame(
      adminName: 'Administrator',
      unreadNotifications: unread,
      selectedNavigationId: switch (selected) {
        'requests' => 'catalogue',
        _ => selected,
      },
      onNavigationSelected: (id) => _go(context, ref, id),
      onNotificationsTap: () {
        _clearDrawerSelections(ref, section);
        context.push('/notifications');
      },
      onLogoutTap: () async {
        await ref.read(sessionProvider.notifier).signOut();
        if (context.mounted) context.go('/');
      },
      body: body,
      rightDrawer: selectedPharmacy != null
          ? SizedBox(
              width: 420,
              child: ApplicationDrawer(
                branchId: selectedPharmacy,
                onClose: () => ref.read(selectedPharmacyProvider.notifier).select(null),
              ),
            )
          : selectedMedicine != null
              ? SizedBox(
                  width: 460,
                  child: CatalogueMedicineShellDrawer(
                    selection: selectedMedicine,
                    onClose: () => ref.read(selectedMedicineProvider.notifier).select(null),
                  ),
                )
              : selectedAudit != null
                  ? SizedBox(
                      width: 420,
                      child: AuditDrawer(
                        recordId: selectedAudit,
                        onClose: () => ref.read(selectedAuditProvider.notifier).select(null),
                      ),
                    )
                  : null,
    );
  }
}
