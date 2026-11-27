import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/osm_listing.dart';
import '../../screens/customer/pharmacy/osm_directions_navigation.dart';
import '../../screens/customer/pharmacy/osm_listing_details_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'browse_store_card.dart';

const _iloiloCenter = LatLng(10.7202, 122.5621);
const _distance = Distance();

String customerOsmAddressLine(OsmListing listing) {
  final base = listing.address.isNotEmpty
      ? listing.address
      : 'Location from OpenStreetMap';
  if (listing.latitude == 0 && listing.longitude == 0) return base;
  final km = _distance.as(
    LengthUnit.Kilometer,
    _iloiloCenter,
    LatLng(listing.latitude, listing.longitude),
  );
  return '$base • ${km.toStringAsFixed(1)} km';
}

/// Paginated OpenStreetMap pharmacy cards for customer home and map.
class CustomerOsmListingsSection extends StatefulWidget {
  const CustomerOsmListingsSection({
    super.key,
    required this.listings,
    this.perPage = 5,
    this.title = 'More pharmacies nearby',
    this.compactTitle = false,
    this.includeDistanceInAddress = true,
  });

  final List<OsmListing> listings;
  final int perPage;
  final String title;
  final bool compactTitle;
  final bool includeDistanceInAddress;

  @override
  State<CustomerOsmListingsSection> createState() =>
      _CustomerOsmListingsSectionState();
}

class _CustomerOsmListingsSectionState extends State<CustomerOsmListingsSection> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant CustomerOsmListingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listings.length != widget.listings.length) {
      _page = 0;
    }
  }

  String _addressLine(OsmListing listing) {
    if (widget.includeDistanceInAddress) {
      return customerOsmAddressLine(listing);
    }
    return listing.address.isNotEmpty
        ? listing.address
        : 'Location from OpenStreetMap';
  }

  void _openListing(BuildContext context, OsmListing listing) {
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

  @override
  Widget build(BuildContext context) {
    final total = widget.listings.length;
    if (total == 0) return const SizedBox.shrink();

    final pageCount = (total / widget.perPage).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * widget.perPage;
    final end = (start + widget.perPage).clamp(0, total);
    final slice = widget.listings.sublist(start, end);

    final titleStyle = widget.compactTitle
        ? const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          )
        : const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(widget.title, style: titleStyle),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < slice.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          BrowseStoreCard(
            name: slice[i].name,
            addressLine: _addressLine(slice[i]),
            osmImageUrl: slice[i].imageUrl,
            osmLatitude: slice[i].latitude,
            osmLongitude: slice[i].longitude,
            isRegistered: false,
            onGetDirections: () => pushOsmListingDirections(context, slice[i]),
            onTap: () => _openListing(context, slice[i]),
          ),
        ],
        if (pageCount > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _CustomerOsmPager(
            firstShown: start + 1,
            lastShown: end,
            total: total,
            page: page,
            pageCount: pageCount,
            onPrevious: page > 0 ? () => setState(() => _page = page - 1) : null,
            onNext: page < pageCount - 1
                ? () => setState(() => _page = page + 1)
                : null,
          ),
        ],
      ],
    );
  }
}

class _CustomerOsmPager extends StatelessWidget {
  const _CustomerOsmPager({
    required this.firstShown,
    required this.lastShown,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int firstShown;
  final int lastShown;
  final int total;
  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$firstShown–$lastShown of $total',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        IconButton(
          tooltip: 'Previous',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${page + 1} / $pageCount',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}