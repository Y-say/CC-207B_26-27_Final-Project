import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/customer/landing/landing_screen.dart';
import '../screens/customer/login/login_screen.dart';
import '../screens/customer/sign_up/sign_up_screen.dart';
import '../screens/shared/change_password_screen.dart';
import 'password_redirect.dart';
import '../providers/session_providers.dart';

// Pages a customer can open
final customerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      return redirectForPasswordChange(
        ref.read(sessionProvider),
        state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
    ],
  );
});