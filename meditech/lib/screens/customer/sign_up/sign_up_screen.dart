import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import 'account_created_screen.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// A new customer fills in their name, mobile, email, and password
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  static final _phMobilePattern = RegExp(r'^09[0-9]{9}$');

  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final TapGestureRecognizer _privacyTap;
  DateTime? _birthdate;
  var _agreed = false;
  var _busy = false;
  var _offline = false;
  String? _mobileError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _birthdateError;
  String? _formError;

  bool get _isValidMobile => _phMobilePattern.hasMatch(_mobile.text.trim());

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/privacy');
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _mobile,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller.addListener(_onFieldsChanged);
    }
  }

  void _onFieldsChanged() {
    setState(() {
      final mobile = _mobile.text.trim();
      if (mobile.isEmpty) {
        _mobileError = null;
      } else if ((mobile.length == 1 && mobile != '0') ||
          (mobile.length >= 2 && !mobile.startsWith('09'))) {
        _mobileError =
            'Use a Philippine mobile number starting with 09 (11 digits, e.g. 09171234567).';
      } else if (mobile.length == 11 && _isValidMobile) {
        _mobileError = null;
      } else {
        _mobileError = null;
      }

      if (_password.text.isNotEmpty &&
          _confirmPassword.text.isNotEmpty &&
          _password.text != _confirmPassword.text) {
        _confirmPasswordError = 'Passwords do not match.';
      } else if (_password.text == _confirmPassword.text) {
        _confirmPasswordError = null;
      }
    });
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _mobile,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller
        ..removeListener(_onFieldsChanged)
        ..dispose();
    }
    super.dispose();
  }

  bool _isUnder18(DateTime birthdate) {
    final today = DateTime.now();
    final eighteenth = DateTime(
      birthdate.year + 18,
      birthdate.month,
      birthdate.day,
    );
    return eighteenth.isAfter(today);
  }

  bool get _canSubmit {
    if (_busy) return false;
    if (!_agreed) return false;
    if (_birthdate == null) return false;
    if (_isUnder18(_birthdate!)) return false;
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      return false;
    }
    if (!_isValidMobile) return false;
    return _password.text == _confirmPassword.text;
  }

  String? get _submitHint {
    if (_busy) return null;
    if (!_agreed) {
      return 'Check the box to agree to the privacy notice.';
    }
    if (_birthdate == null) {
      return 'Select your birthdate to continue.';
    }
    if (_isUnder18(_birthdate!)) {
      return 'You must be 18 years old or above to register.';
    }
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirmPassword.text.isEmpty) {
      return 'Fill in all required fields.';
    }
    if (!_isValidMobile) {
      return 'Enter a valid 11-digit Philippine mobile number starting with 09.';
    }
    if (_password.text != _confirmPassword.text) {
      return 'Passwords must match before you can create an account.';
    }
    return null;
  }

  bool _isAlreadyRegisteredMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already') ||
        lower.contains('email address is already') ||
        lower.contains('duplicate key') ||
        lower.contains('unique constraint') ||
        lower.contains('accounts_pkey') ||
        lower.contains('user already registered');
  }

  bool _isMobileTakenMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('mobile number is already used');
  }

  bool _isMobileFormatMessage(String message) {
    return message.toLowerCase().contains('enter a mobile number like');
  }

  bool _isBirthdateMessage(String message) {
    return message.toLowerCase().contains('birthdate cannot be in the future');
  }

  bool _isEmailConfirmationMessage(String message) {
    return message.toLowerCase().contains('confirm your email');
  }

  bool _isRateLimitMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('too many sign-up') ||
        lower.contains('rate limit') ||
        lower.contains('too many attempts');
  }

  Future<void> _showEmailConfirmationDialog(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your email'),
        content: const Text(
          'Open the link in your Gmail inbox (check spam). After confirming, '
          'sign in with the same email and password to finish your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(authServiceProvider)
                    .resendSignUpConfirmation(email);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Confirmation email sent again.'),
                  ),
                );
              } on AppFailure catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
            child: const Text('Resend email'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRateLimitDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Please wait'),
        content: const Text(
          'Our server is temporarily limiting new sign-ups from this device. '
          'Wait about 5 minutes and try again.\n\n'
          'If you already submitted the form, your account may exist—try signing in first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  void _applyUnhandledSignUpError(String message) {
    final lower = message.toLowerCase();
    setState(() {
      _offline = message == 'Could not reach Supabase.';
      if (_offline) {
        _formError = null;
        return;
      }
      if (lower.contains('password')) {
        _passwordError = message;
        _formError = null;
        return;
      }
      if (lower.contains('email') && !lower.contains('confirm your email')) {
        _emailError = message;
        _formError = null;
        return;
      }
      if (lower.contains('mobile')) {
        _mobileError = message;
        _formError = null;
        return;
      }
      _formError = message.isNotEmpty
          ? message
          : 'Could not create your account. Try again in a few minutes.';
    });
  }

  Future<void> _showAlreadyRegisteredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account already exists'),
        content: const Text(
          'An account is already registered with this email. Sign in instead, or use a different email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sign-in');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  // Save the account only when the form is complete and the passwords match
  Future<void> _signUp() async {
    if (!_canSubmit) return;

    setState(() {
      _formError = null;
      _mobileError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    if (_password.text != _confirmPassword.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match.';
      });
      return;
    }

    final cleanMobile = _mobile.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(cleanMobile)) {
      setState(() {
        _mobileError =
            'Use a Philippine mobile number like 09171234567 (11 digits, starting with 09).';
      });
      return;
    }

    if (_password.text.length < 6) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters.';
      });
      return;
    }

    final email = _email.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() {
        _emailError = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      _busy = true;
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
      await ref.read(sessionProvider.notifier).signOut();
      if (!mounted) return;
      await showAccountCreatedModal(context);
      if (mounted) context.go('/sign-in');
    } on AppFailure catch (error) {
      try {
        await ref.read(sessionProvider.notifier).signOut();
      } catch (_) {}

      if (_isEmailConfirmationMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        if (mounted) {
          await _showEmailConfirmationDialog(_email.text.trim());
        }
        return;
      }

      if (_isMobileFormatMessage(error.message)) {
        setState(() {
          _offline = false;
          _mobileError = error.message;
        });
        return;
      }

      if (_isBirthdateMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        return;
      }

      if (_isMobileTakenMessage(error.message)) {
        setState(() {
          _offline = false;
          _mobileError = 'This mobile number is already used. Try another number or sign in.';
        });
        return;
      }

      if (_isAlreadyRegisteredMessage(error.message)) {
        if (mounted) {
          await _showAlreadyRegisteredDialog();
        }
        setState(() {
          _offline = false;
          _emailError =
              'This email is already registered. Sign in or use another email.';
        });
        return;
      }

      if (_isRateLimitMessage(error.message)) {
        setState(() {
          _offline = false;
          _formError = error.message;
        });
        if (mounted) {
          await _showRateLimitDialog();
        }
        return;
      }

      _applyUnhandledSignUpError(error.message);
    } on Exception catch (error) {
      try {
        await ref.read(sessionProvider.notifier).signOut();
      } catch (_) {}
      _applyUnhandledSignUpError(error.toString());
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
    if (picked != null) {
      setState(() {
        _birthdate = picked;
        _birthdateError = _isUnder18(picked)
            ? 'You must be 18 years old or above to register.'
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthdateLabel = _birthdate == null
        ? 'mm/dd/yyyy'
        : '${_birthdate!.month.toString().padLeft(2, '0')}/${_birthdate!.day.toString().padLeft(2, '0')}/${_birthdate!.year}';
    final cardRadius = BorderRadius.circular(14);
    final buttonShape = RoundedRectangleBorder(borderRadius: cardRadius);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/Meditech Logo.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'MediTech',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Keep your prescriptions and medicine searches in one secure place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _formError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'First name',
                        controller: _firstName,
                        hint: 'e.g. Juan',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Middle name',
                        controller: _middleName,
                        hint: 'Optional',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Last name',
                        controller: _lastName,
                        hint: 'e.g. Dela Cruz',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Mobile number',
                        controller: _mobile,
                        hint: '09XXXXXXXXX',
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        errorText: _mobileError,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Email address',
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Birthdate *',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: _pickBirthdate,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: _birthdateError != null
                              ? AppColors.danger
                              : _birthdate == null
                                  ? AppColors.textMuted
                                  : AppColors.text,
                          side: BorderSide(
                            color: _birthdateError != null
                                ? AppColors.danger
                                : _birthdate == null
                                    ? AppColors.border
                                    : AppColors.primary,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            birthdateLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (_birthdateError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _birthdateError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordField(
                        label: 'Password',
                        controller: _password,
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordField(
                        label: 'Confirm password',
                        controller: _confirmPassword,
                        errorText: _confirmPasswordError,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () => setState(() => _agreed = !_agreed),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreed,
                                  onChanged: (value) =>
                                      setState(() => _agreed = value ?? false),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Privacy Notice',
                                        recognizer: _privacyTap,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' and the processing of my health data (Data Privacy Act of 2012).',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_submitHint != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _submitHint!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: cardRadius,
                          boxShadow: _canSubmit
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: FilledButton(
                          onPressed: _canSubmit ? _signUp : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: buttonShape,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.35),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.85),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/sign-in'),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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