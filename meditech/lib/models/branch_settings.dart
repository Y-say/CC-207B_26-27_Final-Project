// Represents branch profile and settings information (Ph-36)
class BranchSettings {
  final String branchId;
  final String pharmacyName;
  final String branchName;
  final String address;
  final String contactNumber;
  final String pharmacyEmail;
  final String operatingHours;
  final double? latitude;
  final double? longitude;
  final String fdaLto;
  final DateTime? fdaLtoExpiry;
  final String? storefrontPath;

  const BranchSettings({
    required this.branchId,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.contactNumber,
    this.pharmacyEmail = '',
    required this.operatingHours,
    this.latitude,
    this.longitude,
    required this.fdaLto,
    this.fdaLtoExpiry,
    this.storefrontPath,
  });

  factory BranchSettings.fromJson(Map<String, dynamic> json) {
    return BranchSettings(
      branchId: json['branch_id']?.toString() ?? json['id']?.toString() ?? '',
      pharmacyName: json['pharmacy_name']?.toString() ?? json['name']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      pharmacyEmail: json['pharmacy_email']?.toString() ?? '',
      operatingHours: json['operating_hours']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      fdaLto: json['fda_lto']?.toString() ?? '',
      fdaLtoExpiry: json['fda_lto_expiry'] != null
          ? DateTime.tryParse(json['fda_lto_expiry'].toString())
          : null,
      storefrontPath: json['storefront_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'pharmacy_name': pharmacyName,
      'branch_name': branchName,
      'address': address,
      'contact_number': contactNumber,
      'pharmacy_email': pharmacyEmail,
      'operating_hours': operatingHours,
      'latitude': latitude,
      'longitude': longitude,
      'fda_lto': fdaLto,
      'fda_lto_expiry': fdaLtoExpiry?.toIso8601String(),
    };
  }

  BranchSettings copyWith({
    String? pharmacyName,
    String? branchName,
    String? address,
    String? contactNumber,
    String? pharmacyEmail,
    String? operatingHours,
    double? latitude,
    double? longitude,
    String? fdaLto,
    DateTime? fdaLtoExpiry,
  }) {
    return BranchSettings(
      branchId: branchId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      branchName: branchName ?? this.branchName,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      pharmacyEmail: pharmacyEmail ?? this.pharmacyEmail,
      operatingHours: operatingHours ?? this.operatingHours,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fdaLto: fdaLto ?? this.fdaLto,
      fdaLtoExpiry: fdaLtoExpiry ?? this.fdaLtoExpiry,
    );
  }
}
