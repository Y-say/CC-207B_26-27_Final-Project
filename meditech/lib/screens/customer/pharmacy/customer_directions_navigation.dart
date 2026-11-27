import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/osm_listing.dart';
import '../../../routes/customer_navigator_keys.dart';
import 'directions_screen.dart';

/// Same directions flow as a registered pharmacy: `/directions` with [DirectionsArgs].
void pushCustomerDirections(BuildContext context, DirectionsArgs args) {
  final rootCtx = customerRootNavigatorKey.currentContext;
  final router = GoRouter.maybeOf(context) ??
      (rootCtx != null && rootCtx.mounted ? GoRouter.maybeOf(rootCtx) : null);

  if (router != null) {
    router.push(args.routeLocation, extra: args);
    return;
  }

  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/directions'),
      builder: (_) => DirectionsScreen(
        pharmacyName: args.pharmacyName,
        branchName: args.branchName,
        address: args.address,
        destination: args.destination,
        fromOsmDirectory: args.fromOsmDirectory,
      ),
    ),
  );
}

void pushOsmListingDirections(BuildContext context, OsmListing listing) {
  final rootCtx = customerRootNavigatorKey.currentContext;
  final router = GoRouter.maybeOf(context) ??
      (rootCtx != null && rootCtx.mounted ? GoRouter.maybeOf(rootCtx) : null);

  // Path carries the listing id so prod/web builds never need [extra] on `/directions`.
  final location = '/directions/osm/${listing.id}';

  if (router != null) {
    router.push(location, extra: listing);
    return;
  }

  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: location),
      builder: (_) => DirectionsScreen(
        pharmacyName: listing.name,
        branchName: '',
        address: listing.address,
        destination: LatLng(listing.latitude, listing.longitude),
        fromOsmDirectory: true,
      ),
    ),
  );
}