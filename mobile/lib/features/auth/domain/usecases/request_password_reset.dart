import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

/// Step 1 of 3: asks the backend to email a reset code.
///
/// Success here means only that the request was accepted. It says nothing about
/// whether the address has an account, and the UI must not imply that it does.
class RequestPasswordReset {
  const RequestPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({required String email}) async {
    final emailError = Validators.email(email);
    if (emailError != null) return ResultError(ValidationFailure(emailError));

    return _repository.requestPasswordReset(email: email.trim());
  }
}
