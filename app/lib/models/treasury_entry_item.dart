class TreasuryEntryItem {
  const TreasuryEntryItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    this.subtitle = '',
    this.createdAt,
    this.clientId,
    this.clientName,
    this.employeeId,
    this.employeeName,
    this.collectionDate,
    this.amountPaid,
    this.amountDeducted,
    this.balanceBefore,
    this.balanceAfter,
  });

  final String id;
  final String category;
  final double amount;
  final String description;
  final String subtitle;
  final DateTime? createdAt;
  final String? clientId;
  final String? clientName;
  final String? employeeId;
  final String? employeeName;
  final DateTime? collectionDate;
  final double? amountPaid;
  final double? amountDeducted;
  final double? balanceBefore;
  final double? balanceAfter;

  bool get isCollectionInvoice => category == 'collection' && clientId != null;

  factory TreasuryEntryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];
    return TreasuryEntryItem(
      id: rawId?.toString() ?? '',
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      clientId: json['clientId']?.toString(),
      clientName: json['clientName'] as String?,
      employeeId: json['employeeId']?.toString(),
      employeeName: json['employeeName'] as String?,
      collectionDate: json['collectionDate'] != null
          ? DateTime.parse(json['collectionDate'] as String)
          : null,
      amountPaid: (json['amountPaid'] as num?)?.toDouble(),
      amountDeducted: (json['amountDeducted'] as num?)?.toDouble(),
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
    );
  }
}

enum TreasuryCategory {
  opening,
  collection,
  externalRevenue,
  loading,
  expense,
  withdrawal,
}

extension TreasuryCategoryApi on TreasuryCategory {
  String get apiValue => switch (this) {
        TreasuryCategory.opening => 'opening',
        TreasuryCategory.collection => 'collection',
        TreasuryCategory.externalRevenue => 'external_revenue',
        TreasuryCategory.loading => 'loading',
        TreasuryCategory.expense => 'expense',
        TreasuryCategory.withdrawal => 'withdrawal',
      };

  bool get needsEmployee => this == TreasuryCategory.loading || this == TreasuryCategory.expense;

  bool get isMovement =>
      this == TreasuryCategory.collection ||
      this == TreasuryCategory.externalRevenue ||
      this == TreasuryCategory.withdrawal;
}
