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

/// The configured HTTP client, with the auth interceptor already attached.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    interceptors: [
      AuthInterceptor(secureStorage: ref.watch(secureStorageProvider)),
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
