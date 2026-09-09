/// An authenticated account.
///
/// Mirrors the backend's `SafeUser` — the Prisma `User` row with `passwordHash`
/// stripped. Pure Dart with no JSON concerns: serialisation lives in
/// `data/models/user_model.dart`, so the domain never depends on the wire
/// format.
class User {
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  /// UUID assigned by the backend.
  final String id;

  final String email;

  /// When the account was created.
  final DateTime createdAt;

  /// A display name derived from the email local part, capitalised.
  ///
  /// The API only ever sends an email, so this is the most the app can honestly
  /// show. Empty when the local part is empty, which callers greet around
  /// rather than substituting a made-up name.
  String get displayName {
    final local = email.split('@').first;
    if (local.isEmpty) return '';
    return '${local[0].toUpperCase()}${local.substring(1)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, email, createdAt);

  @override
  String toString() => 'User(id: $id, email: $email)';
}
