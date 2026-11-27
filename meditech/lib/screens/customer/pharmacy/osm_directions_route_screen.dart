import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import 'directions_screen.dart';

/// `/directions/osm/:listingId` — directions without relying on GoRouter [extra].
class OsmDirectionsRouteScreen extends ConsumerWidget {
  const OsmDirectionsRouteScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  final String listingId;
  final OsmListing? initialListing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncListing = initialListing != null
        ? AsyncValue.data(initialListing)
        : ref.watch(osmListingDetailProvider(listingId));

    return AsyncView<OsmListing?>(
      value: asyncListing,
      onRetry: () => ref.invalidate(osmListingDetailProvider(listingId)),
      builder: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Directions')),
            body: const Center(
              child: Text(
                'This OpenStreetMap listing is no longer available.',
                style: TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return DirectionsScreen(
          pharmacyName: listing.name,
          branchName: '',
          address: listing.address,
          destination: LatLng(listing.latitude, listing.longitude),
          fromOsmDirectory: true,
        );
      },
    );
  }
}