class TreasuryEntryItem {
  const TreasuryEntryItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    this.subtitle = '',
    this.createdAt,
  });

  final String id;
  final String category;
  final double amount;
  final String description;
  final String subtitle;
  final DateTime? createdAt;

  factory TreasuryEntryItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];
    return TreasuryEntryItem(
      id: rawId?.toString() ?? '',
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
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

  bool get isMovement => this == TreasuryCategory.externalRevenue || this == TreasuryCategory.withdrawal;
}
