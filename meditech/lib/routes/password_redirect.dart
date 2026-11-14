import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/signed_in_account.dart';
import '../providers/session_providers.dart';

String? redirectForPasswordChange(SignedInAccount? account, String location) {
  final changing = location == '/change-password';
  if (account?.mustChangePassword == true && !changing) {
    return '/change-password';
  }
  if (account != null && !account.mustChangePassword && changing) {
    return '/';
  }
  return null;
}

class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}