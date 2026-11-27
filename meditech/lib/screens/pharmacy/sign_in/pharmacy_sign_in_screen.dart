import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../shared/notification_bell.dart';

// Pharmacy staff sign in to their branch (Ph-01)
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
    final account = ref.watch(sessionProvider);
    final signedIn = account != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _MediTechMark(),
                        const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Sign in to your branch',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        "Use your own account. Shared logins aren't allowed.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (signedIn) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Signed in as ${account.role ?? account.accountType}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const NotificationBell(),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (account.role == 'owner')
                          FilledButton(
                            onPressed: () => context.push('/activity-log'),
                            child: const Text('Activity log'),
                          ),
                        if (account.role == 'owner')
                          const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(sessionProvider.notifier).signOut();
                            if (context.mounted) context.go('/');
                          },
                          child: const Text('Switch user'),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xl,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                label: 'Username',
                                controller: _username,
                                hint: 'Your branch username',
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppPasswordField(
                                label: 'Password',
                                controller: _password,
                                errorText: _error,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton(
                                onPressed: _busy ? null : _signIn,
                                child: _busy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'Sessions sign out after 10 minutes of inactivity.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _RegisterPharmacyCard(),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () {
                            showTabletMessageDialog(
                              context: context,
                              title: 'Check your application status',
                              isWarning: false,
                              bullets: const [
                                'Sign in with the owner username from your application.',
                                'Waiting or rejected applications open the status page right after sign-in.',
                              ],
                            );
                          },
                          child: const Text('Already applied? Check your application status'),
                        ),
                      ],
                    ],
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

// Small MediTech mark at the top of the branch sign-in
class _MediTechMark extends StatelessWidget {
  const _MediTechMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/Meditech Logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'MediTech Partner',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// Card that sends new pharmacies to registration
class _RegisterPharmacyCard extends StatelessWidget {
  const _RegisterPharmacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New to MediTech? Register your pharmacy. Approval needs your FDA License to Operate.',
            style: TextStyle(color: AppColors.text, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.push('/register'),
            child: const Text('Register your pharmacy'),
          ),
        ],
      ),
    );
  }
}
