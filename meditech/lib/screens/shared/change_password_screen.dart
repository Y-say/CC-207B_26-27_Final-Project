import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/session_providers.dart';
import '../../utils/app_failure.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_spacing.dart';

// A signed-in person replaces a temporary password
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;
  var _saved = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Save the new password only when the two new boxes match
  Future<void> _save() async {
    if (_currentPassword.text.isEmpty ||
        _newPassword.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      setState(() {
        _offline = false;
        _saved = false;
        _error = 'Enter your current password and a new password.';
      });
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() {
        _offline = false;
        _saved = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
      _saved = false;
    });

    try {
      await ref.read(authServiceProvider).changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      setState(() => _saved = true);
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
      appBar: AppBar(title: const Text('Change password')),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppPasswordField(
                  label: 'Current password',
                  controller: _currentPassword,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'New password',
                  controller: _newPassword,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirm new password',
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
                if (_saved) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text('Password saved.'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}