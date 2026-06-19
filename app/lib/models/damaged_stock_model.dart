import 'package:equatable/equatable.dart';

class DamagedStockEntry extends Equatable {
  const DamagedStockEntry({
    required this.id,
    required this.chickenType,
    required this.quantity,
    this.reason = '',
    this.recordedByName,
    this.createdAt,
  });

  final String id;
  final String chickenType;
  final int quantity;
  final String reason;
  final String? recordedByName;
  final DateTime? createdAt;

  factory DamagedStockEntry.fromJson(Map<String, dynamic> json) {
    final recordedBy = json['recordedBy'] as Map<String, dynamic>?;
    return DamagedStockEntry(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      chickenType: json['chickenType'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      recordedByName: recordedBy?['name'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, chickenType, quantity];
}
