import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../core/widgets/app_loading.dart';
import '../shell/main_shell_scaffold.dart';
import '../../features/habits/presentation/pages/today_page.dart';
import '../../features/habits/presentation/pages/routines_page.dart';
import '../../features/habits/presentation/pages/add_habit_page.dart';
import '../../features/insights/presentation/pages/insights_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's GoRouter, rebuilt when auth state changes.
///
/// Redirects live here rather than in the pages: a page should not have to know
/// whether the user may see it. The rules are:
///
/// - status unknown → hold on the splash screen
/// - unauthenticated on a private route → go to login
/// - authenticated on an auth route → go to the main shell
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AuthStatus>(AuthStatus.unknown);

  ref.listen(
    authNotifierProvider.select((state) => state.status),
    (_, status) => notifier.value = status,
    fireImmediately: true,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splashPath,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final status = notifier.value;
      final location = state.matchedLocation;
      final isPublic = RouteNames.publicPaths.contains(location);

      // Still restoring the stored session — stay on the splash screen.
      if (status == AuthStatus.unknown) {
        return location == RouteNames.splashPath ? null : RouteNames.splashPath;
      }

      if (status == AuthStatus.unauthenticated) {
        return isPublic && location != RouteNames.splashPath
            ? null
            : RouteNames.loginPath;
      }

      // Authenticated: keep the user out of the auth pages.
      return isPublic ? RouteNames.todayPath : null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder: (context, state) => ForgotPasswordPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.todayPath,
                name: RouteNames.today,
                builder: (context, state) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.habitsPath,
                name: RouteNames.habits,
                builder: (context, state) => const RoutinesPage(),
                routes: [
                  GoRoute(
                    path: RouteNames.addHabitPath,
                    name: RouteNames.addHabit,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddHabitPage(),
                  ),
                  GoRoute(
                    path: RouteNames.habitDetailPath,
                    name: RouteNames.habitDetail,
                    builder: (context, state) => _PlaceholderPage(
                      title: 'Habit ${state.pathParameters['habitId']}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.insightsPath,
                name: RouteNames.insights,
                builder: (context, state) => const InsightsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profilePath,
                name: RouteNames.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

/// Shown while `AuthNotifier` restores the stored session.
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppLoading(message: 'Getting things ready…'));
}

/// Stands in for a feature that has not been built yet.
///
/// Replace each of these with the real page as its feature lands; the route
/// itself does not need to change.
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — coming soon')),
    );
  }
}
