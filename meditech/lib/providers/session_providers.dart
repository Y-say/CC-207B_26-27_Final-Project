import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/signed_in_account.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthService();
});

class SessionNotifier extends Notifier<SignedInAccount?> {
  @override
  SignedInAccount? build() => null;

  Future<void> signIn({
    required String identifier,
    required String password,
    required String app,
  }) async {
    final account = await ref.read(authServiceProvider).signIn(
          identifier: identifier,
          password: password,
          app: app,
        );
    state = account;
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = null;
  }
  
  void passwordWasChanged() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(mustChangePassword: false);
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SignedInAccount?>(SessionNotifier.new);
