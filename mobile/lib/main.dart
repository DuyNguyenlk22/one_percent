import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'injection/dependency_injection.dart';

/// Entry point.
///
/// Resolves the dependencies that cannot be created synchronously, hands them
/// to the provider container as overrides, and starts the app. Everything else
/// is constructed lazily by `injection/dependency_injection.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const App(),
    ),
  );
}
