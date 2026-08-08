import 'package:equatable/equatable.dart';

class StockLoadModel extends Equatable {
  const StockLoadModel({
    required this.id,
    required this.stockId,
    required this.chickenType,
    required this.loadedQuantity,
    required this.loadedNetWeight,
    required this.remainingQuantity,
    required this.remainingNetWeight,
    required this.status,
    this.damagedStockId,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final String stockId;
  final String chickenType;
  final int loadedQuantity;
  final double loadedNetWeight;
  final int remainingQuantity;
  final double remainingNetWeight;
  final String status;
  final String? damagedStockId;
  final String? createdByName;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  bool get isPendingWriteOff => status == 'pending_writeoff';

  bool get canFinish =>
      isOpen && (remainingQuantity > 0 || remainingNetWeight > 0);

  factory StockLoadModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final stockIdRaw = json['stockId'];
    final stockId = stockIdRaw is Map
        ? (stockIdRaw['_id'] as String? ?? '')
        : (stockIdRaw as String? ?? '');
    final damagedRaw = json['damagedStockId'];
    final damagedId = damagedRaw is Map
        ? (damagedRaw['_id'] as String?)
        : damagedRaw as String?;

    return StockLoadModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      stockId: stockId,
      chickenType: json['chickenType'] as String? ?? '',
      loadedQuantity: (json['loadedQuantity'] as num?)?.toInt() ?? 0,
      loadedNetWeight: (json['loadedNetWeight'] as num?)?.toDouble() ?? 0,
      remainingQuantity: (json['remainingQuantity'] as num?)?.toInt() ?? 0,
      remainingNetWeight: (json['remainingNetWeight'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'open',
      damagedStockId: damagedId,
      createdByName: createdBy?['name'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, chickenType, status, remainingQuantity, remainingNetWeight];
}
