class AccountStatementEntity {
  const AccountStatementEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
  });

  final String id;
  final String name;
  final String phone;
  final double balance;

  factory AccountStatementEntity.fromJson(Map<String, dynamic> json) {
    return AccountStatementEntity(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AccountStatementEntry {
  const AccountStatementEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.description,
    required this.subtitle,
    required this.debit,
    required this.credit,
    this.balanceAfter,
    this.reference,
  });

  final String id;
  final String type;
  final DateTime date;
  final String description;
  final String subtitle;
  final double debit;
  final double credit;
  final double? balanceAfter;
  final String? reference;

  factory AccountStatementEntry.fromJson(Map<String, dynamic> json) {
    return AccountStatementEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
      reference: json['reference']?.toString(),
    );
  }
}

class AccountStatement {
  const AccountStatement({
    required this.entity,
    required this.entries,
  });

  final AccountStatementEntity entity;
  final List<AccountStatementEntry> entries;

  factory AccountStatement.fromJson(Map<String, dynamic> json) {
    return AccountStatement(
      entity: AccountStatementEntity.fromJson(json['entity'] as Map<String, dynamic>),
      entries: (json['entries'] as List? ?? [])
          .map((e) => AccountStatementEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
