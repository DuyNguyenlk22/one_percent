import 'package:mobile/core/network/network_info.dart';
import 'package:mobile/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile/features/auth/data/models/user_model.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Shared test doubles.
///
/// Mocks live here rather than in individual test files so a change to an
/// interface is fixed once.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

/// A representative user, so tests do not each invent their own.
UserModel buildUserModel({
  String id = '11111111-1111-4111-8111-111111111111',
  String email = 'alex.bloom@example.com',
  DateTime? createdAt,
}) {
  return UserModel(
    id: id,
    email: email,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  );
}

/// Registers fallbacks for any type passed to a mocktail matcher.
/// Call once from a test file's `setUpAll`.
void registerFallbacks() {
  registerFallbackValue(buildUserModel());
}
