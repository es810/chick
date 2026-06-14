import 'package:equatable/equatable.dart';

class ProfitSummary extends Equatable {
  const ProfitSummary({
    required this.revenue,
    required this.loading,
    required this.expenses,
    required this.discount,
    required this.profit,
  });

  final double revenue;
  final double loading;
  final double expenses;
  final double discount;
  final double profit;

  factory ProfitSummary.fromJson(Map<String, dynamic> json) {
    return ProfitSummary(
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      loading: (json['loading'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [profit];
}

class DashboardData extends Equatable {
  const DashboardData({
    required this.dailyProfit,
    required this.monthlyProfit,
    required this.monthlyInvoices,
    required this.pendingPayments,
    required this.lowStockCount,
    required this.recentInvoices,
    required this.mainTreasuryBalance,
    this.mainTreasuryUpdatedAt,
    this.mainTreasuryUpdatedBy,
    required this.receivables,
  });

  final ProfitSummary dailyProfit;
  final double monthlyProfit;
  final int monthlyInvoices;
  final int pendingPayments;
  final int lowStockCount;
  final List<Map<String, dynamic>> recentInvoices;
  final double mainTreasuryBalance;
  final DateTime? mainTreasuryUpdatedAt;
  final String? mainTreasuryUpdatedBy;
  final double receivables;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final stats = json['monthlyStats'] as Map<String, dynamic>? ?? {};
    final alerts = json['lowStockAlerts'] as List? ?? [];
    final recent = json['recentInvoices'] as List? ?? [];
    final mainTreasury = json['mainTreasury'] as Map<String, dynamic>? ?? {};
    final daily = json['dailyProfit'] as Map<String, dynamic>? ?? {};
    final monthly = json['monthlyProfit'] as Map<String, dynamic>? ?? {};

    return DashboardData(
      dailyProfit: ProfitSummary.fromJson(daily),
      monthlyProfit: (monthly['profit'] as num?)?.toDouble() ??
          (stats['revenue'] as num?)?.toDouble() ??
          0,
      monthlyInvoices: (stats['count'] as num?)?.toInt() ?? 0,
      pendingPayments: (stats['pending'] as num?)?.toInt() ?? 0,
      lowStockCount: alerts.length,
      recentInvoices: recent.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      mainTreasuryBalance: (mainTreasury['balance'] as num?)?.toDouble() ?? 0,
      mainTreasuryUpdatedAt: mainTreasury['updatedAt'] != null
          ? DateTime.parse(mainTreasury['updatedAt'] as String)
          : null,
      mainTreasuryUpdatedBy: mainTreasury['updatedByName'] as String?,
      receivables: (json['receivables'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [dailyProfit, monthlyProfit, monthlyInvoices, mainTreasuryBalance];
}

class SalesReportItem extends Equatable {
  const SalesReportItem({
    required this.date,
    required this.totalSales,
    required this.invoiceCount,
  });

  final String date;
  final double totalSales;
  final int invoiceCount;

  factory SalesReportItem.fromJson(Map<String, dynamic> json) {
    return SalesReportItem(
      date: json['_id'] as String,
      totalSales: (json['totalSales'] as num).toDouble(),
      invoiceCount: (json['invoiceCount'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [date, totalSales];
}
