import 'package:equatable/equatable.dart';

class InvoiceItemModel extends Equatable {
  const InvoiceItemModel({
    required this.chickenType,
    required this.quantity,
    required this.weight,
    required this.unitPrice,
    required this.total,
  });

  final String chickenType;
  final int quantity;
  final double weight;
  final double unitPrice;
  final double total;

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      chickenType: json['chickenType'] as String,
      quantity: (json['quantity'] as num).toInt(),
      weight: (json['weight'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chickenType': chickenType,
        'quantity': quantity,
        'weight': weight,
        'unitPrice': unitPrice,
      };

  @override
  List<Object?> get props => [chickenType, quantity];
}

class InvoiceModel extends Equatable {
  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.clientId,
    required this.employeeId,
    required this.items,
    this.itemCount = 1,
    this.grossWeight,
    this.tareWeight,
    required this.totalWeight,
    required this.totalPrice,
    this.balanceBefore,
    this.balanceAfter,
    required this.paymentStatus,
    this.notes = '',
    this.clientName,
    this.clientPhone,
    this.employeeName,
    this.createdAt,
  });

  final String id;
  final String invoiceNumber;
  final String clientId;
  final String employeeId;
  final List<InvoiceItemModel> items;
  final int itemCount;
  final double? grossWeight;
  final double? tareWeight;
  final double totalWeight;
  final double totalPrice;
  final double? balanceBefore;
  final double? balanceAfter;
  final String paymentStatus;
  final String notes;
  final String? clientName;
  final String? clientPhone;
  final String? employeeName;
  final DateTime? createdAt;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final client = json['clientId'];
    final employee = json['employeeId'];

    return InvoiceModel(
      id: json['_id'] as String? ?? json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      clientId: client is Map ? client['_id'] as String : client as String,
      employeeId: employee is Map ? employee['_id'] as String : employee as String,
      items: (json['items'] as List)
          .map((e) => InvoiceItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 1,
      grossWeight: (json['grossWeight'] as num?)?.toDouble(),
      tareWeight: (json['tareWeight'] as num?)?.toDouble(),
      totalWeight: (json['totalWeight'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String,
      notes: json['notes'] as String? ?? '',
      clientName: client is Map ? client['name'] as String? : null,
      clientPhone: client is Map ? client['phone'] as String? : null,
      employeeName: employee is Map ? employee['name'] as String? : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }

  double get netWeight {
    if (grossWeight != null && tareWeight != null) {
      return grossWeight! - tareWeight!;
    }
    return totalWeight;
  }

  double get displayGrossWeight => grossWeight ?? (totalWeight + (tareWeight ?? 0));

  double get displayTareWeight => tareWeight ?? 0;

  double get pricePerKg {
    if (items.isEmpty || netWeight <= 0) return 0;
    if (items.length == 1) return items.first.unitPrice;
    return totalPrice / netWeight;
  }

  @override
  List<Object?> get props => [id, invoiceNumber];
}

class PaginationMeta extends Equatable {
  const PaginationMeta({required this.total, required this.page, required this.pages});

  final int total;
  final int page;
  final int pages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pages: (json['pages'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [total, page, pages];
}
