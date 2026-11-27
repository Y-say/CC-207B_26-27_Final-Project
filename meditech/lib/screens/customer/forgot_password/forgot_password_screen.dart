import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/session_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Ask for an email or mobile number, then send reset instructions
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.signInPath = '/sign-in',
    this.subtitle =
        "Enter the email linked to your account and we'll send you reset instructions.",
    this.identifierLabel = 'Email address',
    this.identifierHint = 'you@example.com',
    this.noDeliveryMessage =
        'No reset code was sent. Sign up in the customer app with your Gmail first, then use that exact email here. Demo @demo.meditech.dev addresses cannot receive mail. On a phone, run the app with env/prod.json (hosted Supabase), not env/dev.json.',
  });

  final String signInPath;
  final String subtitle;
  final String identifierLabel;
  final String identifierHint;
  final String noDeliveryMessage;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifier = TextEditingController();
  var _busy = false;
  var _offline = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  // Send the code to the email on the account
  Future<void> _send() async {
    final identifier = _identifier.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _offline = false;
        _error = 'Enter your email or mobile number.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });

    try {
      final deliveryEmail = await ref
          .read(authServiceProvider)
          .sendPasswordReset(identifier: identifier);
      if (!mounted) return;
      if (deliveryEmail == null) {
        setState(() => _error = widget.noDeliveryMessage);
        return;
      }
      context.push(
        '/forgot-password/check-email',
        extra: {
          'identifier': identifier,
          'deliveryEmail': deliveryEmail,
          'signInPath': widget.signInPath,
        },
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(widget.signInPath),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          if (_offline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Forgot password?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: widget.identifierLabel,
                  controller: _identifier,
                  hint: widget.identifierHint,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _error,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset instructions'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(widget.signInPath),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
