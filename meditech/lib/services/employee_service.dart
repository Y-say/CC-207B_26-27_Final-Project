import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import '../utils/app_failure.dart';
import 'staff_avatar_service.dart';

// Returned when a new employee account is created with a one-time password
class CreatedEmployee {
  final String accountId;
  final String displayId;
  final String username;
  final String temporaryPassword;

  const CreatedEmployee({
    required this.accountId,
    required this.displayId,
    required this.username,
    required this.temporaryPassword,
  });
}

// Form errors sent back from the server for highlighted fields
class EmployeeFieldFailure extends AppFailure {
  final Map<String, String> fieldErrors;

  const EmployeeFieldFailure(super.message, this.fieldErrors);
}

// Manages branch employees, roles, licenses, and password resets
abstract class EmployeeService {
  Future<List<Employee>> loadMine();

  Future<CreatedEmployee> createEmployee({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    String? email,
    required String role,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  });

  Future<void> setActive({
    required String employeeId,
    required bool isActive,
  });

  Future<String> resetPassword({required String employeeId});

  Future<void> changeRole({
    required String employeeId,
    required String newRole,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  });

  Future<void> updateLicense({
    required String employeeId,
    required String prcLicenseNo,
    required DateTime prcLicenseExpiry,
    bool markVerified = false,
    bool ownerConfirmed = false,
  });

  Future<String?> uploadEmployeeAvatar({
    required String employeeAccountId,
    required String fileName,
    required Uint8List bytes,
  });

  Future<void> updateProfile({
    required String employeeId,
    required String firstName,
    String? middleName,
    required String lastName,
  });

  Future<void> updateContactEmail({
    required String employeeId,
    required String email,
  });
}

class SupabaseEmployeeService implements EmployeeService {
  SupabaseEmployeeService({StaffAvatarService? avatarService})
      : _avatarService = avatarService ?? StaffAvatarService();

  final StaffAvatarService _avatarService;

  SupabaseClient get _client => Supabase.instance.client;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> payload) async {
    try {
      final response = await _client.functions.invoke('staff-accounts', body: payload);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map) {
        final rawFields = details['fields'];
        if (rawFields is Map && rawFields.isNotEmpty) {
          final fields = {
            for (final entry in rawFields.entries)
              entry.key.toString(): entry.value.toString(),
          };
          final message = details['error']?.toString() ?? 'Check the highlighted fields.';
          throw EmployeeFieldFailure(message, fields);
        }
      }
      throw AppFailure.fromEdge(error);
    } on SocketException {
      throw const AppFailure('Could not reach Supabase.');
    }
  }

  Future<T> _runRpc<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (error) {
      throw AppFailure.fromPostgrest(error);
    } on SocketException {
      throw const AppFailure('Could not reach Supabase.');
    }
  }

  Future<List<Employee>> _loadEmployeesFromTable() async {
    final rows = await _client.rpc('list_branch_employees');
    if (rows is! List) return [];
    return [
      for (final raw in rows)
        if (raw is Map) Employee.fromJson(Map<String, dynamic>.from(raw)),
    ];
  }

  @override
  Future<List<Employee>> loadMine() async {
    return _runRpc(_loadEmployeesFromTable);
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
    final data = await _invoke({
      'action': 'create',
      'first_name': firstName.trim(),
      if (middleName != null && middleName.trim().isNotEmpty)
        'middle_name': middleName.trim(),
      'last_name': lastName.trim(),
      'username': username.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'role': role,
      if (role == 'pharmacist' && prcLicenseNo != null)
        'prc_license_no': prcLicenseNo.trim(),
      if (role == 'pharmacist' && prcLicenseExpiry != null)
        'prc_license_expiry': _formatDate(prcLicenseExpiry),
    });

    return CreatedEmployee(
      accountId: data['account_id'] as String,
      displayId: (data['display_id'] as String?) ?? '',
      username: username.trim(),
      temporaryPassword: data['temporary_password'] as String,
    );
  }

  @override
  Future<void> setActive({
    required String employeeId,
    required bool isActive,
  }) async {
    await _invoke({
      'action': 'set_active',
      'employee_id': employeeId,
      'is_active': isActive,
    });
  }

  @override
  Future<String> resetPassword({required String employeeId}) async {
    final data = await _invoke({
      'action': 'reset_password',
      'employee_id': employeeId,
    });
    return data['temporary_password'] as String;
  }

  @override
  Future<void> changeRole({
    required String employeeId,
    required String newRole,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) async {
    await _runRpc(() async {
      await _client.rpc('change_employee_role', params: {
        'p_employee_id': employeeId,
        'p_new_role': newRole,
        if (prcLicenseNo != null && prcLicenseNo.trim().isNotEmpty)
          'p_prc_license_no': prcLicenseNo.trim(),
        if (prcLicenseExpiry != null)
          'p_prc_license_expiry': _formatDate(prcLicenseExpiry),
      });
    });
  }

  @override
  Future<void> updateLicense({
    required String employeeId,
    required String prcLicenseNo,
    required DateTime prcLicenseExpiry,
    bool markVerified = false,
    bool ownerConfirmed = false,
  }) async {
    await _runRpc(() async {
      await _client.rpc('update_employee_license', params: {
        'p_employee_id': employeeId,
        'p_prc_license_no': prcLicenseNo.trim(),
        'p_prc_license_expiry': _formatDate(prcLicenseExpiry),
        'p_mark_verified': markVerified,
        'p_owner_confirmed': ownerConfirmed,
      });
    });
  }

  @override
  Future<String?> uploadEmployeeAvatar({
    required String employeeAccountId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _avatarService.uploadForEmployee(
      employeeAccountId: employeeAccountId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  @override
  Future<void> updateProfile({
    required String employeeId,
    required String firstName,
    String? middleName,
    required String lastName,
  }) async {
    await _invoke({
      'action': 'update_profile',
      'employee_id': employeeId,
      'first_name': firstName.trim(),
      if (middleName != null && middleName.trim().isNotEmpty)
        'middle_name': middleName.trim(),
      'last_name': lastName.trim(),
    });
  }

  @override
  Future<void> updateContactEmail({
    required String employeeId,
    required String email,
  }) async {
    await _invoke({
      'action': 'update_employee_email',
      'employee_id': employeeId,
      'email': email.trim(),
    });
  }
}
