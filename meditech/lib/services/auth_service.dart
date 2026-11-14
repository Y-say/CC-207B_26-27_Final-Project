import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/signed_in_account.dart';
import '../utils/app_failure.dart';

// The only place that talks to sign-in and sign-up
abstract class AuthService {
  Future<SignedInAccount> signIn({
    required String identifier,
    required String password,
    required String app,
  });

  Future<SignedInAccount> signUp({
    required String firstName,
    required String middleName,
    required String lastName,
    required String mobile,
    required String email,
    required DateTime birthdate,
    required String password,
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
    return _accountFrom(signedIn.session?.accessToken, body['account_type']);
  }

  // Create the login, then save the customer's profile
  @override
  Future<SignedInAccount> signUp({
    required String firstName,
    required String middleName,
    required String lastName,
    required String mobile,
    required String email,
    required DateTime birthdate,
    required String password,
  }) async {
    try {
      final created = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (created.user == null) {
        throw const AppFailure('Sign-up did not create an account.');
      }

      await _client.rpc('create_customer_profile', params: {
        'p_first_name': firstName.trim(),
        'p_middle_name': middleName.trim(),
        'p_last_name': lastName.trim(),
        'p_mobile': mobile.trim(),
        'p_birthdate':
            '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}',
      });

      final refreshed = await _client.auth.refreshSession();
      return _accountFrom(refreshed.session?.accessToken, 'customer');
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    } on PostgrestException catch (error) {
      throw AppFailure(error.message);
    }
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}

SignedInAccount _accountFrom(String? accessToken, Object? accountType) {
  if (accessToken == null || accessToken.isEmpty) {
    throw const AppFailure('Sign-in did not return a session.');
  }
  final claims = _readClaims(accessToken);
  claims.putIfAbsent('account_type', () => accountType);
  return SignedInAccount.fromJson(claims);
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