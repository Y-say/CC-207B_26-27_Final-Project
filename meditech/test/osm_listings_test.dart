import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/osm_listing.dart';
import 'package:meditech/providers/osm_listing_providers.dart';
import 'package:meditech/screens/admin/listings/osm_listings_screen.dart';
import 'package:meditech/screens/customer/pharmacy/osm_listing_details_screen.dart';
import 'package:meditech/services/osm_listing_service.dart';
import 'package:meditech/widgets/common/nearby_osm_listings_card.dart';

class _FakeOsmListingService extends OsmListingService {
  _FakeOsmListingService(this.items);

  final List<OsmListing> items;
  String? lastHiddenId;
  String? lastHiddenReason;
  String? lastShownId;

  @override
  Future<List<OsmListing>> fetchShownListings() async =>
      items.where((e) => e.status == OsmListingStatus.shown).toList();

  @override
  Future<OsmListing?> fetchListingById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<OsmListing>> findNearbyListings({
    required double latitude,
    required double longitude,
    int radiusMeters = 100,
  }) async => items.where((e) => e.status == OsmListingStatus.shown).toList();

  @override
  Future<List<OsmListing>> fetchAllForAdmin() async =>
      List<OsmListing>.from(items);

  @override
  Future<void> hideListing({
    required String listingId,
    required String reason,
  }) async {
    lastHiddenId = listingId;
    lastHiddenReason = reason;
    final idx = items.indexWhere((e) => e.id == listingId);
    if (idx != -1) {
      final old = items[idx];
      items[idx] = OsmListing(
        id: old.id,
        osmId: old.osmId,
        name: old.name,
        address: old.address,
        latitude: old.latitude,
        longitude: old.longitude,
        lastEditedThere: old.lastEditedThere,
        status: OsmListingStatus.hidden,
        hiddenReason: reason,
      );
    }
  }

  @override
  Future<void> showListingAgain({required String listingId}) async {
    lastShownId = listingId;
    final idx = items.indexWhere((e) => e.id == listingId);
    if (idx != -1) {
      final old = items[idx];
      items[idx] = OsmListing(
        id: old.id,
        osmId: old.osmId,
        name: old.name,
        address: old.address,
        latitude: old.latitude,
        longitude: old.longitude,
        lastEditedThere: old.lastEditedThere,
        status: OsmListingStatus.shown,
      );
    }
  }
}

void main() {
  test('OsmListing.fromJson parses image_url', () {
    final listing = OsmListing.fromJson({
      'id': 'osm-1',
      'osm_id': 'node/1',
      'name': 'Test',
      'address': 'Addr',
      'latitude': 10.7,
      'longitude': 122.5,
      'status': 'shown',
      'image_url': 'https://example.com/p.jpg',
    });
    expect(listing.imageUrl, 'https://example.com/p.jpg');
  });

  final sampleListings = <OsmListing>[
    const OsmListing(
      id: 'osm-1',
      osmId: 'node/41892014',
      name: 'Mediocare Pharmacy',
      address: 'Lapuz, Iloilo City',
      latitude: 10.7031,
      longitude: 122.5812,
      lastEditedThere: 'Mar 2025',
      status: OsmListingStatus.shown,
      distanceMeters: 35,
    ),
    const OsmListing(
      id: 'osm-2',
      osmId: 'way/33219804',
      name: 'St. Jude Botika',
      address: 'Jaro, Iloilo City',
      latitude: 10.7252,
      longitude: 122.5579,
      lastEditedThere: 'Nov 2023',
      status: OsmListingStatus.hidden,
      hiddenReason: 'Pin was in the wrong barangay.',
    ),
  ];

  testWidgets(
    'OsmListingDetailsScreen displays Not on MediTech info and Get directions only',
    (tester) async {
      var directionsTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OsmListingDetailsScreen(
              listingId: 'osm-1',
              initialListing: sampleListings.first,
              onGetDirections: () => directionsTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mediocare Pharmacy'), findsOneWidget);
      expect(find.text('Not on MediTech'), findsOneWidget);
      expect(find.text('Lapuz, Iloilo City'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      expect(find.text('Add to cart'), findsNothing);
      expect(find.text('Reserve'), findsNothing);

      await tester.tap(find.text('Get directions'));
      await tester.pump();
      expect(directionsTapped, isTrue);
    },
  );

  testWidgets(
    'OsmListingsScreen hides and restores listings with reason dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeService = _FakeOsmListingService(
        List<OsmListing>.from(sampleListings),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [osmListingServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: OsmListingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mediocare Pharmacy'), findsOneWidget);
      expect(find.text('St. Jude Botika'), findsOneWidget);

      // Hide the shown listing via the reason dialog
      await tester.ensureVisible(find.text('Hide').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'Duplicate pin in Lapuz',
      );
      await tester.tap(find.text('Hide listing'));
      await tester.pumpAndSettle();

      expect(fakeService.lastHiddenId, 'osm-1');
      expect(fakeService.lastHiddenReason, 'Duplicate pin in Lapuz');

      // Restore a hidden listing
      await tester.tap(find.text('Show again').first);
      await tester.pumpAndSettle();

      expect(fakeService.lastShownId, isNotNull);
    },
  );

  testWidgets(
    'NearbyOsmListingsCard lets registration Step 1 select or decline a match',
    (tester) async {
      final fakeService = _FakeOsmListingService(
        List<OsmListing>.from(sampleListings),
      );
      OsmListing? selected;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [osmListingServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            home: Scaffold(
              body: NearbyOsmListingsCard(
                latitude: 10.7031,
                longitude: 122.5812,
                selectedListingId: null,
                onSelectListing: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('We found a listing near your location'),
        findsOneWidget,
      );
      expect(find.text('Mediocare Pharmacy'), findsOneWidget);

      await tester.tap(find.text('Mediocare Pharmacy'));
      await tester.pump();
      expect(selected?.id, 'osm-1');
    },
  );
}
