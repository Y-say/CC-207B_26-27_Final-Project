import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Returns a masked inbox address when a code was emailed.
  Future<String?> sendPasswordReset({required String identifier});

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  });

  Future<void> finishPasswordRecovery({required String newPassword});

  Future<void> signOut();

  Future<void> resendSignUpConfirmation(String email);
}

class SupabaseAuthService implements AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  String? _customerEmailRedirectUrl() {
    if (!kIsWeb) return null;
    return Uri.base.origin;
  }

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
    final account = _accountFrom(signedIn.session?.accessToken, body['account_type']);
    return account.copyWith(mustChangePassword: await _mustChangePassword());
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
        emailRedirectTo: _customerEmailRedirectUrl(),
      );
      final user = created.user;
      if (user == null) {
        throw const AppFailure('Sign-up did not create an account.');
      }

      final session = created.session;
      final identities = user.identities;
      if (session == null) {
        if (identities != null && identities.isEmpty) {
          throw const AppFailure('User already registered');
        }
        throw const AppFailure(
          'Confirm your email from Gmail (check spam), then sign in to finish your profile.',
        );
      }

      final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
      await _client.rpc('create_customer_profile', params: {
        'p_first_name': firstName.trim(),
        'p_middle_name': middleName.trim(),
        'p_last_name': lastName.trim(),
        'p_mobile': cleanMobile,
        'p_birthdate':
            '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}',
      });

      return _accountFrom(session.accessToken, 'customer');
    } on AuthException catch (error) {
      throw AppFailure(_friendlyAuthSignUpMessage(error.message));
    } on PostgrestException catch (error) {
      throw AppFailure(_friendlyAuthSignUpMessage(error.message));
    }
  }

  // Check the current password, save the new one, then clear the temporary-password flag
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AppFailure('Sign in before changing your password.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      await _client.rpc('finish_password_change');
    } on AuthException catch (error) {
      final message = error.message == 'Invalid login credentials'
          ? 'Current password is wrong.'
          : error.message;
      throw AppFailure(message);
    } on PostgrestException catch (error) {
      throw AppFailure(error.message);
    }
  }

  // Read whether this person still has a temporary password
  Future<bool> _mustChangePassword() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return false;
    final row = await _client
        .from('accounts')
        .select('must_change_password')
        .eq('id', id)
        .maybeSingle();
    return row?['must_change_password'] == true;
  }

  // Ask for a reset code. The same reply is used when no account exists.
  @override
  Future<String?> sendPasswordReset({required String identifier}) async {
    try {
      final response = await _client.functions.invoke(
        'forgot-password',
        body: {'action': 'send', 'identifier': identifier.trim()},
      );
      final data = response.data;
      if (data is Map) {
        final masked = data['deliveryEmail'];
        if (masked is String && masked.isNotEmpty) return masked;
      }
      return null;
    } on FunctionException catch (error) {
      throw AppFailure.fromEdge(error);
    }
  }

  // Check the emailed code, then save the new password
  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _client.functions.invoke(
        'forgot-password',
        body: {
          'action': 'reset',
          'identifier': identifier.trim(),
          'code': code.trim(),
          'password': newPassword,
        },
      );
      await _client.auth.signOut();
    } on FunctionException catch (error) {
      throw AppFailure.fromEdge(error);
    }
  }

  @override
  Future<void> finishPasswordRecovery({required String newPassword}) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    }
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Future<void> resendSignUpConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: _customerEmailRedirectUrl(),
      );
    } on AuthException catch (error) {
      throw AppFailure(_friendlyAuthSignUpMessage(error.message));
    }
  }
}

String _friendlyAuthSignUpMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('mobile number is already used') ||
      lower.contains('enter a mobile number like')) {
    return message;
  }
  if (lower.contains('birthdate cannot be in the future')) {
    return message;
  }
  if (lower.contains('duplicate key') ||
      lower.contains('unique constraint') ||
      lower.contains('already registered') ||
      lower.contains('user already registered')) {
    return 'User already registered';
  }
  if (lower.contains('confirm your email')) {
    return message;
  }
  if (lower.contains('password') &&
      (lower.contains('least') || lower.contains('weak') || lower.contains('short'))) {
    return 'Password must be at least 6 characters.';
  }
  if (lower.contains('invalid') && lower.contains('email')) {
    return 'Enter a valid email address.';
  }
  if (lower.contains('rate limit') ||
      lower.contains('too many') ||
      lower.contains('over_email_send_rate_limit') ||
      lower.contains('over_request_rate_limit')) {
    return 'Too many sign-up attempts from this device. Wait about 5 minutes, then try again—or sign in if you already created an account.';
  }
  if (lower.contains('you need to sign up before saving your profile')) {
    return 'Sign-up session expired. Close this page, open sign-up again, and retry.';
  }
  if (lower.contains('create_customer_profile') ||
      lower.contains('could not find the function') ||
      lower.contains('schema cache')) {
    return 'Sign-up is not fully set up on the server yet. Ask your administrator to apply the latest database migration.';
  }
  return message;
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