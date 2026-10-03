import 'package:equatable/equatable.dart';

class DailyProfitRow extends Equatable {
  const DailyProfitRow({
    required this.date,
    required this.revenue,
    required this.loading,
    required this.expenses,
    required this.discount,
    required this.profit,
  });

  final String date;
  final double revenue;
  final double loading;
  final double expenses;
  final double discount;
  final double profit;

  factory DailyProfitRow.fromJson(Map<String, dynamic> json) {
    return DailyProfitRow(
      date: json['date']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      loading: (json['loading'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [date, profit];
}

class MonthlyProfitStatement extends Equatable {
  const MonthlyProfitStatement({
    required this.year,
    required this.month,
    required this.days,
    required this.revenue,
    required this.loading,
    required this.expenses,
    required this.discount,
    required this.dailyProfitsTotal,
    required this.salaryAdvances,
    required this.profit,
  });

  final int year;
  final int month;
  final List<DailyProfitRow> days;
  final double revenue;
  final double loading;
  final double expenses;
  final double discount;
  final double dailyProfitsTotal;
  final double salaryAdvances;
  final double profit;

  factory MonthlyProfitStatement.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final daysRaw = json['days'] as List? ?? [];
    return MonthlyProfitStatement(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      days: daysRaw
          .map((e) => DailyProfitRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      revenue: (summary['revenue'] as num?)?.toDouble() ?? 0,
      loading: (summary['loading'] as num?)?.toDouble() ?? 0,
      expenses: (summary['expenses'] as num?)?.toDouble() ?? 0,
      discount: (summary['discount'] as num?)?.toDouble() ?? 0,
      dailyProfitsTotal: (summary['dailyProfitsTotal'] as num?)?.toDouble() ?? 0,
      salaryAdvances: (summary['salaryAdvances'] as num?)?.toDouble() ?? 0,
      profit: (summary['profit'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [year, month, days.length, profit];
}
