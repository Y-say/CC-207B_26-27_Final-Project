import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_failure.dart';

// Sends one question to the assistant function
abstract class AssistantService {
  Future<String> ask(
    String message, {
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? location,
  });
}

class SupabaseAssistantService implements AssistantService {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<String> ask(
    String message, {
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? location,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-assistant',
        body: {
          'message': message.trim(),
          if (history.isNotEmpty) 'history': history,
          'location': ?location,
        },
      );
      final data = response.data;
      if (data is Map) {
        final answer = data['answer'];
        if (answer is String && answer.isNotEmpty) return answer;
        final err = data['error'];
        if (err is String && err.isNotEmpty) throw AppFailure(err);
      }
      throw const AppFailure('The assistant is unavailable.');
    } on FunctionException catch (error) {
      throw _failure(error);
    }
  }

  AppFailure _failure(FunctionException error) {
    final message = _edgeErrorMessage(error.details);
    if (message != null) return AppFailure(message);
    if (error.status == 0) return const AppFailure('Could not reach Supabase.');
    if (error.status == 403) {
      return const AppFailure('This assistant is for customer accounts only.');
    }
    if (error.status == 401) {
      return const AppFailure('Sign in before using the assistant.');
    }
    return const AppFailure('The assistant is unavailable.');
  }

  static String? _edgeErrorMessage(Object? details) {
    if (details is Map) {
      final message = details['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (details is String && details.isNotEmpty) {
      try {
        final parsed = jsonDecode(details);
        if (parsed is Map && parsed['error'] is String) {
          return parsed['error'] as String;
        }
      } catch (_) {
        return details;
      }
    }
    return null;
  }
}