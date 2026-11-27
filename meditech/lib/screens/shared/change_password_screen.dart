import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';
import '../../utils/app_failure.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_colors.dart';
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
          ref.read(sessionProvider.notifier).passwordWasChanged();
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
    final account = ref.watch(sessionProvider);
    final mustChange = account?.mustChangePassword == true;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () async {
            if (mustChange) {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go('/');
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Change password',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            mustChange
                                ? 'Set a new password to continue.'
                                : 'Enter your current password and choose a new one.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.lg),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save password'),
                          ),
                          if (_saved) ...[
                            const SizedBox(height: AppSpacing.md),
                            const Text(
                              'Password saved.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}