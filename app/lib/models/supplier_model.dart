import 'package:equatable/equatable.dart';

class SupplierModel extends Equatable {
  const SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    this.location = '',
    this.balance = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String location;
  final double balance;

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      location: json['location'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'location': location,
        'balance': balance,
      };

  @override
  List<Object?> get props => [id, name];
}
