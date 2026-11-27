import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_providers.dart';
import '../screens/pharmacy/activity_log/activity_log_screen.dart';
import '../screens/pharmacy/employees/employees_screen.dart';
import '../screens/pharmacy/inventory/inventory_screen.dart';
import '../screens/pharmacy/pharmacy_dashboard_route.dart';
import '../screens/pharmacy/pharmacy_shell_screen.dart';
import '../screens/pharmacy/registration/application_status_screen.dart';
import '../screens/pharmacy/registration/registration_screen.dart';
import '../screens/pharmacy/branch_settings/branch_settings_screen.dart';
import '../screens/pharmacy/profile/pharmacy_edit_profile_screen.dart';
import '../screens/pharmacy/profile/pharmacy_profile_screen.dart';
import '../screens/pharmacy/reservations/reservations_screen.dart';
import '../screens/pharmacy/renewal/lto_renewal_screen.dart';
import '../screens/pharmacy/sign_in/pharmacy_sign_in_screen.dart';
import '../screens/customer/forgot_password/check_email_screen.dart';
import '../screens/customer/forgot_password/forgot_password_route_extra.dart';
import '../screens/customer/forgot_password/forgot_password_screen.dart';
import '../screens/customer/forgot_password/reset_password_screen.dart';
import '../screens/pharmacy/stock_alerts/stock_alerts_screen.dart';
import '../screens/shared/change_password_screen.dart';
import '../screens/shared/notification_list_screen.dart';
import 'password_redirect.dart';

// Pages a pharmacy user can open
final pharmacyRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      return redirectForPharmacySession(
        ref.read(sessionProvider),
        state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PharmacySignInScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(
          signInPath: '/',
          subtitle:
              'Enter the Gmail on your pharmacy profile, or your username if that Gmail is already saved. '
              "We'll email a 6-digit reset code.",
          identifierLabel: 'Gmail or username',
          identifierHint: 'you@gmail.com',
          noDeliveryMessage:
              'No code was sent. Add Gmail under Profile → Edit profile while signed in, or ask your owner to set it on Employees. '
              'Demo @demo.meditech.dev addresses cannot receive mail.',
        ),
        routes: [
          GoRoute(
            path: 'check-email',
            builder: (context, state) {
              final extra = forgotPasswordRouteExtra(state.extra);
              return CheckEmailScreen(
                identifier: extra?['identifier'],
                deliveryEmail: extra?['deliveryEmail'],
                signInPath: extra?['signInPath'] ?? '/',
              );
            },
          ),
          GoRoute(
            path: 'reset',
            builder: (context, state) {
              final extra = forgotPasswordRouteExtra(state.extra);
              final id = extra?['identifier'] ??
                  (state.extra is String ? state.extra as String : null);
              return ResetPasswordScreen(
                identifier: id,
                signInPath: extra?['signInPath'] ?? '/',
                signedInHint:
                    'Your password was updated. Sign in with your username and new password.',
              );
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => PharmacyShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const PharmacyDashboardRoute(),
          ),
          GoRoute(
            path: '/reservations',
            builder: (context, state) => const ReservationsScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/stock-alerts',
            builder: (context, state) => const StockAlertsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const PharmacyProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const PharmacyEditProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const BranchSettingsScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationListScreen(embedded: true),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/application-status',
        builder: (context, state) => ApplicationStatusScreen(
          onBackToSignIn: () async {
            await ref.read(sessionProvider.notifier).signOut();
            // ignore: use_build_context_synchronously
            if (context.mounted) context.go('/');
          },
          onEditAndResubmit: () => context.push('/register'),
        ),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => LtoRenewalScreen(
            onSignOut: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/activity-log',
        builder: (context, state) => const ActivityLogScreen(),
      ),
    ],
  );
});