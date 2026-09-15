import 'package:equatable/equatable.dart';

class ClientModel extends Equatable {
  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.whatsappGroupLink = '',
    this.balance = 0,
    this.email = '',
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  /// WhatsApp group invite/open URL (e.g. https://chat.whatsapp.com/...).
  final String whatsappGroupLink;
  final double balance;
  final String email;

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    String? email = json['email'] as String?;
    if (email == null && json['userId'] is Map) {
      email = (json['userId'] as Map)['email'] as String?;
    }
    return ClientModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String? ?? '',
      whatsappGroupLink: json['whatsappGroupLink'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      email: email ?? '',
    );
  }

  Map<String, dynamic> toJson({String? password}) => {
        if (id.isNotEmpty) '_id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'whatsappGroupLink': whatsappGroupLink,
        'balance': balance,
        if (email.isNotEmpty) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
      };

  @override
  List<Object?> get props => [id, name];
}
