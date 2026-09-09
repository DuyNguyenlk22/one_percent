import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/validators.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Creates an account and signs the new user in.
///
/// When [confirmPassword] is supplied it must match [password]; the backend has
/// no such field, so the check belongs here.
class Register {
  const Register(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call({
    required String email,
    required String password,
    String? confirmPassword,
  }) async {
    final emailError = Validators.email(email);
    if (emailError != null) return ResultError(ValidationFailure(emailError));

    final passwordError = Validators.password(password);
    if (passwordError != null) return ResultError(ValidationFailure(passwordError));

    if (confirmPassword != null) {
      final mismatch = Validators.confirmPassword(confirmPassword, password);
      if (mismatch != null) return ResultError(ValidationFailure(mismatch));
    }

    return _repository.register(email: email.trim(), password: password);
  }
}
