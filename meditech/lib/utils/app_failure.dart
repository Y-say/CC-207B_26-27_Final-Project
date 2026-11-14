import 'package:supabase_flutter/supabase_flutter.dart';

class AppFailure implements Exception {
  final String message;

  const AppFailure(this.message);

  
  factory AppFailure.signIn(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['error'];
      if (message is String && message.isNotEmpty) {
        return AppFailure(message);
      }
    }
    if (error.status == 0) {
      return const AppFailure('Could not reach Supabase.');
    }
    return const AppFailure('Sign-in failed. Try again.');
  }

  @override
  String toString() => message;
}
