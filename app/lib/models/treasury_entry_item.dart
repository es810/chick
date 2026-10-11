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
    this.clientPhone,
    this.clientWhatsappGroupLink,
    this.employeeId,
    this.employeeName,
    this.collectionDate,
    this.amountPaid,
    this.amountDeducted,
    this.balanceBefore,
    this.balanceAfter,
    this.readOnly = false,
  });

  final String id;
  final String category;
  final double amount;
  final String description;
  final String subtitle;
  final DateTime? createdAt;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? clientWhatsappGroupLink;
  final String? employeeId;
  final String? employeeName;
  final DateTime? collectionDate;
  final double? amountPaid;
  final double? amountDeducted;
  final double? balanceBefore;
  final double? balanceAfter;
  final bool readOnly;

  bool get isCollectionInvoice => category == 'collection' && clientId != null;

  factory TreasuryEntryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];
    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final amountPaid = asDouble(json['amountPaid']);
    final amount = asDouble(json['amount']) ?? amountPaid ?? 0;

    return TreasuryEntryItem(
      id: rawId?.toString() ?? '',
      category: json['category']?.toString() ?? 'collection',
      amount: amount,
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      clientId: json['clientId']?.toString(),
      clientName: json['clientName']?.toString(),
      clientPhone: json['clientPhone']?.toString(),
      clientWhatsappGroupLink: json['clientWhatsappGroupLink']?.toString(),
      employeeId: json['employeeId']?.toString(),
      employeeName: json['employeeName']?.toString(),
      collectionDate: json['collectionDate'] != null
          ? DateTime.tryParse(json['collectionDate'].toString())
          : null,
      amountPaid: amountPaid ?? (amount > 0 ? amount : null),
      amountDeducted: asDouble(json['amountDeducted']),
      balanceBefore: asDouble(json['balanceBefore']),
      balanceAfter: asDouble(json['balanceAfter']),
      readOnly: json['readOnly'] == true ||
          (rawId?.toString().startsWith('supplier-debt-') ?? false),
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
