import '../../../../core/errors/result.dart';
import '../entities/user.dart';

/// What the domain layer needs from authentication, stated without reference to
/// HTTP, Dio, or secure storage.
///
/// Implemented by `AuthRepositoryImpl` in the data layer. Every method returns
/// a [Result] rather than throwing, so callers handle both outcomes explicitly.
abstract interface class AuthRepository {
  /// Exchanges credentials for a session and persists the token.
  Future<Result<User>> login({required String email, required String password});

  /// Creates an account and signs the new user in.
  Future<Result<User>> register({required String email, required String password});

  /// Clears the stored session. Succeeds even when already signed out.
  Future<Result<void>> logout();

  /// The signed-in user, or a failure when the session is missing or expired.
  Future<Result<User>> getCurrentUser();

  /// Asks the backend to email a reset code.
  ///
  /// Succeeds for an unregistered address too — the backend refuses to reveal
  /// which addresses have accounts, and the app must not imply otherwise.
  Future<Result<void>> requestPasswordReset({required String email});

  /// Trades the emailed code for a short-lived reset token.
  ///
  /// Every rejection — wrong, expired, or too many attempts — comes back as the
  /// same failure, because the backend deliberately does not distinguish them.
  Future<Result<String>> verifyResetCode({
    required String email,
    required String code,
  });

  /// Sets a new password using the token from [verifyResetCode].
  ///
  /// Does not sign the user in: they return to login and use the new password,
  /// which keeps a single sign-in path.
  Future<Result<void>> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// Whether a token is stored locally.
  ///
  /// A cheap check for the router's initial redirect — it does not prove the
  /// token is still valid, which only [getCurrentUser] can.
  Future<bool> hasSession();

  /// Emits whenever the session changes, so the router can redirect.
  ///
  /// A `null` event means the user signed out or the token was rejected.
  Stream<User?> get authStateChanges;
}
