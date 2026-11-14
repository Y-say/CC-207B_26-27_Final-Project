import 'dart:typed_data';

// A file the applicant picked (LTO or storefront photo)
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

// Opening hours for one day (0 = Sunday, 6 = Saturday)
class DayHours {
  const DayHours({required this.weekday, this.opensAt, this.closesAt, this.isClosed = false});

  final int weekday;
  final String? opensAt; // like "08:00"
  final String? closesAt; // like "20:00"
  final bool isClosed;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'opens_at': opensAt,
        'closes_at': closesAt,
        'is_closed': isClosed,
      };
}

// Everything the 4 registration steps collect
class PharmacyApplication {
  const PharmacyApplication({
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.contactNumber,
    required this.pharmacyEmail,
    required this.latitude,
    required this.longitude,
    required this.hours,
    required this.ltoNumber,
    required this.ltoExpiry,
    required this.ltoFile,
    required this.storefrontFile,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.mobile,
    required this.email,
    required this.username,
    required this.password,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final String contactNumber;
  final String pharmacyEmail;
  final double latitude;
  final double longitude;
  final List<DayHours> hours;
  final String ltoNumber;
  final DateTime ltoExpiry;
  final PickedDocument ltoFile;
  final PickedDocument storefrontFile;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String mobile;
  final String email;
  final String username;
  final String password;

  // The form details sent to the server (the files go separately)
  Map<String, dynamic> toJson() => {
        'pharmacy_name': pharmacyName.trim(),
        'branch_name': branchName.trim(),
        'address': address.trim(),
        'contact_number': contactNumber.trim(),
        'pharmacy_email': pharmacyEmail.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'hours': hours.map((h) => h.toJson()).toList(),
        'lto_number': ltoNumber.trim(),
        'lto_expiry': ltoExpiry.toIso8601String().substring(0, 10),
        'first_name': firstName.trim(),
        'middle_name': middleName?.trim(),
        'last_name': lastName.trim(),
        'mobile': mobile.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
      };
}