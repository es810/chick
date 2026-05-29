import 'package:equatable/equatable.dart';

class StockModel extends Equatable {
  const StockModel({
    required this.id,
    required this.chickenType,
    required this.quantity,
    required this.averageWeight,
    required this.pricePerKg,
    this.location = '',
    this.tareWeight = 0,
    this.netWeight = 0,
    this.totalAmount = 0,
    this.lowStockThreshold = 50,
  });

  final String id;
  final String location;
  final String chickenType;
  final int quantity;
  final double tareWeight;
  final double netWeight;
  final double averageWeight;
  final double pricePerKg;
  final double totalAmount;
  final int lowStockThreshold;

  bool get isLowStock => quantity <= lowStockThreshold;

  double get displayTotal =>
      totalAmount > 0 ? totalAmount : pricePerKg * netWeight;

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      id: (json['_id'] ?? json['id']).toString(),
      location: json['location'] as String? ?? '',
      chickenType: json['chickenType'] as String,
      quantity: (json['quantity'] as num).toInt(),
      tareWeight: (json['tareWeight'] as num?)?.toDouble() ?? 0,
      netWeight: (json['netWeight'] as num?)?.toDouble() ?? 0,
      averageWeight: (json['averageWeight'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'chickenType': chickenType,
        'quantity': quantity,
        'tareWeight': tareWeight,
        'netWeight': netWeight,
        'averageWeight': averageWeight,
        'pricePerKg': pricePerKg,
        'totalAmount': totalAmount,
      };

  @override
  List<Object?> get props => [id, chickenType, quantity];
}
