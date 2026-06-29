import 'package:equatable/equatable.dart';

class EmployeeTreasurySummary extends Equatable {
  const EmployeeTreasurySummary({
    required this.employeeId,
    required this.employeeName,
    required this.employeePhone,
    required this.balance,
    required this.collection,
    required this.incomingTransfer,
    required this.expenses,
    required this.advances,
    required this.debts,
    required this.outgoingTransfer,
  });

  final String employeeId;
  final String employeeName;
  final String employeePhone;
  final double balance;
  final double collection;
  final double incomingTransfer;
  final double expenses;
  final double advances;
  final double debts;
  final double outgoingTransfer;

  factory EmployeeTreasurySummary.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>?;
    return EmployeeTreasurySummary(
      employeeId: employee?['id']?.toString() ?? '',
      employeeName: employee?['name'] as String? ?? '',
      employeePhone: employee?['phone'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      collection: (json['collection'] as num?)?.toDouble() ?? 0,
      incomingTransfer: (json['incomingTransfer'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      advances: (json['advances'] as num?)?.toDouble() ?? 0,
      debts: (json['debts'] as num?)?.toDouble() ?? 0,
      outgoingTransfer: (json['outgoingTransfer'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [employeeId, balance];
}
