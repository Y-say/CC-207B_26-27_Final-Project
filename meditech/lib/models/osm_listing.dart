enum OsmListingStatus {
  shown,
  hidden,
  replaced;

  static OsmListingStatus fromString(String value) => switch (value) {
    'hidden' => OsmListingStatus.hidden,
    'replaced' => OsmListingStatus.replaced,
    _ => OsmListingStatus.shown,
  };
}

class OsmListing {
  const OsmListing({
    required this.id,
    required this.osmId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.lastEditedThere,
    this.status = OsmListingStatus.shown,
    this.hiddenReason,
    this.replacedByBranchId,
    this.replacedByPharmacyName,
    this.syncedAt,
    this.distanceMeters,
    this.imageUrl,
  });

  final String id;
  final String osmId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? lastEditedThere;
  final OsmListingStatus status;
  final String? hiddenReason;
  final String? replacedByBranchId;
  final String? replacedByPharmacyName;
  final DateTime? syncedAt;
  final int? distanceMeters;
  final String? imageUrl;

  factory OsmListing.fromJson(Map<String, dynamic> json) {
    final branch = json['branches'];
    String? replacedName;
    if (branch is Map<String, dynamic>) {
      final pName = branch['pharmacy_name'] as String?;
      final bName = branch['branch_name'] as String?;
      if (pName != null && pName.isNotEmpty) {
        replacedName = (bName != null && bName.isNotEmpty)
            ? '$pName ($bName)'
            : pName;
      }
    }

    return OsmListing(
      id: json['id'] as String,
      osmId: json['osm_id'] as String,
      name: json['name'] as String,
      address: (json['address'] as String?) ?? 'Iloilo City',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lastEditedThere: json['last_edited_there'] as String?,
      status: OsmListingStatus.fromString(
        (json['status'] as String?) ?? 'shown',
      ),
      hiddenReason: json['hidden_reason'] as String?,
      replacedByBranchId: json['replaced_by_branch_id'] as String?,
      replacedByPharmacyName: replacedName,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'] as String)
          : null,
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      imageUrl: _nonEmptyString(json['image_url'] as String?),
    );
  }
}

String? _nonEmptyString(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
