import '../../domain/entities/user.dart';

/// Wire representation of [User].
///
/// Extends the entity so a model is usable anywhere a [User] is, while keeping
/// every mention of JSON inside the data layer.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.createdAt,
  });

  /// Parses the `user` object returned by `/auth/login`, `/auth/register`,
  /// and `/auth/me`.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  /// Serialises for the local cache. The backend never receives this.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Widens an entity into a model, for writing a cached copy.
  factory UserModel.fromEntity(User user) =>
      UserModel(id: user.id, email: user.email, createdAt: user.createdAt);
}
