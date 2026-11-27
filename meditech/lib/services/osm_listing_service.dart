import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/osm_listing.dart';

class OsmListingService {
  OsmListingService({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const _listingPublicColumns =
      'id, osm_id, name, address, latitude, longitude, last_edited_there, '
      'status, synced_at';

  static const _listingPublicColumnsWithImage =
      '$_listingPublicColumns, image_url';

  bool _missingImageUrlColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('image_url') ||
        error.code == '42703' ||
        error.code == 'PGRST204';
  }

  List<OsmListing> _rowsToListings(List<dynamic> rows) => rows
      .map(
        (row) => OsmListing.fromJson(Map<String, dynamic>.from(row as Map)),
      )
      .toList();

  Future<List<OsmListing>> fetchShownListings() async {
    try {
      final rows = await _db
          .from('osm_listings')
          .select(_listingPublicColumnsWithImage)
          .eq('status', 'shown')
          .order('name', ascending: true);

      return _rowsToListings(rows as List<dynamic>);
    } on PostgrestException catch (error) {
      if (!_missingImageUrlColumn(error)) rethrow;
      final rows = await _db
          .from('osm_listings')
          .select(_listingPublicColumns)
          .eq('status', 'shown')
          .order('name', ascending: true);
      return _rowsToListings(rows as List<dynamic>);
    }
  }

  Future<OsmListing?> fetchListingById(String id) async {
    try {
      final row = await _db
          .from('osm_listings')
          .select(_listingPublicColumnsWithImage)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return OsmListing.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (!_missingImageUrlColumn(error)) rethrow;
      final row = await _db
          .from('osm_listings')
          .select(_listingPublicColumns)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return OsmListing.fromJson(Map<String, dynamic>.from(row));
    }
  }

  Future<List<OsmListing>> findNearbyListings({
    required double latitude,
    required double longitude,
    int radiusMeters = 100,
  }) async {
    final rows = await _db.rpc(
      'find_nearby_osm_listings',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_meters': radiusMeters,
      },
    );

    return (rows as List<dynamic>)
        .map(
          (row) => OsmListing.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<OsmListing>> fetchAllForAdmin() async {
    const adminWithImage =
        '$_listingPublicColumns, hidden_reason, replaced_by_branch_id, '
        'image_url, branches:replaced_by_branch_id(pharmacy_name, branch_name)';
    const adminLegacy =
        '$_listingPublicColumns, hidden_reason, replaced_by_branch_id, '
        'branches:replaced_by_branch_id(pharmacy_name, branch_name)';

    try {
      final rows =
          await _db.from('osm_listings').select(adminWithImage).order(
            'name',
            ascending: true,
          );
      return _rowsToListings(rows as List<dynamic>);
    } on PostgrestException catch (error) {
      if (!_missingImageUrlColumn(error)) rethrow;
      final rows =
          await _db.from('osm_listings').select(adminLegacy).order(
            'name',
            ascending: true,
          );
      return _rowsToListings(rows as List<dynamic>);
    }
  }

  Future<void> hideListing({
    required String listingId,
    required String reason,
  }) async {
    await _db.rpc(
      'admin_hide_osm_listing',
      params: {'p_listing_id': listingId, 'p_reason': reason.trim()},
    );
  }

  Future<void> showListingAgain({required String listingId}) async {
    await _db.rpc(
      'admin_show_osm_listing',
      params: {'p_listing_id': listingId},
    );
  }

  Future<int> syncFromOpenStreetMap() async {
    // Let the edge function fetch from Overpass server-side — it has its own
    // mirror fallback logic and is not subject to mobile/browser network limits.
    try {
      final res = await _db.functions.invoke(
        'osm-sync',
        body: <String, dynamic>{}, // empty body → edge function fetches from Overpass itself
      );
      final data = res.data;
      if (data is Map && data['synced'] is num) {
        return (data['synced'] as num).toInt();
      }
      if (data is Map && data['error'] is String) {
        throw Exception(data['error'] as String);
      }
      throw Exception('OpenStreetMap sync returned an invalid response.');
    } on FunctionException catch (error) {
      final details = error.details ?? error.toString();
      if (details is Map) {
        final message = details['error'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      if (error.status == 404) {
        throw Exception(
          'The osm-sync function is not deployed. '
          'Run: supabase functions deploy osm-sync',
        );
      }
      if (error.status == 401 || error.status == 403) {
        throw Exception(
          'Permission denied (HTTP ${error.status}). '
          'Make sure you are signed in as an admin.',
        );
      }
      if (error.status == 502 || error.status == 504) {
        throw Exception(
          'OpenStreetMap mirrors timed out (HTTP ${error.status}). '
          'Wait a minute and tap Sync OSM again.',
        );
      }
      // Surface the raw status and details so the error is diagnosable
      final raw = details is Map ? details.toString() : details.toString();
      throw Exception(
        'Sync failed (HTTP ${error.status}): $raw',
      );
    }
  }
}
