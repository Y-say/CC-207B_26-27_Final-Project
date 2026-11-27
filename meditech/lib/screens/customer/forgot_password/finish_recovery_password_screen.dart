import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../utils/validators.dart';
import 'password_changed_modal.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shown after the user opens the reset link and MediTech receives the session.
class FinishRecoveryPasswordScreen extends ConsumerStatefulWidget {
  const FinishRecoveryPasswordScreen({super.key});

  @override
  ConsumerState<FinishRecoveryPasswordScreen> createState() =>
      _FinishRecoveryPasswordScreenState();
}

class _FinishRecoveryPasswordScreenState
    extends ConsumerState<FinishRecoveryPasswordScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final passwordError = Validators.password(_password.text);
    final confirmError = Validators.confirmPassword(
      _confirmPassword.text,
      _password.text,
    );
    final error = passwordError ?? confirmError;
    if (error != null) {
      setState(() {
        _offline = false;
        _error = error;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      await ref.read(authServiceProvider).finishPasswordRecovery(
            newPassword: _password.text,
          );
      if (!mounted) return;
      await showPasswordChangedModal(context);
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
                const Text(
                  'Choose a new password for your account.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.lg),
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