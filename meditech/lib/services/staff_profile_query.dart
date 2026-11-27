import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';

/// Columns that have existed since staff accounts were introduced.
const _staffCoreColumns = '''
display_id,
first_name,
middle_name,
last_name,
role,
prc_license_no,
prc_license_expiry,
license_status
''';

bool _missingColumn(PostgrestException error, String column) {
  final message = error.message.toLowerCase();
  return message.contains(column.toLowerCase()) ||
      error.code == '42703' ||
      error.code == 'PGRST204';
}

/// Signed-in staff row. Avoids embedding [accounts] (two FKs make that query fail).
Future<Map<String, dynamic>?> fetchMyStaffProfileRow(SupabaseClient client) async {
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  try {
    final row = await client.rpc('get_my_staff_profile');
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.isNotEmpty && row.first is Map) {
      return Map<String, dynamic>.from(row.first as Map);
    }
  } on PostgrestException {
    // Function not deployed yet — fall through to a direct read.
  }

  try {
    return await client
        .from('staff_members')
        .select('$_staffCoreColumns, avatar_path')
        .eq('account_id', uid)
        .maybeSingle();
  } on PostgrestException catch (error) {
    if (!_missingColumn(error, 'avatar_path')) rethrow;
    return client
        .from('staff_members')
        .select(_staffCoreColumns)
        .eq('account_id', uid)
        .maybeSingle();
  }
}

Map<String, dynamic>? normalizeStaffProfileRow(Map<String, dynamic>? row) {
  if (row == null) return null;
  final username = row['username'];
  return {
    ...row,
    if (username is String && username.isNotEmpty) 'resolved_username': username,
  };
}

/// Saves the signed-in staff member's name.
Future<void> updateMyStaffProfile(
  SupabaseClient client, {
  required String firstName,
  String? middleName,
  required String lastName,
  String? username,
}) async {
  final middle = middleName?.trim();
  final user = username?.trim();
  try {
    await client.rpc('update_my_staff_profile', params: {
      'p_first_name': firstName.trim(),
      'p_middle_name': middle == null || middle.isEmpty ? '' : middle,
      'p_last_name': lastName.trim(),
      if (user != null && user.isNotEmpty) 'p_username': user,
    });
    return;
  } on PostgrestException catch (error) {
    final missing = error.code == 'PGRST202' ||
        error.message.toLowerCase().contains('update_my_staff_profile');
    if (!missing) {
      throw PostgrestException(message: error.message, code: error.code);
    }
  }

  final uid = client.auth.currentUser?.id;
  if (uid == null) {
    throw const PostgrestException(message: 'Sign in to update your profile.');
  }
  await client.from('staff_members').update({
    'first_name': firstName.trim(),
    'middle_name': middle == null || middle.isEmpty ? null : middle,
    'last_name': lastName.trim(),
  }).eq('account_id', uid);
}

/// Saves the signed-in staff member's contact email (Supabase Auth).
Future<void> updateMyStaffContactEmail(
  SupabaseClient client, {
  required String email,
}) async {
  try {
    final response = await client.functions.invoke(
      'staff-accounts',
      body: {
        'action': 'update_my_email',
        'email': email.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw AppFailure(data['error'].toString());
    }
  } on FunctionException catch (error) {
    final details = error.details;
    if (details is Map) {
      final rawFields = details['fields'];
      if (rawFields is Map && rawFields['email'] != null) {
        throw AppFailure(rawFields['email'].toString());
      }
    }
    throw AppFailure.fromEdge(error);
  } on SocketException {
    throw const AppFailure('Could not reach Supabase.');
  }
  await client.auth.refreshSession();
}
