import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Signs an existing user in.
///
/// Validates locally before spending a round trip, then delegates to the
/// repository. A use case holds one operation's rules, which keeps that logic
/// out of the notifier and makes it testable without a widget tree.
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call({required String email, required String password}) async {
    final emailError = Validators.email(email);
    if (emailError != null) return ResultError(ValidationFailure(emailError));

    final passwordError = Validators.password(password);
    if (passwordError != null) return ResultError(ValidationFailure(passwordError));

    return _repository.login(email: email.trim(), password: password);
  }
}
