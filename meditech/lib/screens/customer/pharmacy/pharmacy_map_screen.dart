import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/osm_listing.dart';
import '../../../models/pharmacy.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/browse_store_card.dart';
import '../../../widgets/common/customer_osm_listings_section.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'osm_directions_navigation.dart';
import 'osm_listing_details_screen.dart';
import 'pharmacy_details_screen.dart';

// Guest/customer map of approved pharmacy branches and OpenStreetMap pharmacies
class PharmacyMapScreen extends ConsumerStatefulWidget {
  const PharmacyMapScreen({super.key, this.focusBranchId});

  final String? focusBranchId;

  @override
  ConsumerState<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends ConsumerState<PharmacyMapScreen> {
  static const _iloilo = LatLng(10.7202, 122.5621);
  final _map = MapController();
  String? _selectedId;
  PharmacyDetail? _selectedBranch;
  OsmListing? _selectedOsm;
  bool _focused = false;

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _selectedBranch = null;
      _selectedOsm = null;
    });
  }

  void _openDetails(PharmacyDetail pharmacy) {
    final name = Uri.encodeComponent(pharmacy.pharmacyName);
    if (GoRouter.maybeOf(context) != null) {
      context.push('/pharmacies/${pharmacy.branchId}?name=$name');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsScreen(
          branchId: pharmacy.branchId,
          initialTitle: pharmacy.pharmacyName,
        ),
      ),
    );
  }

  void _openOsmDetails(OsmListing listing) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/osm-listing/${listing.id}', extra: listing);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OsmListingDetailsScreen(
          listingId: listing.id,
          initialListing: listing,
        ),
      ),
    );
  }

  void _focusPharmacy(PharmacyDetail pharmacy) {
    setState(() {
      _selectedId = pharmacy.branchId;
      _selectedBranch = pharmacy;
      _selectedOsm = null;
    });
    if (pharmacy.latitude == 0 && pharmacy.longitude == 0) return;
    _map.move(LatLng(pharmacy.latitude, pharmacy.longitude), 15);
  }

  void _focusOsmListing(OsmListing listing) {
    setState(() {
      _selectedId = listing.id;
      _selectedOsm = listing;
      _selectedBranch = null;
    });
    if (listing.latitude == 0 && listing.longitude == 0) return;
    _map.move(LatLng(listing.latitude, listing.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(publicBranchesProvider);
    final hours = ref.watch(publicBranchHoursProvider).value;
    final osmAsync = ref.watch(shownOsmListingsProvider);
    final osmListings = osmAsync.value ?? const <OsmListing>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: AsyncView<List<PharmacyDetail>>(
        value: branchesAsync,
        isEmpty: (items) => items.isEmpty && osmListings.isEmpty,
        emptyMessage: 'No pharmacies are listed yet.',
        onRetry: () => ref.invalidate(publicBranchesProvider),
        builder: (branches) {
          final focusId = widget.focusBranchId;
          if (!_focused && focusId != null) {
            for (final branch in branches) {
              if (branch.branchId == focusId) {
                _focused = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _focusPharmacy(branch);
                });
                break;
              }
            }
          }

          final markers = [
            ...branches
                .where((b) => b.latitude != 0 || b.longitude != 0)
                .map(
                  (branch) => Marker(
                    point: LatLng(branch.latitude, branch.longitude),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _focusPharmacy(branch),
                      child: Icon(
                        Icons.location_on,
                        size: _selectedId == branch.branchId ? 44 : 36,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ...osmListings
                .where((o) => o.latitude != 0 || o.longitude != 0)
                .map(
                  (listing) => Marker(
                    point: LatLng(listing.latitude, listing.longitude),
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _focusOsmListing(listing),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: _selectedId == listing.id ? 40 : 32,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
          ];

          final located = branches.where(
            (b) => b.latitude != 0 || b.longitude != 0,
          );
          final center = located.isEmpty
              ? _iloilo
              : LatLng(located.first.latitude, located.first.longitude);

          return SizedBox.expand(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13.5,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.all &
                          ~InteractiveFlag.scrollWheelZoom &
                          ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ph.meditech',
                    ),
                    MarkerLayer(markers: markers),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: AppSpacing.md,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        if (GoRouter.maybeOf(context)?.canPop() == true ||
                            Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }
                        context.go('/home');
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.42,
                  minChildSize: 0.18,
                  maxChildSize: 0.72,
                  builder: (context, controller) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A1B2420),
                            blurRadius: 16,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedBranch != null) ...[
                            const Text(
                              'Selected pharmacy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            BrowseStoreCard(
                              branchId: _selectedBranch!.branchId,
                              name: _selectedBranch!.pharmacyName,
                              addressLine: _selectedBranch!.distanceKm == null
                                  ? _selectedBranch!.address
                                  : '${_selectedBranch!.address} • ${_selectedBranch!.distanceKm!.toStringAsFixed(1)} km',
                              storefrontPath: _selectedBranch!.storefrontPath,
                              isOpen: pharmacyIsOpenNow(
                                hours?[_selectedBranch!.branchId],
                              ),
                              onTap: () => _openDetails(_selectedBranch!),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              onPressed: _clearSelection,
                              child: const Text('Show all stores'),
                            ),
                          ] else if (_selectedOsm != null) ...[
                            const Text(
                              'Selected pharmacy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            BrowseStoreCard(
                              name: _selectedOsm!.name,
                              addressLine: _selectedOsm!.address.isNotEmpty
                                  ? _selectedOsm!.address
                                  : 'Location from OpenStreetMap',
                              osmImageUrl: _selectedOsm!.imageUrl,
                              osmLatitude: _selectedOsm!.latitude,
                              osmLongitude: _selectedOsm!.longitude,
                              isRegistered: false,
                              onGetDirections: () => pushOsmListingDirections(
                                context,
                                _selectedOsm!,
                              ),
                              onTap: () => _openOsmDetails(_selectedOsm!),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => pushOsmListingDirections(
                                  context,
                                  _selectedOsm!,
                                ),
                                icon: const Icon(Icons.near_me_outlined, size: 18),
                                label: const Text('Get directions'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: _clearSelection,
                              child: const Text('Show all stores'),
                            ),
                          ] else ...[
                            const Text(
                              'Browse All Stores',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Tap a map pin to see one store at a time.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (var i = 0; i < branches.length; i++) ...[
                              if (i > 0) const SizedBox(height: AppSpacing.sm),
                              BrowseStoreCard(
                                branchId: branches[i].branchId,
                                name: branches[i].pharmacyName,
                                addressLine: branches[i].distanceKm == null
                                    ? branches[i].address
                                    : '${branches[i].address} • ${branches[i].distanceKm!.toStringAsFixed(1)} km',
                                storefrontPath: branches[i].storefrontPath,
                                isOpen: pharmacyIsOpenNow(
                                  hours?[branches[i].branchId],
                                ),
                                onTap: () => _openDetails(branches[i]),
                              ),
                            ],
                            if (osmListings.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              CustomerOsmListingsSection(
                                listings: osmListings,
                                compactTitle: true,
                                includeDistanceInAddress: false,
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
