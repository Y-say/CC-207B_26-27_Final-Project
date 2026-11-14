import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// A pharmacy user signs in with a username
class PharmacySignInScreen extends ConsumerStatefulWidget {
  const PharmacySignInScreen({super.key});

  @override
  ConsumerState<PharmacySignInScreen> createState() =>
      _PharmacySignInScreenState();
}

class _PharmacySignInScreenState extends ConsumerState<PharmacySignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  // Send the username and password to the pharmacy sign-in
  Future<void> _signIn() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter your username and password.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      await ref.read(sessionProvider.notifier).signIn(
            identifier: username,
            password: password,
            app: 'pharmacy',
          );
    } on AppFailure catch (error) {
      setState(() {
        _offline = error.message == 'Could not reach Supabase.';
        _error = _offline ? null : error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy sign in')),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppTextField(
                  label: 'Username',
                  controller: _username,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Password',
                  controller: _password,
                  errorText: _error,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}