import 'package:equatable/equatable.dart';

class SupplierModel extends Equatable {
  const SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    this.location = '',
  });

  final String id;
  final String name;
  final String phone;
  final String location;

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      location: json['location'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'location': location,
      };

  @override
  List<Object?> get props => [id, name];
}
