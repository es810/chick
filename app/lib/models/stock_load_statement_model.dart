import 'package:equatable/equatable.dart';
import 'stock_load_model.dart';

class StockLoadStatementTotals extends Equatable {
  const StockLoadStatementTotals({
    required this.distributedQuantity,
    required this.distributedNetWeight,
    required this.distributedAmount,
    required this.unpaidAmount,
    required this.invoiceCount,
  });

  final int distributedQuantity;
  final double distributedNetWeight;
  final double distributedAmount;
  final double unpaidAmount;
  final int invoiceCount;

  factory StockLoadStatementTotals.fromJson(Map<String, dynamic> json) {
    return StockLoadStatementTotals(
      distributedQuantity: (json['distributedQuantity'] as num?)?.toInt() ?? 0,
      distributedNetWeight:
          (json['distributedNetWeight'] as num?)?.toDouble() ?? 0,
      distributedAmount: (json['distributedAmount'] as num?)?.toDouble() ?? 0,
      unpaidAmount: (json['unpaidAmount'] as num?)?.toDouble() ?? 0,
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [distributedQuantity, distributedNetWeight, invoiceCount];
}

class StockLoadStatementEntry extends Equatable {
  const StockLoadStatementEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.subtitle,
    required this.quantity,
    required this.netWeight,
    required this.amount,
    this.invoiceNumber,
    this.clientId = '',
    this.clientName = '',
    this.paymentStatus = '',
    this.source,
    this.status,
  });

  final String id;
  final String type;
  final DateTime date;
  final String description;
  final String subtitle;
  final int quantity;
  final double netWeight;
  final double amount;
  final String? invoiceNumber;
  final String clientId;
  final String clientName;
  final String paymentStatus;
  final String? source;
  final String? status;

  bool get isDistribution => type == 'distribution';

  factory StockLoadStatementEntry.fromJson(Map<String, dynamic> json) {
    return StockLoadStatementEntry(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      description: json['description']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      netWeight: (json['netWeight'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      invoiceNumber: json['invoiceNumber']?.toString(),
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      source: json['source']?.toString(),
      status: json['status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, type, quantity, amount];
}

class StockLoadStatement extends Equatable {
  const StockLoadStatement({
    required this.load,
    required this.totals,
    required this.entries,
  });

  final StockLoadModel load;
  final StockLoadStatementTotals totals;
  final List<StockLoadStatementEntry> entries;

  factory StockLoadStatement.fromJson(Map<String, dynamic> json) {
    final loadRaw = Map<String, dynamic>.from(json['load'] as Map? ?? {});
    // Normalize id field for StockLoadModel.fromJson
    if (loadRaw['id'] != null && loadRaw['_id'] == null) {
      loadRaw['_id'] = loadRaw['id'];
    }
    loadRaw.putIfAbsent('stockId', () => '');
    return StockLoadStatement(
      load: StockLoadModel.fromJson(loadRaw),
      totals: StockLoadStatementTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? {}),
      ),
      entries: (json['entries'] as List? ?? [])
          .map(
            (e) => StockLoadStatementEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [load.id, totals, entries.length];
}
