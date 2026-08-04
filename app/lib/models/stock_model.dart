import 'package:equatable/equatable.dart';

class StockModel extends Equatable {
  const StockModel({
    required this.id,
    required this.chickenType,
    required this.quantity,
    required this.averageWeight,
    required this.pricePerKg,
    this.location = '',
    this.grossWeight = 0,
    this.tareWeight = 0,
    this.netWeight = 0,
    this.totalAmount = 0,
    this.lowStockThreshold = 50,
    this.pendingSurplusQuantity = 0,
    this.pendingSurplusNetWeight = 0,
    int? usableQuantity,
    double? usableNetWeight,
  })  : usableQuantity = usableQuantity ??
            ((quantity - pendingSurplusQuantity) < 0
                ? 0
                : quantity - pendingSurplusQuantity),
        usableNetWeight = usableNetWeight ??
            (((netWeight - pendingSurplusNetWeight) < 0
                    ? 0
                    : netWeight - pendingSurplusNetWeight));

  final String id;
  final String location;
  final String chickenType;
  final int quantity;
  final double grossWeight;
  final double tareWeight;
  final double netWeight;
  final double averageWeight;
  final double pricePerKg;
  final double totalAmount;
  final int lowStockThreshold;

  /// Oversold count not yet written off (هلك).
  final int pendingSurplusQuantity;

  /// Oversold kg not yet written off (هلك).
  final double pendingSurplusNetWeight;

  /// Book stock minus open surplus — «عندي مخزون».
  final int usableQuantity;

  /// Book net weight minus open surplus kg.
  final double usableNetWeight;

  bool get isLowStock => usableQuantity <= lowStockThreshold;

  bool get hasPendingSurplus =>
      pendingSurplusQuantity > 0 || pendingSurplusNetWeight > 0;

  double get displayTotal =>
      totalAmount > 0 ? totalAmount : pricePerKg * netWeight;

  factory StockModel.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 0;
    final netWeight = (json['netWeight'] as num?)?.toDouble() ?? 0;
    final pendingQty = (json['pendingSurplusQuantity'] as num?)?.toInt() ?? 0;
    final pendingKg =
        (json['pendingSurplusNetWeight'] as num?)?.toDouble() ?? 0;
    final usableQty = (json['usableQuantity'] as num?)?.toInt() ??
        (quantity - pendingQty < 0 ? 0 : quantity - pendingQty);
    final usableKg = (json['usableNetWeight'] as num?)?.toDouble() ??
        (netWeight - pendingKg < 0 ? 0 : netWeight - pendingKg);

    return StockModel(
      id: (json['_id'] ?? json['id']).toString(),
      location: json['location'] as String? ?? '',
      chickenType: json['chickenType'] as String,
      quantity: quantity,
      grossWeight: (json['grossWeight'] as num?)?.toDouble() ?? 0,
      tareWeight: (json['tareWeight'] as num?)?.toDouble() ?? 0,
      netWeight: netWeight,
      averageWeight: (json['averageWeight'] as num?)?.toDouble() ?? 0,
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 50,
      pendingSurplusQuantity: pendingQty,
      pendingSurplusNetWeight: pendingKg,
      usableQuantity: usableQty,
      usableNetWeight: usableKg,
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'chickenType': chickenType,
        'quantity': quantity,
        'grossWeight': grossWeight,
        'tareWeight': tareWeight,
        'netWeight': netWeight,
        'averageWeight': averageWeight,
        'pricePerKg': pricePerKg,
        'totalAmount': totalAmount,
      };

  @override
  List<Object?> get props => [id, chickenType, quantity, usableQuantity];
}
