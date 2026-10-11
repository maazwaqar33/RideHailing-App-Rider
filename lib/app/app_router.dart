import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../features/auth/application/session_controller.dart';
import '../core/config/env.dart';
import '../features/auth/presentation/auth_hub_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/password_screens.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/booking/presentation/choose_ride_screen.dart';
import '../features/booking/presentation/fleets_screen.dart';
import '../features/booking/presentation/confirm_pay_screen.dart';
import '../features/history/presentation/trip_receipt_screen.dart';
import '../features/history/presentation/trips_tab.dart';
import '../features/map/data/local_places_store.dart';
import '../features/map/presentation/pick_on_map_screen.dart';
import '../features/map/presentation/ride_tab.dart';
import '../features/map/presentation/search_destination_screen.dart';
import '../features/onboarding/application/onboarding_provider.dart';
import '../features/onboarding/presentation/intro_onboarding_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/profile/presentation/profile_tab.dart';
import '../features/tracking/presentation/ride_screen.dart';
import '../features/trip/presentation/rate_tip_screen.dart';
import '../features/trip/presentation/trip_complete_screen.dart';
import '../features/wallet/presentation/wallet_tab.dart';
import 'home_shell.dart';

const _publicPaths = {
  '/onboarding',
  '/intro',
  '/auth',
  '/welcome',
  '/login',
  '/signup',
  '/forgot',
  '/reset',
  '/terms',
  '/privacy',
};

/// Pure redirect rules (unit-tested). [location] is the matched path without query.
String? appRedirect({
  required SessionState session,
  required bool onboardingSeen,
  required String location,
  bool hubVariant = false,
}) {
  if (session is SessionRestoring || session is SessionRestoreFailed) {
    return location == '/splash' ? null : '/splash';
  }
  if (session is SessionUnauthenticated) {
    final entry = hubVariant
        ? (onboardingSeen ? '/auth' : '/intro')
        : (onboardingSeen ? '/welcome' : '/onboarding');
    if (location == '/splash') return entry;
    if (_publicPaths.contains(location)) return null;
    return entry;
  }
  // Authenticated
  if (location == '/splash' || _publicPaths.contains(location)) return '/home';
  return null;
}

Page<dynamic> _smoothPage({
  required GoRouterState state,
  required Widget child,
  bool slideFromBottom = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final beginOffset = slideFromBottom
          ? const Offset(0.0, 0.15)
          : const Offset(0.15, 0.0);
      final slideAnimation = Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(curvedAnimation);

      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: curvedAnimation,
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(
    sessionControllerProvider,
    (_, _) => refresh.value++,
  );
  ref.listen<bool>(onboardingSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      session: ref.read(sessionControllerProvider),
      onboardingSeen: ref.read(onboardingSeenProvider),
      location: state.matchedLocation,
      hubVariant: Env.uiVariant == 'hub',
    ),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/intro',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const IntroOnboardingScreen()),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: AuthHubScreen(
            initialTab: state.uri.queryParameters['tab'] == 'new' ? 1 : 0,
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const SignupScreen()),
      ),
      GoRoute(
        path: '/forgot',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: const ForgotPasswordScreen(),
          slideFromBottom: true,
        ),
      ),
      GoRoute(
        path: '/reset',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: ResetPasswordScreen(
            email: state.uri.queryParameters['email'],
            token: state.uri.queryParameters['token'],
          ),
          slideFromBottom: true,
        ),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: LegalScreen.terms(),
          slideFromBottom: true,
        ),
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: LegalScreen.privacy(),
          slideFromBottom: true,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const RideTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/trips', builder: (_, _) => const TripsTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/wallet', builder: (_, _) => const WalletTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) {
          final set = state.uri.queryParameters['set'];
          return _smoothPage(
            state: state,
            child: SearchDestinationScreen(
              setSlot: set == null
                  ? null
                  : SavedSlot.values.firstWhere(
                      (s) => s.name == set,
                      orElse: () => SavedSlot.home,
                    ),
            ),
            slideFromBottom: true,
          );
        },
      ),
      GoRoute(
        path: '/pick-on-map',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: PickOnMapScreen(
            target: state.uri.queryParameters['target'] == 'pickup'
                ? PickTarget.pickup
                : PickTarget.dropoff,
          ),
          slideFromBottom: true,
        ),
      ),
      GoRoute(
        path: '/choose-ride',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const ChooseRideScreen()),
      ),
      GoRoute(
        path: '/confirm-pay',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const ConfirmPayScreen()),
      ),
      GoRoute(
        path: '/ride/:id',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: RideScreen(rideId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      // Top-level (not nested under /ride/:id) so opening it never also builds the live ride screen.
      GoRoute(
        path: '/ride-complete/:id',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: TripCompleteScreen(
            rideId: int.parse(state.pathParameters['id']!),
          ),
          slideFromBottom: true,
        ),
      ),
      GoRoute(
        path: '/fleets',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const FleetsScreen()),
      ),
      GoRoute(
        path: '/rate/:id',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: RateTipScreen(rideId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (_, state) => _smoothPage(
          state: state,
          child: TripReceiptScreen(
            rideId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/design-kit',
        pageBuilder: (_, state) =>
            _smoothPage(state: state, child: const DesignKitDemoScreen()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
