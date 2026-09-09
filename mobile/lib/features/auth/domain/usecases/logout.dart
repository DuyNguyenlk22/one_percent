import '../../../../core/errors/result.dart';
import '../repositories/auth_repository.dart';

/// Ends the session and clears the stored token.
class Logout {
  const Logout(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}
