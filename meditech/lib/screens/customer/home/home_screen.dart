import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../models/reservation.dart';
import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/reservation_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/basket_bar.dart';
import '../../../widgets/common/branch_storefront_thumb.dart';
import '../../../widgets/common/customer_location_title.dart';
import '../../../widgets/common/browse_store_card.dart';
import '../../../widgets/common/customer_osm_listings_section.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/sign_in_sheet.dart';

// Main Flow home matched to the Figma guest/signed-in browse screens
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.cartCount = 0,
    this.notificationCount = 0,
    this.onCartTap,
    this.onNotificationsTap,
    this.onSearchTap,
    this.onViewMapsTap,
    this.onOpenReservations,
    this.onOpenReservationDetails,
    this.onOpenPharmacy,
  });

  final int cartCount;
  final int notificationCount;
  final VoidCallback? onCartTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onViewMapsTap;
  final VoidCallback? onOpenReservations;
  final ValueChanged<String>? onOpenReservationDetails;
  final void Function(PharmacyDetail pharmacy)? onOpenPharmacy;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isGuest = session == null;
    final reservations = ref.watch(myReservationsProvider).value ?? const [];
    final active = reservations.where((r) => r.status.isActive).toList();
    final branchesAsync = ref.watch(publicBranchesProvider);
    final hours = ref.watch(publicBranchHoursProvider).value;
    final browse = ref.watch(storeBrowseProvider);
    final osmAsync = ref.watch(shownOsmListingsProvider);
    final osmListings = osmAsync.value ?? const <OsmListing>[];

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          customerBottomChromeScrollPadding(context),
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Find medicine near you',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: CustomerLocationTitle(
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CircleAction(
                tooltip: 'Cart',
                icon: Icons.shopping_bag_outlined,
                badgeCount: cartCount,
                onPressed: onCartTap,
              ),
              const SizedBox(width: AppSpacing.sm),
              _CircleAction(
                tooltip: 'Notifications',
                icon: Icons.notifications_none,
                badgeCount: notificationCount,
                onPressed: onNotificationsTap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: AppColors.textMuted),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Search medicine...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.mic_none, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isGuest) ...[
            _GuestBanner(
              onSignIn: () => showCustomerSignInSheet(context),
              onCreateAccount: () => context.push('/sign-up'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else if (active.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active reservations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenReservations,
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...active
                .take(3)
                .map(
                  (reservation) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ActiveReservationCard(
                      reservation: reservation,
                      onTap: () =>
                          onOpenReservationDetails?.call(reservation.id),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text(
            'Browse All Stores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  icon: Icons.schedule,
                  label: 'Open now',
                  selected: browse.openNow,
                  onTap: () =>
                      ref.read(storeBrowseProvider.notifier).toggleOpenNow(),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterPill(
                  icon: Icons.tune,
                  label: 'Sort By',
                  onTap: () => _openSortSheet(context, ref, browse.sort),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: onViewMapsTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('View maps'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncView<List<PharmacyDetail>>(
            value: branchesAsync,
            isEmpty: (items) => items.isEmpty && osmListings.isEmpty,
            emptyMessage: 'No approved pharmacies are listed yet.',
            onRetry: () => ref.invalidate(publicBranchesProvider),
            builder: (branches) {
              final visible = _visibleBranches(
                branches,
                hours: hours,
                openNow: browse.openNow,
                sort: browse.sort,
              );
              final showOsm = !browse.openNow && osmListings.isNotEmpty;
              final osmLoadFailed = osmAsync.hasError && !osmAsync.isLoading;
              if (visible.isEmpty && !showOsm && !osmLoadFailed) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'No pharmacies match these filters.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    BrowseStoreCard(
                      branchId: visible[i].branchId,
                      name: visible[i].pharmacyName,
                      addressLine: _addressLine(visible[i]),
                      storefrontPath: visible[i].storefrontPath,
                      isOpen: _branchIsOpen(visible[i], hours),
                      onTap: () => onOpenPharmacy?.call(visible[i]),
                    ),
                  ],
                  if (osmLoadFailed) ...[
                    if (visible.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(shownOsmListingsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Map listings did not load. Tap to retry.',
                      ),
                    ),
                  ],
                  if (browse.openNow && osmListings.isNotEmpty) ...[
                    if (visible.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Turn off Open now to see pharmacies from OpenStreetMap.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (showOsm) ...[
                    if (visible.isNotEmpty)
                      const SizedBox(height: AppSpacing.lg),
                    CustomerOsmListingsSection(listings: osmListings),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

const _iloilo = LatLng(10.7202, 122.5621);
const _distance = Distance();

String _addressLine(PharmacyDetail branch) {
  final km = _kilometers(branch);
  if (km == null) return branch.address;
  return '${branch.address} • ${km.toStringAsFixed(1)} km';
}

double? _kilometers(PharmacyDetail branch) {
  if (branch.distanceKm != null) return branch.distanceKm;
  if (branch.latitude == 0 && branch.longitude == 0) return null;
  return _distance.as(
    LengthUnit.Kilometer,
    _iloilo,
    LatLng(branch.latitude, branch.longitude),
  );
}

bool _branchIsOpen(
  PharmacyDetail branch,
  Map<String, List<PharmacyHours>>? hours,
) {
  return pharmacyIsOpenNow(hours?[branch.branchId]);
}

List<PharmacyDetail> _visibleBranches(
  List<PharmacyDetail> branches, {
  required Map<String, List<PharmacyHours>>? hours,
  required bool openNow,
  required StoreSort sort,
}) {
  final visible = [
    for (final branch in branches)
      if (!openNow || _branchIsOpen(branch, hours)) branch,
  ];
  if (sort == StoreSort.nearest) {
    visible.sort((a, b) {
      final aKm = _kilometers(a) ?? double.infinity;
      final bKm = _kilometers(b) ?? double.infinity;
      return aKm.compareTo(bKm);
    });
  }
  return visible;
}

Future<void> _openSortSheet(
  BuildContext context,
  WidgetRef ref,
  StoreSort current,
) async {
  var selected = current;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<StoreSort>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) setSheetState(() => selected = value);
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<StoreSort>(
                        value: StoreSort.nearest,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Nearest'),
                      ),
                      RadioListTile<StoreSort>(
                        value: StoreSort.recommended,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Recommended (5+ MedFound)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () {
                    ref.read(storeBrowseProvider.notifier).setSort(selected);
                    Navigator.of(sheetContext).pop();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

enum StoreSort { nearest, recommended }

class StoreBrowseState {
  const StoreBrowseState({
    this.openNow = false,
    this.sort = StoreSort.recommended,
  });

  final bool openNow;
  final StoreSort sort;

  StoreBrowseState copyWith({bool? openNow, StoreSort? sort}) {
    return StoreBrowseState(
      openNow: openNow ?? this.openNow,
      sort: sort ?? this.sort,
    );
  }
}

class StoreBrowseNotifier extends Notifier<StoreBrowseState> {
  @override
  StoreBrowseState build() => const StoreBrowseState();

  void toggleOpenNow() => state = state.copyWith(openNow: !state.openNow);

  void setSort(StoreSort sort) => state = state.copyWith(sort: sort);
}

final storeBrowseProvider =
    NotifierProvider<StoreBrowseNotifier, StoreBrowseState>(
      StoreBrowseNotifier.new,
    );

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.text;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onSignIn, required this.onCreateAccount});

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You're browsing as a guest",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You can search medicines, compare prices, and get directions. Sign in to reserve.',
            style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onSignIn,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCreateAccount,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Create account'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveReservationCard extends StatelessWidget {
  const _ActiveReservationCard({required this.reservation, this.onTap});

  final CustomerReservation reservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (reservation.status) {
      ReservationStatus.readyForPickup => BadgeTone.success,
      ReservationStatus.confirmed => BadgeTone.info,
      _ => BadgeTone.warning,
    };
    final label = switch (reservation.status) {
      ReservationStatus.pending => 'Pending Confirmation',
      _ => reservation.status.label,
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              BranchStorefrontThumb(
                branchId: reservation.branchId,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.referenceNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reservation.pharmacyName,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBadge(label, tone: tone),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
