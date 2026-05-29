import 'package:equatable/equatable.dart';

class StockModel extends Equatable {
  const StockModel({
    required this.id,
    required this.chickenType,
    required this.quantity,
    required this.averageWeight,
    required this.pricePerKg,
    this.lowStockThreshold = 50,
  });

  final String id;
  final String chickenType;
  final int quantity;
  final double averageWeight;
  final double pricePerKg;
  final int lowStockThreshold;

  bool get isLowStock => quantity <= lowStockThreshold;

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      id: (json['_id'] ?? json['id']).toString(),
      chickenType: json['chickenType'] as String,
      quantity: (json['quantity'] as num).toInt(),
      averageWeight: (json['averageWeight'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'chickenType': chickenType,
        'quantity': quantity,
        'averageWeight': averageWeight,
        'pricePerKg': pricePerKg,
      };

  @override
  List<Object?> get props => [id, chickenType, quantity];
}
