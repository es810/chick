import 'package:equatable/equatable.dart';

enum UserRole { admin, employee, client }

class EmployeePermissions extends Equatable {
  const EmployeePermissions({
    this.canEditInvoices = true,
    this.canViewOthersWork = false,
    this.canTransfer = false,
    this.canAddExpense = true,
    this.canPaySupplier = true,
  });

  final bool canEditInvoices;
  final bool canViewOthersWork;
  final bool canTransfer;
  final bool canAddExpense;
  final bool canPaySupplier;

  factory EmployeePermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EmployeePermissions();
    return EmployeePermissions(
      canEditInvoices: json['canEditInvoices'] as bool? ?? true,
      canViewOthersWork: json['canViewOthersWork'] as bool? ?? false,
      canTransfer: json['canTransfer'] as bool? ?? false,
      canAddExpense: json['canAddExpense'] as bool? ?? true,
      canPaySupplier: json['canPaySupplier'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'canEditInvoices': canEditInvoices,
        'canViewOthersWork': canViewOthersWork,
        'canTransfer': canTransfer,
        'canAddExpense': canAddExpense,
        'canPaySupplier': canPaySupplier,
      };

  EmployeePermissions copyWith({
    bool? canEditInvoices,
    bool? canViewOthersWork,
    bool? canTransfer,
    bool? canAddExpense,
    bool? canPaySupplier,
  }) {
    return EmployeePermissions(
      canEditInvoices: canEditInvoices ?? this.canEditInvoices,
      canViewOthersWork: canViewOthersWork ?? this.canViewOthersWork,
      canTransfer: canTransfer ?? this.canTransfer,
      canAddExpense: canAddExpense ?? this.canAddExpense,
      canPaySupplier: canPaySupplier ?? this.canPaySupplier,
    );
  }

  @override
  List<Object?> get props => [
        canEditInvoices,
        canViewOthersWork,
        canTransfer,
        canAddExpense,
        canPaySupplier,
      ];
}

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
    this.permissions = const EmployeePermissions(),
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final String? clientProfile;
  final bool isActive;
  final double salary;
  final EmployeePermissions permissions;

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
      permissions: EmployeePermissions.fromJson(
        json['permissions'] is Map
            ? Map<String, dynamic>.from(json['permissions'] as Map)
            : null,
      ),
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
        'permissions': permissions.toJson(),
      };

  @override
  List<Object?> get props => [id, email, role, permissions];
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
