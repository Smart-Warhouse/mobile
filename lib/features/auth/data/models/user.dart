import '../../../../core/json/json_reader.dart';

/// SV-07 roles: viewer (read only) < operator (tasks, robot commands, E-stop,
/// manual control) < admin.
enum UserRole {
  viewer('viewer'),
  operator('operator'),
  admin('admin'),
  unknown('_unknown');

  const UserRole(this.wire);

  final String wire;

  /// Operator or admin: may command robots, create/cancel tasks, E-stop.
  bool get canOperate => this == operator || this == admin;

  static UserRole parse(String? wire) =>
      values.firstWhere((r) => r.wire == wire, orElse: () => UserRole.unknown);
}

class User {
  const User({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  final int id;
  final String username;
  final String name;
  final UserRole role;

  factory User.fromJson(JsonReader r) => User(
    id: r.reqInt('id'),
    username: r.reqString('username'),
    name: r.string('name', orElse: r.string('username')),
    role: UserRole.parse(r.optString('role')),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'role': role.wire,
  };
}
