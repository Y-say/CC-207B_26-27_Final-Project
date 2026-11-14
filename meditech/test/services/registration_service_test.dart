import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditech/models/pharmacy_application.dart';
import 'package:meditech/services/registration_service.dart';

// A sample application for the tests
PharmacyApplication sample() => PharmacyApplication(
      pharmacyName: 'Farmacia Uno',
      branchName: 'Main Branch',
      address: '12 Rizal St, Molo, Iloilo City',
      contactNumber: '0333361111',
      pharmacyEmail: 'uno@test.com',
      latitude: 10.72,
      longitude: 122.56,
      hours: List.generate(7, (d) => DayHours(weekday: d, opensAt: '08:00', closesAt: '20:00')),
      ltoNumber: 'LTO-1',
      ltoExpiry: DateTime(2028, 2, 28),
      ltoFile: PickedDocument(name: 'lto.pdf', bytes: Uint8List(10), mimeType: 'application/pdf'),
      storefrontFile: PickedDocument(name: 's.jpg', bytes: Uint8List(10), mimeType: 'image/jpeg'),
      firstName: 'Ana',
      lastName: 'Reyes',
      mobile: '09171234567',
      email: 'ana@test.com',
      username: 'areyes',
      password: 'Test1234',
    );

void main() {
  // A successful submit returns the pharmacy ID
  test('returns the pharmacy ID when submitted', () async {
    final server = MockClient((_) async =>
        http.Response(jsonEncode({'application_id': 'PHM-000004'}), 201));
    final id = await RegistrationService(server).submit(sample());
    expect(id, 'PHM-000004');
  });

  // A taken username comes back as a field error
  test('reports which field has a problem', () async {
    final server = MockClient((_) async => http.Response(
        jsonEncode({'error': 'This username is taken.', 'fields': {'username': 'Already taken.'}}),
        409));
    expect(
      () => RegistrationService(server).submit(sample()),
      throwsA(isA<RegistrationException>()
          .having((e) => e.fieldErrors['username'], 'username error', 'Already taken.')),
    );
  });
}