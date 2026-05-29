import 'package:equatable/equatable.dart';

class ClientModel extends Equatable {
  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.balance = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final double balance;

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
      };

  @override
  List<Object?> get props => [id, name];
}
