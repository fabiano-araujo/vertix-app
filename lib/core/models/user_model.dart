/// User Model
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? username;
  final String? photo;
  final String role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.photo,
    this.role = 'USER',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      photo: json['photo'] as String?,
      role: json['role'] as String? ?? 'USER',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'photo': photo,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isCreator => role == 'CREATOR' || role == 'ADMIN';
  String get displayName => username ?? name;

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? username,
    String? photo,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      photo: photo ?? this.photo,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Auth Response
class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final UserModel? user;

  AuthResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      token: json['token'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
