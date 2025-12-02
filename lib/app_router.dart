import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'screens/auth/auth_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/initial_splash_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/schedule/watering_schedule_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/batch/batch_management_screen.dart';
import 'screens/batch/batch_detail_screen.dart';
import 'screens/batch/create_batch_screen.dart';
import 'core/utils/page_transitions.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      ref.read(authRepositoryProvider).authStateChanges,
    ),
    routes: [
      GoRoute(
        path: '/',
        name: 'initial',
        pageBuilder: (context, state) =>
            buildFadeTransitionPage(state: state, child: const InitialSplashScreen()),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) =>
            buildSlideTransitionPage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) =>
            buildSlideTransitionPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => buildSlideTransitionPage(
          state: state,
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/schedule',
        name: 'schedule',
        pageBuilder: (context, state) => buildSlideTransitionPage(
          state: state,
          child: const WateringScheduleScreen(),
        ),
      ),
      GoRoute(
        path: '/report',
        name: 'report',
        pageBuilder: (context, state) =>
            buildSlideTransitionPage(state: state, child: const ReportScreen()),
      ),
      GoRoute(
        path: '/batch',
        name: 'batch',
        pageBuilder: (context, state) => buildSlideTransitionPage(
          state: state,
          child: const BatchManagementScreen(showAppBar: true),
        ),
        routes: [
          GoRoute(
            path: 'create/:greenhouseId',
            name: 'batch-create',
            pageBuilder: (context, state) {
              final greenhouseId = state.pathParameters['greenhouseId']!;
              return buildSlideTransitionPage(
                state: state,
                child: CreateBatchScreen(greenhouseId: greenhouseId),
              );
            },
          ),
          GoRoute(
            path: 'detail/:batchId',
            name: 'batch-detail',
            pageBuilder: (context, state) {
              final batchId = state.pathParameters['batchId']!;
              return buildSlideTransitionPage(
                state: state,
                child: BatchDetailScreen(batchId: batchId),
              );
            },
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = auth.valueOrNull != null;
      final loggingIn = state.fullPath == '/login';
      final onSplash = state.fullPath == '/splash';
      final onInitial = state.fullPath == '/';

      // Allow initial splash to load
      if (onInitial) return null;

      if (!isLoggedIn) {
        if (onSplash || loggingIn) return null;
        return '/login';
      }

      if (isLoggedIn && onSplash) {
        return '/dashboard';
      }

      // When already logged in and currently on /login, allow staying so
      // the screen can drive its own transition after animations.
      if (isLoggedIn && loggingIn) {
        return null;
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
