import '../../../../core/errors/result.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Resolves the signed-in user, used on startup to restore a session.
class GetCurrentUser {
  const GetCurrentUser(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call() => _repository.getCurrentUser();
}
