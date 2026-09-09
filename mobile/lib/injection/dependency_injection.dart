/// The app's object graph, as Riverpod providers.
///
/// This file is the one place that knows which concrete class implements each
/// interface. Everything else depends on the interface and reads it from `ref`,
/// so a test swaps an implementation with a `ProviderScope` override:
///
/// ```dart
/// ProviderScope(
///   overrides: [authRepositoryProvider.overrideWithValue(MockAuthRepository())],
///   child: const MyApp(),
/// );
/// ```
///
/// Providers are grouped by layer, outermost first: platform, then core, then
/// per-feature data sources, repositories, and use cases.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/interceptors/auth_interceptor.dart';
import '../core/network/network_info.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/data/datasources/auth_local_datasource.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/get_current_user.dart';
import '../features/auth/domain/usecases/login.dart';
import '../features/auth/domain/usecases/logout.dart';
import '../features/auth/domain/usecases/register.dart';
import '../features/entries/data/datasources/entry_remote_datasource.dart';
import '../features/entries/data/repositories/entry_repository_impl.dart';
import '../features/entries/domain/repositories/entry_repository.dart';
import '../features/entries/domain/usecases/get_entries.dart';
import '../features/entries/domain/usecases/set_entry.dart';
import '../features/habits/data/datasources/habit_remote_datasource.dart';
import '../features/habits/data/repositories/habit_repository_impl.dart';
import '../features/habits/domain/repositories/habit_repository.dart';
import '../features/habits/domain/usecases/create_habit.dart';
import '../features/habits/domain/usecases/delete_habit.dart';
import '../features/habits/domain/usecases/get_daily_habits.dart';
import '../features/habits/domain/usecases/update_habit.dart';


// ---------------------------------------------------------------------------
// Platform
// ---------------------------------------------------------------------------

/// Resolved in `main()` and injected via an override, because
/// `SharedPreferences.getInstance()` is asynchronous and providers are not.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() — see bootstrap().',
  );
});

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------

final localStorageProvider = Provider<LocalStorage>(
  (ref) => LocalStorage(ref.watch(sharedPreferencesProvider)),
);

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final networkInfoProvider = Provider<NetworkInfo>((ref) => const NetworkInfoImpl());

/// Counts the times the backend has rejected the bearer token.
///
/// A counter rather than a flag: two 401s in a row must both be observable,
/// and a counter is the simplest value that changes every time. `AuthNotifier`
/// listens and flips to unauthenticated, which the router picks up.
class SessionExpiryNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Called by [AuthInterceptor] once it has cleared the rejected token.
  void expire() => state = state + 1;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiryNotifier, int>(SessionExpiryNotifier.new);

/// The configured HTTP client, with the auth interceptor already attached.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    interceptors: [
      AuthInterceptor(
        secureStorage: ref.watch(secureStorageProvider),
        // Closes the loop the interceptor cannot close on its own: it clears
        // the token, this tells the router.
        onUnauthorized: () =>
            ref.read(sessionExpiredProvider.notifier).expire(),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Feature: auth
// ---------------------------------------------------------------------------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSourceImpl(
    secureStorage: ref.watch(secureStorageProvider),
    localStorage: ref.watch(localStorageProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final loginUseCaseProvider = Provider<Login>(
  (ref) => Login(ref.watch(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<Register>(
  (ref) => Register(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<Logout>(
  (ref) => Logout(ref.watch(authRepositoryProvider)),
);

final getCurrentUserUseCaseProvider = Provider<GetCurrentUser>(
  (ref) => GetCurrentUser(ref.watch(authRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Feature: habits
// ---------------------------------------------------------------------------

final habitRemoteDataSourceProvider = Provider<HabitRemoteDataSource>(
  (ref) => HabitRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepositoryImpl(
    remoteDataSource: ref.watch(habitRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final getDailyHabitsUseCaseProvider = Provider<GetDailyHabits>(
  (ref) => GetDailyHabits(ref.watch(habitRepositoryProvider)),
);

final createHabitUseCaseProvider = Provider<CreateHabit>(
  (ref) => CreateHabit(ref.watch(habitRepositoryProvider)),
);

final updateHabitUseCaseProvider = Provider<UpdateHabit>(
  (ref) => UpdateHabit(ref.watch(habitRepositoryProvider)),
);

final deleteHabitUseCaseProvider = Provider<DeleteHabit>(
  (ref) => DeleteHabit(ref.watch(habitRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Feature: entries
// ---------------------------------------------------------------------------

final entryRemoteDataSourceProvider = Provider<EntryRemoteDataSource>(
  (ref) => EntryRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepositoryImpl(
    remoteDataSource: ref.watch(entryRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final setEntryUseCaseProvider = Provider<SetEntry>(
  (ref) => SetEntry(ref.watch(entryRepositoryProvider)),
);

final getEntriesUseCaseProvider = Provider<GetEntries>(
  (ref) => GetEntries(ref.watch(entryRepositoryProvider)),
);
