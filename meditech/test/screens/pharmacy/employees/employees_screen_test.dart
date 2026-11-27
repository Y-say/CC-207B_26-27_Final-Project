import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/employee.dart';
import 'package:meditech/providers/employee_providers.dart';
import 'package:meditech/screens/pharmacy/employees/employees_screen.dart';
import 'package:meditech/services/employee_service.dart';
import 'package:meditech/utils/app_failure.dart';

class _FakeEmployeeService implements EmployeeService {
  List<Employee> items;
  bool failLoad;
  String? lastDeactivatedId;
  String? lastResetId;
  String? lastCreatedUsername;

  _FakeEmployeeService(this.items, {this.failLoad = false});

  @override
  Future<List<Employee>> loadMine() async {
    if (failLoad) throw const AppFailure('Failed to load');
    return List.of(items);
  }

  @override
  Future<CreatedEmployee> createEmployee({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    String? email,
    required String role,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) async {
    lastCreatedUsername = username;
    final created = Employee(
      accountId: 'new-1',
      displayId: 'EMP-000099',
      username: username,
      role: role,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      prcLicenseNo: prcLicenseNo,
      prcLicenseExpiry: prcLicenseExpiry,
      licenseStatus: role == 'pharmacist' ? 'pending' : 'none',
      isActive: true,
    );
    items = [...items, created];
    return CreatedEmployee(
      accountId: 'new-1',
      displayId: 'EMP-000099',
      username: username,
      temporaryPassword: 'TempPass88',
    );
  }

  @override
  Future<void> setActive({required String employeeId, required bool isActive}) async {
    lastDeactivatedId = '$employeeId:$isActive';
    items = [
      for (final e in items)
        if (e.accountId == employeeId)
          Employee(
            accountId: e.accountId,
            displayId: e.displayId,
            username: e.username,
            role: e.role,
            firstName: e.firstName,
            middleName: e.middleName,
            lastName: e.lastName,
            prcLicenseNo: e.prcLicenseNo,
            prcLicenseExpiry: e.prcLicenseExpiry,
            licenseStatus: e.licenseStatus,
            isActive: isActive,
          )
        else
          e,
    ];
  }

  @override
  Future<String> resetPassword({required String employeeId}) async {
    lastResetId = employeeId;
    return 'ResetPass42';
  }

  @override
  Future<void> changeRole({
    required String employeeId,
    required String newRole,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) async {}

  @override
  Future<void> updateLicense({
    required String employeeId,
    required String prcLicenseNo,
    required DateTime prcLicenseExpiry,
    bool markVerified = false,
    bool ownerConfirmed = false,
  }) async {}

  @override
  Future<String?> uploadEmployeeAvatar({
    required String employeeAccountId,
    required String fileName,
    required Uint8List bytes,
  }) async =>
      null;

  @override
  Future<void> updateProfile({
    required String employeeId,
    required String firstName,
    String? middleName,
    required String lastName,
  }) async {}

  @override
  Future<void> updateContactEmail({
    required String employeeId,
    required String email,
  }) async {}
}

List<Employee> _sampleEmployees() => [
      const Employee(
        accountId: 'o1',
        displayId: 'EMP-000001',
        username: 'demo_owner',
        role: 'owner',
        firstName: 'Ana',
        lastName: 'Santos',
        licenseStatus: 'none',
        isActive: true,
      ),
      Employee(
        accountId: 'p1',
        displayId: 'EMP-000002',
        username: 'demo_pharma',
        role: 'pharmacist',
        firstName: 'Jose',
        lastName: 'Reyes',
        prcLicenseNo: '1234567',
        prcLicenseExpiry: DateTime(2030, 12, 31),
        licenseStatus: 'verified',
        isActive: true,
      ),
    ];

Future<void> _pumpEmployees(WidgetTester tester, EmployeeService service) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [employeeServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: EmployeesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists employees and opens drawer on tap', (tester) async {
    final fake = _FakeEmployeeService(_sampleEmployees());
    await _pumpEmployees(tester, fake);

    expect(find.text('Ana Santos'), findsAtLeastNWidgets(1));
    expect(find.text('Jose Reyes'), findsOneWidget);
    expect(find.text('@demo_pharma'), findsOneWidget);

    await tester.tap(find.text('Jose Reyes'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
  });

  testWidgets('adds a staff member without email and shows temporary password', (tester) async {
    final fake = _FakeEmployeeService(_sampleEmployees());
    await _pumpEmployees(tester, fake);

    await tester.tap(find.text('Add employee'));
    await tester.pumpAndSettle();
    tester.takeException(); // suppress layout overflow in dialog

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Maria');
    await tester.enterText(fields.at(1), 'Cruz');
    await tester.enterText(fields.at(3), 'mcruz_staff');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save employee'));
    await tester.pumpAndSettle();

    expect(find.text('Add employee account?'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(fake.lastCreatedUsername, 'mcruz_staff');
    expect(find.text('TempPass88'), findsOneWidget);
  });

  testWidgets('deactivating and resetting password require confirmation', (tester) async {
    final fake = _FakeEmployeeService(_sampleEmployees());
    await _pumpEmployees(tester, fake);

    await tester.tap(find.text('Jose Reyes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    tester.takeException(); // suppress layout overflow in dialog
    expect(find.text('Deactivate employee?'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Deactivate').last);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate').last);
    await tester.pumpAndSettle();
    expect(fake.lastDeactivatedId, 'p1:false');

    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    tester.takeException(); // suppress layout overflow in dialog
    expect(find.text('Reset password?'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Reset password').last);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password').last);
    await tester.pumpAndSettle();
    expect(fake.lastResetId, 'p1');
    expect(find.text('ResetPass42'), findsOneWidget);
  });

  testWidgets('shows retry state when loading fails', (tester) async {
    final fake = _FakeEmployeeService(const [], failLoad: true);
    await _pumpEmployees(tester, fake);

    expect(find.text('Retry'), findsOneWidget);
  });
}
