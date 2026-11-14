import 'package:flutter/material.dart';

import '../../../models/pharmacy_application.dart';

// Everything typed into the registration form, kept while moving between steps
class RegistrationDraft {
  // Step 1: pharmacy
  final pharmacyName = TextEditingController();
  final branchName = TextEditingController();
  final address = TextEditingController();
  final contactNumber = TextEditingController();
  final pharmacyEmail = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  Set<int> openDays = {1, 2, 3, 4, 5, 6}; // Monday to Saturday
  TimeOfDay opensAt = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closesAt = const TimeOfDay(hour: 20, minute: 0);

  // Step 2: license
  final ltoNumber = TextEditingController();
  DateTime? ltoExpiry;
  PickedDocument? ltoFile;
  PickedDocument? storefrontFile;

  // Step 3: owner account
  final firstName = TextEditingController();
  final middleName = TextEditingController();
  final lastName = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  // Step 4: review
  bool agreed = false;

  // Has a map pin been set?
  bool get hasLocation =>
      double.tryParse(latitude.text) != null && double.tryParse(longitude.text) != null;

  // Opening hours for all 7 days (0 = Sunday)
  List<DayHours> get hours => List.generate(7, (day) {
        if (!openDays.contains(day)) return DayHours(weekday: day, isClosed: true);
        return DayHours(weekday: day, opensAt: _time(opensAt), closesAt: _time(closesAt));
      });

  // Time as "08:00"
  static String _time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Turn the draft into an application to send
  PharmacyApplication toApplication() => PharmacyApplication(
        pharmacyName: pharmacyName.text,
        branchName: branchName.text,
        address: address.text,
        contactNumber: contactNumber.text,
        pharmacyEmail: pharmacyEmail.text,
        latitude: double.parse(latitude.text),
        longitude: double.parse(longitude.text),
        hours: hours,
        ltoNumber: ltoNumber.text,
        ltoExpiry: ltoExpiry!,
        ltoFile: ltoFile!,
        storefrontFile: storefrontFile!,
        firstName: firstName.text,
        middleName: middleName.text.trim().isEmpty ? null : middleName.text,
        lastName: lastName.text,
        mobile: mobile.text,
        email: email.text,
        username: username.text,
        password: password.text,
      );

  // Free the text boxes when the screen closes
  void dispose() {
    for (final c in [
      pharmacyName, branchName, address, contactNumber, pharmacyEmail, latitude, longitude,
      ltoNumber, firstName, middleName, lastName, mobile, email, username, password, confirmPassword,
    ]) {
      c.dispose();
    }
  }
}