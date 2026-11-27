import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/customer/assistant/assistant_screen.dart';
import '../screens/customer/cart/cart_screen.dart';
import '../screens/customer/customer_frame.dart';
import '../screens/customer/forgot_password/forgot_password_route_extra.dart';
import '../screens/customer/forgot_password/check_email_screen.dart';
import '../screens/customer/forgot_password/forgot_password_screen.dart';
import '../screens/customer/forgot_password/finish_recovery_password_screen.dart';
import '../screens/customer/forgot_password/reset_password_screen.dart';
import '../screens/customer/landing/landing_screen.dart';
import '../screens/customer/login/login_screen.dart';
import '../screens/customer/medicine/medicine_details_screen.dart';
import '../screens/customer/pharmacy/pharmacy_details_screen.dart';
import '../screens/customer/pharmacy/directions_screen.dart';
import '../screens/customer/pharmacy/pharmacy_map_screen.dart';
import '../screens/customer/profile/edit_profile_screen.dart';
import '../screens/customer/profile/notification_preferences_screen.dart';
import '../screens/customer/profile/privacy_notice_screen.dart';
import '../screens/customer/profile/profile_screen.dart';
import '../screens/customer/profile/saved_addresses_screen.dart';
import '../screens/customer/reservations/reservation_details_screen.dart';
import '../screens/customer/reservations/reservation_submitted_screen.dart';
import '../screens/customer/sign_up/account_created_screen.dart';
import '../screens/customer/sign_up/sign_up_screen.dart';
import '../models/medicine.dart';
import '../models/osm_listing.dart';
import '../screens/customer/pharmacy/osm_directions_route_screen.dart';
import '../screens/customer/pharmacy/osm_listing_details_screen.dart';
import '../screens/shared/change_password_screen.dart';
import '../screens/shared/notification_list_screen.dart';
import '../models/customer_profile.dart';
import '../providers/session_providers.dart';
import 'customer_navigator_keys.dart';
export 'customer_navigator_keys.dart';
import 'password_redirect.dart';

// Pages a customer can open
final customerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: customerRootNavigatorKey,
    refreshListenable: refresh,
    redirect: (context, state) {
      final account = ref.read(sessionProvider);
      final location = state.matchedLocation;

      // Force password change before anything else
      final pwRedirect = redirectForPasswordChange(account, location);
      if (pwRedirect != null) return pwRedirect;

      // Signed-in customers should not linger on auth/landing pages
      if (account != null) {
        if (location == '/' ||
            location == '/sign-in' ||
            location == '/sign-up' ||
            location == '/login') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const CustomerFrame(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(path: '/login', redirect: (context, state) => '/sign-in'),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
        routes: [
          GoRoute(
            path: 'check-email',
            builder: (context, state) {
              final extra = forgotPasswordRouteExtra(state.extra);
              return CheckEmailScreen(
                identifier: extra?['identifier'],
                deliveryEmail: extra?['deliveryEmail'],
                signInPath: extra?['signInPath'] ?? '/sign-in',
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
                signInPath: extra?['signInPath'] ?? '/sign-in',
              );
            },
          ),
          GoRoute(
            path: 'complete',
            parentNavigatorKey: customerRootNavigatorKey,
            builder: (context, state) => const FinishRecoveryPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/account-created',
        builder: (context, state) => const AccountCreatedScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) => EditProfileScreen(
          initialProfile:
              state.extra is CustomerProfile ? state.extra as CustomerProfile : null,
        ),
      ),
      GoRoute(
        path: '/profile/addresses',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        path: '/profile/notification-preferences',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) => const AssistantScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyNoticeScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationListScreen(
          onOpen: (item) {
            final reservationId = item.reservationId;
            if (reservationId == null || reservationId.isEmpty) return;
            context.push('/reservations/$reservationId');
          },
        ),
      ),
      GoRoute(
        path: '/reservations/:id',
        builder: (context, state) => ReservationDetailsScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/reservation-submitted',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! ReservationSubmittedArgs) {
            // Extra lost — navigate to reservations tab
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const Scaffold(body: SizedBox.shrink());
          }
          return ReservationSubmittedScreen(
            reservationId: extra.reservationId,
            referenceNo: extra.referenceNo,
            branchId: extra.branchId,
            pharmacyName: extra.pharmacyName,
            branchName: extra.branchName,
            branchAddress: extra.branchAddress,
            items: extra.items,
            totalAmount: extra.totalAmount,
          );
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/medicines',
        builder: (context, state) {
          final medicine = state.extra;
          if (medicine is! MedicineSearchResult) {
            // Extra lost (back navigation / deep link) — return to search
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const Scaffold(body: SizedBox.shrink());
          }
          return MedicineDetailsScreen(medicine: medicine);
        },
      ),
      GoRoute(
        path: '/directions/osm/:listingId',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['listingId']!;
          final initial = state.extra is OsmListing
              ? state.extra as OsmListing
              : null;
          return OsmDirectionsRouteScreen(
            listingId: id,
            initialListing: initial,
          );
        },
      ),
      GoRoute(
        path: '/directions',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) {
          final args = state.extra is DirectionsArgs
              ? state.extra! as DirectionsArgs
              : directionsArgsFromQuery(state.uri.queryParameters);
          if (args == null) {
            return const _DirectionsArgsMissing();
          }
          return DirectionsScreen(
            pharmacyName: args.pharmacyName,
            branchName: args.branchName,
            address: args.address,
            destination: args.destination,
            fromOsmDirectory: args.fromOsmDirectory,
          );
        },
      ),
      GoRoute(
        path: '/map',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) => PharmacyMapScreen(
          focusBranchId: state.uri.queryParameters['branch'],
        ),
      ),
      GoRoute(
        path: '/pharmacies/:branchId',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) => PharmacyDetailsScreen(
          branchId: state.pathParameters['branchId']!,
          initialTitle: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/osm-listing/:id',
        parentNavigatorKey: customerRootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initial = state.extra is OsmListing
              ? state.extra as OsmListing
              : null;
          return OsmListingDetailsScreen(
            listingId: id,
            initialListing: initial,
          );
        },
      ),
    ],
  );
});

class _DirectionsArgsMissing extends StatelessWidget {
  const _DirectionsArgsMissing();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directions')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We could not open directions for this pharmacy.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
