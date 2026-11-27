import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../services/employee_service.dart';
import 'session_providers.dart';

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return SupabaseEmployeeService();
});

// Holds the owner's branch employee list and reloads after any change
class EmployeesNotifier extends AsyncNotifier<List<Employee>> {
  @override
  FutureOr<List<Employee>> build() {
    restoreSessionIfNeeded(
      currentSession: ref.read(sessionProvider),
      setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
    );
    ref.watch(sessionProvider);
    return ref.watch(employeeServiceProvider).loadMine();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(employeeServiceProvider).loadMine(),
    );
  }

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
    final created = await ref.read(employeeServiceProvider).createEmployee(
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          username: username,
          email: email,
          role: role,
          prcLicenseNo: prcLicenseNo,
          prcLicenseExpiry: prcLicenseExpiry,
        );
    await reload();
    return created;
  }

  Future<void> setActive({
    required String employeeId,
    required bool isActive,
  }) async {
    await ref.read(employeeServiceProvider).setActive(
          employeeId: employeeId,
          isActive: isActive,
        );
    await reload();
  }

  Future<String> resetPassword({required String employeeId}) async {
    final password = await ref.read(employeeServiceProvider).resetPassword(
          employeeId: employeeId,
        );
    await reload();
    return password;
  }

  Future<void> changeRole({
    required String employeeId,
    required String newRole,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) async {
    await ref.read(employeeServiceProvider).changeRole(
          employeeId: employeeId,
          newRole: newRole,
          prcLicenseNo: prcLicenseNo,
          prcLicenseExpiry: prcLicenseExpiry,
        );
    await reload();
  }

  Future<void> updateLicense({
    required String employeeId,
    required String prcLicenseNo,
    required DateTime prcLicenseExpiry,
    bool markVerified = false,
    bool ownerConfirmed = false,
  }) async {
    await ref.read(employeeServiceProvider).updateLicense(
          employeeId: employeeId,
          prcLicenseNo: prcLicenseNo,
          prcLicenseExpiry: prcLicenseExpiry,
          markVerified: markVerified,
          ownerConfirmed: ownerConfirmed,
        );
    await reload();
  }

  Future<void> updateProfile({
    required String employeeId,
    required String firstName,
    String? middleName,
    required String lastName,
  }) async {
    await ref.read(employeeServiceProvider).updateProfile(
          employeeId: employeeId,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
        );
    await reload();
  }
}

final employeesProvider =
    AsyncNotifierProvider<EmployeesNotifier, List<Employee>>(
  EmployeesNotifier.new,
);
