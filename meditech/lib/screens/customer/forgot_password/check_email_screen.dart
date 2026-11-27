import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shown after reset instructions are sent
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({
    super.key,
    this.identifier,
    this.deliveryEmail,
    this.signInPath = '/sign-in',
    this.resetPath = '/forgot-password/reset',
  });

  final String? identifier;
  final String? deliveryEmail;
  final String signInPath;
  final String resetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.check_circle, size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                deliveryEmail != null
                    ? 'We sent a 6-digit code to $deliveryEmail. Open the message titled Your MediTech password reset code (check Spam). Do not tap any Supabase reset link—it often opens a blank browser tab on Android. Tap Enter the code below instead. The code expires in 1 hour.'
                    : "If that email is registered as a MediTech customer account, we sent a 6-digit code there. Use the same email you signed up with. Check spam and tap Enter the code—do not use a Supabase reset link.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push(
                  resetPath,
                  extra: {
                    'identifier': identifier,
                    'signInPath': signInPath,
                  },
                ),
                child: const Text('Enter the code'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(signInPath),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
