const staffInternalAuthEmailSuffix = '@staff.meditech.internal';

/// System-generated Supabase auth addresses for staff created without a real email.
bool isInternalStaffAuthEmail(String? email) {
  final value = email?.trim().toLowerCase();
  if (value == null || value.isEmpty) return true;
  return value.endsWith(staffInternalAuthEmailSuffix);
}

/// Contact email shown in Profile (hides internal staff-auth addresses).
String? staffContactEmailFromAuth(String? authEmail) {
  if (isInternalStaffAuthEmail(authEmail)) return null;
  return authEmail?.trim();
}