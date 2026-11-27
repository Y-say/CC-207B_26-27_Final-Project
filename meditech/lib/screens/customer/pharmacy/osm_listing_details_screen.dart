import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'osm_directions_navigation.dart';

// Customer details screen for a pharmacy listed from OpenStreetMap ("Not on MediTech")
class OsmListingDetailsScreen extends ConsumerWidget {
  const OsmListingDetailsScreen({
    super.key,
    required this.listingId,
    this.initialListing,
    this.onGetDirections,
  });

  final String listingId;
  final OsmListing? initialListing;
  final VoidCallback? onGetDirections;

  void _openDirections(BuildContext context, OsmListing listing) {
    if (onGetDirections != null) {
      onGetDirections!();
      return;
    }
    pushOsmListingDirections(context, listing);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncListing = initialListing != null
        ? AsyncValue.data(initialListing)
        : ref.watch(osmListingDetailProvider(listingId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const CustomerLocationAppBarTitle(
          heading: 'Pharmacy details',
          icon: Icons.local_pharmacy_outlined,
          headingStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: AsyncView<OsmListing?>(
        value: asyncListing,
        onRetry: () => ref.invalidate(osmListingDetailProvider(listingId)),
        builder: (listing) {
          if (listing == null) {
            return const StateMessage(
              icon: Icons.store_mall_directory_outlined,
              message:
                  'This OpenStreetMap listing may have been hidden or replaced by a registered pharmacy.',
            );
          }

          final point = LatLng(listing.latitude, listing.longitude);
          final photoUrl = listing.imageUrl;
          final mapHeight =
              photoUrl != null && photoUrl.isNotEmpty ? 140.0 : 200.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  _OsmListingPhoto(url: photoUrl),
                  const SizedBox(height: AppSpacing.md),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: mapHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: point,
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.meditech.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: point,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          left: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'OpenStreetMap',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const StatusBadge('Not on MediTech', tone: BadgeTone.warning),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.md),
                      _DetailLine(
                        icon: Icons.location_on_outlined,
                        text: listing.address,
                      ),
                      if (listing.lastEditedThere != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _DetailLine(
                          icon: Icons.update_outlined,
                          text: 'Map data last updated ${listing.lastEditedThere}',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openDirections(context, listing),
                          icon: const Icon(Icons.near_me_outlined, size: 18),
                          label: const Text('Get directions'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            final coords =
                                '${listing.latitude.toStringAsFixed(5)},${listing.longitude.toStringAsFixed(5)}';
                            Clipboard.setData(ClipboardData(text: coords));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Coordinates copied ($coords)'),
                              ),
                            );
                          },
                          child: const Text('Copy coordinates'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This pharmacy has not registered on MediTech yet. Medicine prices, stock, and reservations are only available for registered pharmacies.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OsmListingPhoto extends StatelessWidget {
  const _OsmListingPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.neutralLight,
                child: Icon(
                  Icons.local_pharmacy_outlined,
                  size: 48,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  child: Text(
                    'Photo from OpenStreetMap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}