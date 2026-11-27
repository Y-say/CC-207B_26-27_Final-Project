import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';
import '../widgets/tablet/tablet_dialogs.dart';

/// User-facing title and explanation for a failed action.
class FriendlyError {
  const FriendlyError({
    required this.title,
    required this.body,
    this.nextStep,
  });

  final String title;
  final String body;
  final String? nextStep;
}

/// Pulls a plain message out of Postgrest, AppFailure, or stringified errors.
String friendlyErrorMessage(Object error) {
  return resolveFriendlyError(error).body;
}

FriendlyError resolveFriendlyError(Object error, {String? action}) {
  final raw = _rawMessage(error);
  final licenseRequired = _matches(
    raw,
    'A verified and unexpired pharmacist license is required',
  );
  final rxLicenseRequired = _matches(
    raw,
    'A verified and unexpired pharmacist license is required to release Rx items',
  );

  if (rxLicenseRequired) {
    return const FriendlyError(
      title: 'Pharmacist license needed for Rx pickup',
      body:
          'This reservation includes prescription (Rx) medicines. Only a pharmacist '
          'with a verified, unexpired PRC license can release them at pickup.',
      nextStep:
          'Sign in as a verified pharmacist, or ask your branch owner to verify '
          'a pharmacist\'s license under Employees.',
    );
  }

  if (licenseRequired) {
    return const FriendlyError(
      title: 'A licensed pharmacist must do this',
      body:
          'Confirming or rejecting reservations is restricted to pharmacists with a '
          'verified, unexpired PRC license. General branch staff—and owners without '
          'a verified license—cannot approve or reject requests.',
      nextStep:
          'Ask your branch owner to verify a pharmacist in Employees, or sign in as '
          'that pharmacist (for example your demo pharmacist account).',
    );
  }

  if (_matches(raw, 'Only pharmacy staff can confirm reservations') ||
      _matches(raw, 'Only pharmacy staff can reject reservations')) {
    return const FriendlyError(
      title: 'Pharmacy sign-in required',
      body: 'You must be signed in as pharmacy staff at this branch.',
    );
  }

  if (_matches(raw, 'Only pending reservations can be confirmed')) {
    return const FriendlyError(
      title: 'Cannot confirm this reservation',
      body: 'Only reservations still waiting for review can be confirmed. '
          'Refresh the list—it may have changed.',
    );
  }

  if (_matches(raw, 'Only pending reservations can be rejected')) {
    return const FriendlyError(
      title: 'Cannot reject this reservation',
      body: 'Only pending reservations can be rejected.',
    );
  }

  if (_matches(raw, 'Only confirmed reservations can be marked as ready')) {
    return const FriendlyError(
      title: 'Cannot mark as ready',
      body: 'This reservation must be confirmed before you can mark it ready for pickup.',
    );
  }

  if (_matches(raw, 'Not enough stock')) {
    return FriendlyError(
      title: 'Not enough stock',
      body: raw.isNotEmpty ? raw : 'There is not enough stock to confirm this reservation.',
      nextStep: 'Update inventory, then try again.',
    );
  }

  if (_matches(raw, 'This reservation belongs to a different branch')) {
    return const FriendlyError(
      title: 'Wrong branch',
      body: 'This reservation belongs to another pharmacy branch.',
    );
  }

  if (_matches(raw, 'Reservation not found')) {
    return const FriendlyError(
      title: 'Reservation not found',
      body: 'It may have been removed or updated. Refresh the list and try again.',
    );
  }

  if (_matches(raw, 'prc_format')) {
    return const FriendlyError(
      title: 'Invalid PRC license number',
      body: 'PRC license numbers must be exactly 7 digits (e.g. 0123456).',
    );
  }

  if (_matches(raw, 'Reason must be between 5 and 200 characters')) {
    return const FriendlyError(
      title: 'Reason too short or too long',
      body: 'Please enter a reason between 5 and 200 characters.',
    );
  }

  if (_matches(raw, 'Too many wrong attempts. Code is locked')) {
    return const FriendlyError(
      title: 'Pickup code locked',
      body:
          'Too many incorrect pickup code attempts. Wait 15 minutes, then try again.',
    );
  }

  if (_matches(raw, 'This pickup code has already been used')) {
    return const FriendlyError(
      title: 'Code already used',
      body: 'This pickup code was already used to complete the reservation.',
    );
  }

  if (_matches(raw, 'Could not reach Supabase')) {
    return const FriendlyError(
      title: 'Connection problem',
      body: 'We could not reach the server. Check your internet and try again.',
    );
  }

  if (raw.isNotEmpty && !_looksTechnical(raw)) {
    return FriendlyError(
      title: action != null ? 'Could not $action' : 'Something went wrong',
      body: raw,
    );
  }

  return FriendlyError(
    title: action != null ? 'Could not $action' : 'Something went wrong',
    body: 'Something went wrong. Please try again, or refresh the page.',
  );
}

Future<void> showFriendlyErrorDialog(
  BuildContext context,
  Object error, {
  String? action,
}) {
  final friendly = resolveFriendlyError(error, action: action);
  if (friendly.nextStep == null) {
    return showTabletMessageDialog(
      context: context,
      title: friendly.title,
      message: friendly.body,
      isWarning: true,
      buttonLabel: 'OK',
    );
  }
  return showTabletMessageDialog(
    context: context,
    title: friendly.title,
    bullets: [friendly.body, friendly.nextStep!],
    isWarning: true,
    buttonLabel: 'OK',
  );
}

String _rawMessage(Object error) {
  if (error is PostgrestException) return error.message.trim();
  if (error is AppFailure) return error.message.trim();
  final text = error.toString();
  final embedded = RegExp(r'message:\s*([^,]+),').firstMatch(text);
  if (embedded != null) return embedded.group(1)!.trim();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length).trim();
  }
  return text.trim();
}

bool _matches(String raw, String needle) =>
    raw.toLowerCase().contains(needle.toLowerCase());

bool _looksTechnical(String raw) =>
    raw.contains('PostgrestException') ||
    raw.contains('P0001') ||
    raw.contains('code:') ||
    raw.contains('details:');