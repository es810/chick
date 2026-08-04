import 'package:equatable/equatable.dart';

class TreasurySummaryModel extends Equatable {
  const TreasurySummaryModel({
    required this.openingBalance,
    required this.balance,
    required this.totalCollection,
    required this.externalRevenue,
    required this.totalLoading,
    required this.otherExpenses,
    required this.withdrawals,
    this.stockValue = 0,
    this.updatedAt,
    this.updatedByName,
  });

  final double openingBalance;
  final double balance;
  final double totalCollection;
  final double externalRevenue;
  final double totalLoading;
  final double otherExpenses;
  final double withdrawals;
  final double stockValue;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory TreasurySummaryModel.fromJson(Map<String, dynamic> json) {
    return TreasurySummaryModel(
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num).toDouble(),
      totalCollection: (json['totalCollection'] as num?)?.toDouble() ?? 0,
      externalRevenue: (json['externalRevenue'] as num?)?.toDouble() ?? 0,
      totalLoading: (json['totalLoading'] as num?)?.toDouble() ?? 0,
      otherExpenses: (json['otherExpenses'] as num?)?.toDouble() ?? 0,
      withdrawals: (json['withdrawals'] as num?)?.toDouble() ?? 0,
      stockValue: (json['stockValue'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      updatedByName: json['updatedByName'] as String?,
    );
  }

  @override
  List<Object?> get props => [balance, totalCollection, stockValue];
}
