import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/validators.dart';
import '../repositories/auth_repository.dart';

/// Step 3 of 3: sets the new password.
///
/// [confirmPassword], when supplied, must match — the backend has no such
/// field, so the check belongs here, exactly as it does in `Register`.
class ResetPassword {
  const ResetPassword(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required String resetToken,
    required String newPassword,
    String? confirmPassword,
  }) async {
    if (resetToken.trim().isEmpty) {
      return const ResultError(
        ValidationFailure('Verify your code again before setting a password'),
      );
    }

    final passwordError = Validators.password(newPassword);
    if (passwordError != null) return ResultError(ValidationFailure(passwordError));

    if (confirmPassword != null) {
      final mismatch = Validators.confirmPassword(confirmPassword, newPassword);
      if (mismatch != null) return ResultError(ValidationFailure(mismatch));
    }

    return _repository.resetPassword(
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }
}
