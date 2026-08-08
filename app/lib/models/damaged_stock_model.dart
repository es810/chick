import 'package:equatable/equatable.dart';

class DamagedStockEntry extends Equatable {
  const DamagedStockEntry({
    required this.id,
    required this.chickenType,
    required this.quantity,
    this.netWeight = 0,
    this.reason = '',
    this.source = 'manual',
    this.status = 'written_off',
    this.recordedByName,
    this.createdAt,
  });

  final String id;
  final String chickenType;
  final int quantity;
  final double netWeight;
  final String reason;
  final String source;
  final String status;
  final String? recordedByName;
  final DateTime? createdAt;

  bool get isDistributionSurplus => source == 'distribution_surplus';

  bool get isDistributionRemainder => source == 'distribution_remainder';

  bool get isLoadDeficit => source == 'load_deficit';

  bool get isDistributionVariance =>
      isDistributionSurplus || isDistributionRemainder || isLoadDeficit;

  bool get isOpenVariance =>
      isDistributionVariance && (status == 'open' || status.isEmpty);

  /// Back-compat alias used by older call sites.
  bool get isOpenSurplus => isOpenVariance;

  factory DamagedStockEntry.fromJson(Map<String, dynamic> json) {
    final recordedBy = json['recordedBy'] as Map<String, dynamic>?;
    final source = json['source'] as String? ?? 'manual';
    final rawStatus = json['status'] as String?;
    final status = rawStatus ??
        (source == 'distribution_surplus' ||
                source == 'distribution_remainder' ||
                source == 'load_deficit'
            ? 'open'
            : 'written_off');

    return DamagedStockEntry(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      chickenType: json['chickenType'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      netWeight: (json['netWeight'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      source: source,
      status: status,
      recordedByName: recordedBy?['name'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, chickenType, quantity, netWeight, source, status];
}
