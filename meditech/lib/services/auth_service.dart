import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/signed_in_account.dart';
import '../utils/app_failure.dart';

// The only place that talks to the sign-in function
abstract class AuthService {
  Future<SignedInAccount> signIn({
    required String identifier,
    required String password,
    required String app,
  });

  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<SignedInAccount> signIn({
    required String identifier,
    required String password,
    required String app,
  }) async {
    final Map<String, dynamic> body;
    try {
      final response = await _client.functions.invoke(
        'sign-in',
        body: {
          'identifier': identifier.trim(),
          'password': password,
          'app': app,
        },
      );
      body = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      throw AppFailure.signIn(error);
    }

    final refreshToken = body['refresh_token'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const AppFailure('Sign-in did not return a session.');
    }

    final signedIn = await _client.auth.setSession(refreshToken);
    final accessToken = signedIn.session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AppFailure('Sign-in did not return a session.');
    }

    final claims = _readClaims(accessToken);
    claims.putIfAbsent('account_type', () => body['account_type']);
    return SignedInAccount.fromJson(claims);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}

Map<String, dynamic> _readClaims(String accessToken) {
  final parts = accessToken.split('.');
  if (parts.length < 2) {
    throw const AppFailure('Sign-in did not return a session.');
  }
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  final decoded = jsonDecode(payload);
  if (decoded is! Map) {
    throw const AppFailure('Sign-in did not return a session.');
  }
  return Map<String, dynamic>.from(decoded);
}
