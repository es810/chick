import 'package:equatable/equatable.dart';

enum UserRole { admin, employee, client }

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.clientProfile,
    this.isActive = true,
    this.salary = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final String? clientProfile;
  final bool isActive;
  final double salary;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == (json['role'] as String),
        orElse: () => UserRole.employee,
      ),
      clientProfile: json['clientProfile'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      salary: (json['salary'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'clientProfile': clientProfile,
        'isActive': isActive,
        'salary': salary,
      };

  @override
  List<Object?> get props => [id, email, role];
}

class AuthResponse extends Equatable {
  const AuthResponse({required this.user, required this.token});

  final UserModel user;
  final String token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }

  @override
  List<Object?> get props => [user, token];
}
