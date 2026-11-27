import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import 'password_changed_modal.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// Enter the emailed code and save a new password
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.identifier,
    this.signInPath = '/sign-in',
    this.signedInHint = 'Sign in with your email and new password.',
  });

  final String? identifier;
  final String signInPath;
  final String signedInHint;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _identifier;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(text: widget.identifier ?? '');
  }

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Save the new password only when the code is present and the two boxes match
  Future<void> _save() async {
    if (_identifier.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter the code and a new password.';
      });
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _offline = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      await ref.read(authServiceProvider).resetPassword(
            identifier: _identifier.text,
            code: _code.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      await showPasswordChangedModal(
        context,
        signInPath: widget.signInPath,
        message: widget.signedInHint,
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
      appBar: AppBar(title: const Text('Reset password')),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppTextField(
                  label: 'Email or mobile',
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Code',
                  controller: _code,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(label: 'New password', controller: _password),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: _confirmPassword,
                  errorText: _error,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
