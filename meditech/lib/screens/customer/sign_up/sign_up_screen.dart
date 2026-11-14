import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_spacing.dart';

// A new customer fills in their name, mobile, email, and password
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  DateTime? _birthdate;
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Save the account only when the form is complete and the passwords match
  Future<void> _signUp() async {
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _birthdate == null) {
      setState(() {
        _offline = false;
        _error = 'Fill in every field. Middle name can be left blank.';
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
      await ref.read(authServiceProvider).signUp(
            firstName: _firstName.text,
            middleName: _middleName.text,
            lastName: _lastName.text,
            mobile: _mobile.text,
            email: _email.text,
            birthdate: _birthdate!,
            password: _password.text,
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

  Future<void> _pickBirthdate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final birthdateLabel = _birthdate == null
        ? 'Choose birthdate'
        : '${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-${_birthdate!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppTextField(label: 'First name', controller: _firstName),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Middle name', controller: _middleName),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Last name', controller: _lastName),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Mobile number',
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _pickBirthdate,
                  child: Text(birthdateLabel),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(label: 'Password', controller: _password),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: _confirmPassword,
                  errorText: _error,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _signUp,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}