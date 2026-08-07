import 'package:equatable/equatable.dart';

class ProfitSummary extends Equatable {
  const ProfitSummary({
    required this.revenue,
    required this.loading,
    required this.expenses,
    required this.discount,
    required this.profit,
    this.withdrawals = 0,
  });

  final double revenue;
  final double loading;
  final double expenses;
  final double discount;
  final double profit;
  final double withdrawals;

  factory ProfitSummary.fromJson(Map<String, dynamic> json) {
    return ProfitSummary(
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      loading: (json['loading'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      withdrawals: (json['withdrawals'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [profit];
}

class MonthlyProfitSummary extends Equatable {
  const MonthlyProfitSummary({
    required this.profit,
    required this.dailyProfitsTotal,
    required this.salaries,
    required this.year,
    required this.month,
    this.loading = 0,
  });

  final double profit;
  final double dailyProfitsTotal;
  final double salaries;
  final int year;
  final int month;
  final double loading;

  factory MonthlyProfitSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? {};
    return MonthlyProfitSummary(
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      dailyProfitsTotal: (json['dailyProfitsTotal'] as num?)?.toDouble() ?? 0,
      salaries: (json['salaries'] as num?)?.toDouble() ??
          (json['salaryAdvances'] as num?)?.toDouble() ??
          0,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      loading: (breakdown['loading'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [profit, year, month];
}

class DashboardData extends Equatable {
  const DashboardData({
    required this.dailyProfit,
    required this.monthlyProfit,
    required this.monthlyInvoices,
    required this.pendingPayments,
    required this.damagedStockQuantity,
    this.damagedStockNetWeight = 0,
    required this.recentInvoices,
    required this.mainTreasuryBalance,
    this.mainTreasuryUpdatedAt,
    this.mainTreasuryUpdatedBy,
    required this.receivables,
  });

  final ProfitSummary dailyProfit;
  final MonthlyProfitSummary monthlyProfit;
  final int monthlyInvoices;
  final int pendingPayments;
  final int damagedStockQuantity;
  final double damagedStockNetWeight;
  final List<Map<String, dynamic>> recentInvoices;
  final double mainTreasuryBalance;
  final DateTime? mainTreasuryUpdatedAt;
  final String? mainTreasuryUpdatedBy;
  final double receivables;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final stats = json['monthlyStats'] as Map<String, dynamic>? ?? {};
    final damaged = json['damagedStock'] as Map<String, dynamic>? ?? {};
    final recent = json['recentInvoices'] as List? ?? [];
    final mainTreasury = json['mainTreasury'] as Map<String, dynamic>? ?? {};
    final daily = json['dailyProfit'] as Map<String, dynamic>? ?? {};
    final monthly = json['monthlyProfit'] as Map<String, dynamic>? ?? {};

    return DashboardData(
      dailyProfit: ProfitSummary.fromJson(daily),
      monthlyProfit: MonthlyProfitSummary.fromJson(monthly),
      monthlyInvoices: (stats['count'] as num?)?.toInt() ?? 0,
      pendingPayments: (stats['pending'] as num?)?.toInt() ?? 0,
      damagedStockQuantity: (damaged['totalQuantity'] as num?)?.toInt() ?? 0,
      damagedStockNetWeight: (damaged['totalNetWeight'] as num?)?.toDouble() ?? 0,
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
