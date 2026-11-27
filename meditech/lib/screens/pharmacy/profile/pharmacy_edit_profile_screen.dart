import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/pharmacy_staff_providers.dart';
import '../../../services/staff_profile_query.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

final _namePattern = RegExp(r"^[A-Za-zÑñ .'-]{2,50}$");
final _usernamePattern = RegExp(r'^[A-Za-z0-9_]{4,20}$');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class PharmacyEditProfileScreen extends ConsumerStatefulWidget {
  const PharmacyEditProfileScreen({super.key});

  @override
  ConsumerState<PharmacyEditProfileScreen> createState() =>
      _PharmacyEditProfileScreenState();
}

class _PharmacyEditProfileScreenState
    extends ConsumerState<PharmacyEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  var _ready = false;
  var _busy = false;
  String? _error;
  String? _savedContactEmail;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(pharmacyStaffProfileProvider).value;
    if (profile != null) _apply(profile);
  }

  void _apply(PharmacyStaffProfile profile) {
    _firstName.text = profile.firstName;
    _middleName.text = profile.middleName ?? '';
    _lastName.text = profile.lastName;
    final user = profile.username?.trim();
    _username.text = user ?? '';
    _savedContactEmail = profile.contactEmail;
    _email.text = profile.contactEmail ?? '';
    _ready = true;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      await updateMyStaffProfile(
        client,
        firstName: _firstName.text,
        middleName: _middleName.text,
        lastName: _lastName.text,
        username: _username.text,
      );
      final nextEmail = _email.text.trim();
      final emailChanged =
          nextEmail.isNotEmpty && nextEmail != (_savedContactEmail ?? '');
      if (emailChanged) {
        await updateMyStaffContactEmail(client, email: nextEmail);
      }
      ref.invalidate(pharmacyStaffProfileProvider);
      if (!mounted) return;
      final savedName = [
        _firstName.text.trim(),
        if (_middleName.text.trim().isNotEmpty) _middleName.text.trim(),
        _lastName.text.trim(),
      ].join(' ');
      await showTabletMessageDialog(
        context: context,
        title: 'Profile updated',
        bullets: [
          savedName,
          'Your display name and sign-in username were saved.',
          if (emailChanged) 'Your contact email was updated.',
          'PRC license is read-only here—edit it under Employees.',
        ],
        isWarning: false,
        buttonLabel: 'Done',
      );
      if (!mounted) return;
      context.pop(true);
    } on AppFailure catch (error) {
      setState(() => _error = error.message);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('username') &&
          (message.contains('unique') || message.contains('duplicate'))) {
        setState(() => _error = 'That username is already taken. Choose another.');
      } else {
        setState(() => _error = AppFailure.fromPostgrest(error).message);
      }
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(pharmacyStaffProfileProvider);
    if (!_ready) {
      profileAsync.whenData((profile) {
        if (profile != null && !_ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _apply(profile));
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => context.pop(false),
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Edit profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update your name, sign-in username, and contact email. '
                'You still sign in with your username and password.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_ready)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: 'First name',
                        controller: _firstName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Middle name (optional)',
                        controller: _middleName,
                        validator: (v) {
                          final trimmed = (v ?? '').trim();
                          if (trimmed.isEmpty) return null;
                          return _namePattern.hasMatch(trimmed)
                              ? null
                              : 'Enter 2 to 50 letters.';
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Last name',
                        controller: _lastName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Username',
                        hint: 'Sign-in username',
                        controller: _username,
                        validator: (v) => _usernamePattern.hasMatch((v ?? '').trim())
                            ? null
                            : '4 to 20 letters, numbers, or underscores.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email (optional)',
                        hint: 'name@gmail.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final trimmed = (v ?? '').trim();
                          if (trimmed.isEmpty) return null;
                          return _emailPattern.hasMatch(trimmed)
                              ? null
                              : 'Enter a valid email.';
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Add or change Gmail here so you can use Forgot password on the branch sign-in screen.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(_busy ? 'Saving…' : 'Save'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: _busy ? null : () => context.pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
