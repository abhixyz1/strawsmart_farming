import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async'; 
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'screens/auth/auth_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref.read(authRepositoryProvider).authStateChanges),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = auth.valueOrNull != null;
      final loggingIn = state.fullPath == '/login';
      final onSplash = state.fullPath == '/splash';

      if (!isLoggedIn) {
        if (onSplash || loggingIn) return null;
        return '/login';
      }

      if (isLoggedIn && (loggingIn || onSplash)) {
        return '/dashboard';
      }

      return null;
    },
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListener = () => notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListener());
  }
  late final void Function() notifyListener;
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
