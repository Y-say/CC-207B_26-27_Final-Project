import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Customer sign-in matched to the Main Flow "Welcome back" screen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final identifier = _identifier.text.trim();
    final password = _password.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter your email or mobile number and password.';
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
            identifier: identifier,
            password: password,
            app: 'customer',
          );
      if (mounted) context.go('/home');
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
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.md,
                            AppSpacing.xl,
                            AppSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              const SizedBox(height: AppSpacing.lg),
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
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Welcome back',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Text(
                                'Sign in to continue managing your medicines.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              AppTextField(
                                label: 'Email address',
                                controller: _identifier,
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppPasswordField(
                                label: 'Password',
                                controller: _password,
                                errorText: _error,
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      context.push('/forgot-password'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: cardRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  onPressed: _busy ? null : _signIn,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    shape: buttonShape,
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
                                          'Sign in',
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
                                      'New to MediTech? ',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push('/sign-up'),
                                      child: const Text(
                                        'Create an account',
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
                              const Spacer(),
                              const SizedBox(height: AppSpacing.xl),
                              const Text(
                                'Your health information stays private and protected.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
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
