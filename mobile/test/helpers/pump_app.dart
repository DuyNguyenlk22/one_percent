import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 moved `Override` out of the main barrel.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/theme.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

/// Mounts [widget] inside the app's theme and a provider scope.
///
/// [overrides] replaces any provider the widget reaches. Without one for
/// `authRepositoryProvider` the graph would try to build the real HTTP client
/// and `sharedPreferencesProvider`, which deliberately throws outside `main()`.
Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.lightTheme, home: widget),
    ),
  );
  await tester.pumpAndSettle();
}

/// A repository mock that reports "signed out" and never hits the network.
///
/// Enough for any widget test that only needs the page to build.
MockAuthRepository buildSignedOutRepository() {
  final repository = MockAuthRepository();
  when(repository.hasSession).thenAnswer((_) async => false);
  when(() => repository.authStateChanges).thenAnswer((_) => const Stream<User?>.empty());
  return repository;
}

/// The override list a widget test normally needs.
List<Override> signedOutOverrides([AuthRepository? repository]) => [
      authRepositoryProvider.overrideWithValue(repository ?? buildSignedOutRepository()),
    ];
