/// Route paths and names, in one place so no call site hardcodes a string.
///
/// Paths are what appear in the URL; names are what `context.goNamed` takes.
/// Prefer the named form — a path can change without touching call sites.
abstract final class RouteNames {
  // Bootstrap
  static const String welcome = 'welcome';
  static const String welcomePath = '/';

  // Auth
  static const String login = 'login';
  static const String loginPath = '/login';

  static const String register = 'register';
  static const String registerPath = '/register';

  static const String forgotPassword = 'forgot-password';
  static const String forgotPasswordPath = '/forgot-password';

  // Main shell
  static const String today = 'today';
  static const String todayPath = '/today';

  static const String habits = 'habits';
  static const String habitsPath = '/habits';

  static const String addHabit = 'add-habit';
  static const String addHabitPath = 'add';

  static const String habitDetail = 'habit-detail';

  /// Nested under [habitsPath]; use [habitDetailLocation] to build the URL.
  static const String habitDetailPath = ':habitId';

  static String habitDetailLocation(String habitId) => '$habitsPath/$habitId';

  static const String insights = 'insights';
  static const String insightsPath = '/insights';

  static const String profile = 'profile';
  static const String profilePath = '/profile';

  /// Routes reachable while signed out. Everything else redirects to login.
  static const Set<String> publicPaths = {
    welcomePath,
    loginPath,
    registerPath,
    forgotPasswordPath,
  };
}
