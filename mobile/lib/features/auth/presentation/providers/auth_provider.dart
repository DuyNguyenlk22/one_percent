import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../injection/dependency_injection.dart';
import '../../domain/entities/user.dart';

/// Where the app is in the sign-in lifecycle.
enum AuthStatus {
  /// Startup: the stored session has not been checked yet. The router holds
  /// on the splash screen while this is the status.
  unknown,

  /// A valid session exists.
  authenticated,

  /// No session, or the stored one was rejected.
  unauthenticated,
}

/// State exposed to the auth pages.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.failure,
  });

  final AuthStatus status;

  /// The signed-in user, `null` unless [status] is
  /// [AuthStatus.authenticated].
  final User? user;

  /// True while a login or register request is in flight.
  final bool isSubmitting;

  /// The last failure, cleared when a new submission starts.
  final Failure? failure;

  /// Message for the error banner, or `null` when there is nothing to show.
  String? get errorMessage => failure?.message;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Copies the state. [failure] is cleared unless explicitly passed, because
  /// a stale error must not survive the next submission.
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isSubmitting,
    Failure? failure,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure,
    );
  }
}

/// Drives sign-in, registration, and sign-out.
///
/// Calls use cases only; it never touches Dio or storage, which is what keeps
/// it testable with a mocked repository.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Restore the session once, right after the first frame is scheduled.
    Future.microtask(restoreSession);
    return const AuthState();
  }

  /// Loads the stored session on startup.
  ///
  /// Skips the network call when no token is stored, so a first launch does
  /// not wait on a request that is certain to fail.
  Future<void> restoreSession() async {
    final repository = ref.read(authRepositoryProvider);
    if (!await repository.hasSession()) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final result = await ref.read(getCurrentUserUseCaseProvider)();
    state = switch (result) {
      Success(:final data) => AuthState(status: AuthStatus.authenticated, user: data),
      ResultError() => const AuthState(status: AuthStatus.unauthenticated),
    };
  }

  /// Signs in. Returns true when the user is authenticated afterwards.
  Future<bool> login({required String email, required String password}) {
    return _submit(() => ref.read(loginUseCaseProvider)(email: email, password: password));
  }

  /// Creates an account and signs in.
  Future<bool> register({
    required String email,
    required String password,
    String? confirmPassword,
  }) {
    return _submit(
      () => ref.read(registerUseCaseProvider)(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      ),
    );
  }

  /// Signs out and returns the app to the unauthenticated state.
  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider)();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Dismisses the error banner without changing anything else.
  void clearError() => state = state.copyWith(failure: null);

  Future<bool> _submit(Future<Result<User>> Function() action) async {
    state = state.copyWith(isSubmitting: true);

    final result = await action();
    switch (result) {
      case Success(:final data):
        state = AuthState(status: AuthStatus.authenticated, user: data);
        return true;
      case ResultError(:final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }
}

/// The app's auth state. Pages watch this; the router listens to it.
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The signed-in user, or `null`. A convenience for widgets that need only
/// the profile and should not rebuild on submission-state changes.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authNotifierProvider.select((state) => state.user));
});
