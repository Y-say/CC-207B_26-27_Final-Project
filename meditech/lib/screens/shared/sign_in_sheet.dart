import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/session_providers.dart';
import '../../utils/app_failure.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_spacing.dart';

// Open sign-in over the current page, then come back to that same page
Future<void> showCustomerSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const CustomerSignInSheet(),
  );
}

// Email or mobile sign-in that does not leave the page underneath
class CustomerSignInSheet extends ConsumerStatefulWidget {
  const CustomerSignInSheet({super.key});

  @override
  ConsumerState<CustomerSignInSheet> createState() => _CustomerSignInSheetState();
}

class _CustomerSignInSheetState extends ConsumerState<CustomerSignInSheet> {
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

  // Send the customer sign-in, and close the sheet only when it works
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
      if (mounted) Navigator.pop(context);
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (_offline) const OfflineBanner(),
          AppTextField(
            label: 'Email or mobile',
            controller: _identifier,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'Password',
            controller: _password,
            errorText: _error,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/sign-up');
            },
            child: const Text('Create an account'),
          ),
        ],
      ),
    );
  }
}