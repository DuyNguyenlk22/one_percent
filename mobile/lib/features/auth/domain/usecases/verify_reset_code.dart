import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

/// Step 2 of 3: trades the emailed code for a short-lived reset token.
///
/// The shape check runs locally first because the backend allows only five
/// attempts per code — a half-typed code must not burn one of them.
class VerifyResetCode {
  const VerifyResetCode(this._repository);

  final AuthRepository _repository;

  Future<Result<String>> call({
    required String email,
    required String code,
  }) async {
    final emailError = Validators.email(email);
    if (emailError != null) return ResultError(ValidationFailure(emailError));

    final codeError = Validators.resetCode(code);
    if (codeError != null) return ResultError(ValidationFailure(codeError));

    return _repository.verifyResetCode(email: email.trim(), code: code.trim());
  }
}
