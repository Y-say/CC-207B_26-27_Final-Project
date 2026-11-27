import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/signed_in_account.dart';
import '../providers/session_providers.dart';

const _pharmacyShellPaths = {
  '/dashboard',
  '/reservations',
  '/inventory',
  '/stock-alerts',
  '/settings',
  '/employees',
  '/notifications',
  '/profile',
  '/profile/edit',
};

const _adminShellPaths = {
  '/overview',
  '/pharmacies',
  '/listings',
  '/catalogue',
  '/requests',
  '/audit',
  '/notifications',
};

// Temporary passwords must be changed before anything else
String? redirectForPasswordChange(
  SignedInAccount? account,
  String location, {
  String homePath = '/',
}) {
  final changing = location == '/change-password';
  if (account?.mustChangePassword == true && !changing) {
    return '/change-password';
  }
  if (account != null && !account.mustChangePassword && changing) {
    return homePath;
  }
  return null;
}

// Pharmacy owners waiting, rejected, or suspended only see their status pages.
// Approved staff open the tablet shell instead of staying on sign-in.
String? redirectForPharmacySession(SignedInAccount? account, String location) {
  final passwordRedirect = redirectForPasswordChange(
    account,
    location,
    homePath: '/dashboard',
  );
  if (passwordRedirect != null) return passwordRedirect;

  if (account == null) {
    if (location.startsWith('/forgot-password')) return null;
    if (location == '/application-status' ||
        location == '/suspended' ||
        _pharmacyShellPaths.contains(location) ||
        location == '/activity-log' ||
        location == '/notifications') {
      return '/';
    }
    return null;
  }

  final waiting =
      account.state == 'pending_approval' || account.state == 'rejected';
  final suspended = account.state == 'suspended';

  if (waiting) {
    const allowed = {'/application-status', '/change-password', '/register'};
    if (!allowed.contains(location)) return '/application-status';
    return null;
  }

  if (suspended) {
    const allowed = {'/suspended', '/change-password'};
    if (!allowed.contains(location)) return '/suspended';
    return null;
  }

  if (location == '/' ||
      location == '/application-status' ||
      location == '/suspended') {
    return '/dashboard';
  }

  if (location.startsWith('/employees') && account.role != 'owner') {
    return '/dashboard';
  }

  return null;
}

// Signed-in admins open the overview shell; guests stay on sign-in
String? redirectForAdminSession(SignedInAccount? account, String location) {
  final passwordRedirect = redirectForPasswordChange(
    account,
    location,
    homePath: '/overview',
  );
  if (passwordRedirect != null) return passwordRedirect;

  if (account == null) {
    if (_adminShellPaths.contains(location) ||
        location.startsWith('/audit/')) {
      return '/';
    }
    return null;
  }

  if (location == '/') return '/overview';
  return null;
}

class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}
