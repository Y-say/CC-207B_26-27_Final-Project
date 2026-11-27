import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/staff_avatar_local_store.dart';
import '../services/staff_avatar_service.dart';
import '../services/staff_profile_query.dart';
import '../utils/app_failure.dart';
import '../utils/staff_contact_email.dart';

import 'branch_reservation_providers.dart';
import 'session_providers.dart';
import 'stock_alerts_providers.dart';

final staffAvatarServiceProvider = Provider<StaffAvatarService>((ref) {
  return StaffAvatarService();
});

/// Cache-bust token (ms timestamp) after avatar uploads — same storage path on upsert.
class StaffAvatarRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = DateTime.now().millisecondsSinceEpoch;
}

final staffAvatarRevisionProvider =
    NotifierProvider<StaffAvatarRevision, int>(StaffAvatarRevision.new);

/// Storage path from the latest successful upload until profile row reloads.
class StaffAvatarPathOverride extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? path) => state = path;

  void clear() => state = null;
}

final staffAvatarPathOverrideProvider =
    NotifierProvider<StaffAvatarPathOverride, String?>(StaffAvatarPathOverride.new);

/// Signed-in pharmacy staff profile from [staff_members] + own [accounts] row.
class PharmacyStaffProfile {
  const PharmacyStaffProfile({
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.employeeId,
    required this.role,
    this.username,
    this.email,
    this.avatarPublicUrl,
    this.avatarStoragePath,
    this.prcLicenseNo,
    this.prcLicenseExpiry,
    this.licenseStatus = 'none',
  });

  final String firstName;
  final String lastName;
  final String? middleName;
  final String employeeId;
  final String role;
  final String? username;
  final String? email;
  final String? avatarPublicUrl;
  final String? avatarStoragePath;
  final String? prcLicenseNo;
  final DateTime? prcLicenseExpiry;
  final String licenseStatus;

  String get fullName {
    final mid = middleName?.trim();
    if (mid != null && mid.isNotEmpty) {
      return '$firstName $mid $lastName'.trim();
    }
    return '$firstName $lastName'.trim();
  }

  /// Header chip label (same as sidebar role).
  String get displayName => fullName;

  String get roleLabel => switch (role) {
        'owner' => 'Owner',
        'pharmacist' => 'Pharmacist',
        _ => 'Staff',
      };

  String get licenseStatusLabel => switch (licenseStatus) {
        'verified' => 'Verified',
        'pending' => 'Pending verification',
        'expired' => 'Expired',
        'rejected' => 'Rejected',
        'none' => 'Not on file',
        _ => 'Not on file',
      };

  /// Pharmacists and owner–pharmacists keep a personal PRC on file (not branch staff).
  bool get showsPrcLicenseSection => role == 'pharmacist' || role == 'owner';

  /// Matches database [has_valid_license] (confirm / reject / Rx release).
  bool hasValidPharmacistLicense([DateTime? onDate]) {
    final expiry = prcLicenseExpiry;
    if (licenseStatus != 'verified' || expiry == null) return false;
    final refDay = onDate ?? DateTime.now();
    final today = DateTime(refDay.year, refDay.month, refDay.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return !expiryDay.isBefore(today);
  }

  /// Owner or pharmacist may cancel (staff cannot) per [cancel_reservation].
  bool get canCancelReservation => role == 'owner' || role == 'pharmacist';

  /// Real contact email from auth, excluding internal staff sign-in addresses.
  String? get contactEmail => staffContactEmailFromAuth(email);
}

/// True when the signed-in user may confirm or reject pending reservations.
final pharmacyCanLicenseReservationsProvider = Provider<bool>((ref) {
  final profile = ref.watch(pharmacyStaffProfileProvider).value;
  return profile?.hasValidPharmacistLicense() ?? false;
});

final pharmacyStaffProfileProvider =
    FutureProvider<PharmacyStaffProfile?>((ref) async {
  ref.keepAlive();
  restoreSessionIfNeeded(
    currentSession: ref.read(sessionProvider),
    setSignedIn: ref.read(sessionProvider.notifier).setSignedIn,
  );
  ref.watch(sessionProvider);

  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  late final Map<String, dynamic>? raw;
  try {
    raw = await fetchMyStaffProfileRow(client);
  } on PostgrestException catch (error) {
    throw AppFailure.fromPostgrest(error);
  }
  final row = normalizeStaffProfileRow(raw);
  if (row == null) return null;

  final username = row['resolved_username'] as String?;
  final email = client.auth.currentUser?.email;
  var avatarPath = row['avatar_path'] as String?;
  if (avatarPath == null || avatarPath.isEmpty) {
    avatarPath = await staffAvatarLocalStore().load(uid);
  }
  final avatarUrl = ref
      .read(staffAvatarServiceProvider)
      .publicUrlForPath(avatarPath);

  return PharmacyStaffProfile(
    firstName: row['first_name'] as String? ?? '',
    lastName: row['last_name'] as String? ?? '',
    middleName: row['middle_name'] as String?,
    employeeId: row['display_id'] as String? ?? '',
    role: row['role'] as String? ?? 'staff',
    username: username,
    email: email,
    avatarPublicUrl: avatarUrl,
    avatarStoragePath: avatarPath,
    prcLicenseNo: row['prc_license_no'] as String?,
    prcLicenseExpiry: row['prc_license_expiry'] != null
        ? DateTime.tryParse(row['prc_license_expiry'].toString())
        : null,
    licenseStatus: row['license_status'] as String? ?? 'none',
  );
});

/// Photo URL for the shell header — always derived from path + cache bust.
final staffHeaderPhotoUrlProvider = Provider<String?>((ref) {
  final bust = ref.watch(staffAvatarRevisionProvider);
  final pathOverride = ref.watch(staffAvatarPathOverrideProvider);
  final profileAsync = ref.watch(pharmacyStaffProfileProvider);
  final path = pathOverride ?? profileAsync.asData?.value?.avatarStoragePath;
  if (path == null || path.isEmpty) return null;
  return staffAvatarPublicUrl(path, cacheBust: bust == 0 ? null : bust);
});

/// Badge: pending reservations for this branch.
final pharmacyPendingReservationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(branchReservationsProvider).value;
  if (list == null) return 0;
  return list.where((r) => r.status == 'pending').length;
});

/// Badge: total items across stock alert categories.
final pharmacyStockAlertsCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(stockAlertsProvider).value;
  if (alerts == null) return 0;
  var total = 0;
  for (final items in alerts.values) {
    total += items.length;
  }
  return total;
});