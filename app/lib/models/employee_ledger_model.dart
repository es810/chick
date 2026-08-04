import 'package:equatable/equatable.dart';

class EmployeeLedgerEntry extends Equatable {
  const EmployeeLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.supplierId,
    this.supplierName,
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String description;
  final String? supplierId;
  final String? supplierName;
  final String? createdByName;
  final DateTime? createdAt;

  bool get isExpense => type == 'expense';
  bool get isDebt => type == 'debt';

  factory EmployeeLedgerEntry.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    final supplier = json['supplierId'];
    return EmployeeLedgerEntry(
      id: json['_id'] as String? ?? json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      supplierId: supplier is Map
          ? supplier['_id']?.toString() ?? supplier['id']?.toString()
          : supplier?.toString(),
      supplierName: supplier is Map ? supplier['name'] as String? : null,
      createdByName: createdBy is Map ? createdBy['name'] as String? : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [id, type, amount, supplierId];
}

class SalaryAdvanceEntry extends Equatable {
  const SalaryAdvanceEntry({
    required this.id,
    required this.amount,
    required this.advanceDate,
    this.notes = '',
    this.createdByName,
    this.createdAt,
  });

  final String id;
  final double amount;
  final DateTime advanceDate;
  final String notes;
  final String? createdByName;
  final DateTime? createdAt;

  factory SalaryAdvanceEntry.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    return SalaryAdvanceEntry(
      id: json['_id'] as String? ?? json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      advanceDate: DateTime.parse(json['advanceDate'] as String),
      notes: json['notes'] as String? ?? '',
      createdByName: createdBy is Map ? createdBy['name'] as String? : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [id, amount, advanceDate];
}

class EmployeeLedgerSummary extends Equatable {
  const EmployeeLedgerSummary({
    required this.employeeId,
    required this.employeeName,
    required this.employeeSalary,
    required this.totalExpenses,
    required this.totalDebt,
    required this.totalAdvances,
    required this.treasuryBalance,
    required this.entries,
    required this.advances,
  });

  final String employeeId;
  final String employeeName;
  final double employeeSalary;
  final double totalExpenses;
  final double totalDebt;
  final double totalAdvances;
  final double treasuryBalance;
  final List<EmployeeLedgerEntry> entries;
  final List<SalaryAdvanceEntry> advances;

  factory EmployeeLedgerSummary.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>;
    final entries = json['entries'] as List? ?? [];
    final advances = json['advances'] as List? ?? [];
    final treasury = json['treasury'] as Map<String, dynamic>?;
    return EmployeeLedgerSummary(
      employeeId: employee['_id']?.toString() ?? employee['id']?.toString() ?? '',
      employeeName: employee['name'] as String? ?? '',
      employeeSalary: (employee['salary'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0,
      totalAdvances: (json['totalAdvances'] as num?)?.toDouble() ?? 0,
      treasuryBalance: (json['treasuryBalance'] as num?)?.toDouble() ??
          (treasury?['balance'] as num?)?.toDouble() ??
          0,
      entries: entries
          .map((e) => EmployeeLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      advances: advances
          .map((e) => SalaryAdvanceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [employeeId, totalExpenses, totalDebt, totalAdvances, treasuryBalance];
}
