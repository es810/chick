import '../core/constants/api_constants.dart';
import '../models/treasury_entry_item.dart';
import '../models/treasury_summary_model.dart';
import '../services/api_client.dart';

class TreasuryRepository {
  TreasuryRepository(this._api);

  final ApiClient _api;

  Future<TreasurySummaryModel> getSummary() async {
    final response = await _api.get('${ApiConstants.treasury}/summary');
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> updateOpeningBalance(double openingBalance) async {
    final response = await _api.patch(
      ApiConstants.treasury,
      data: {'openingBalance': openingBalance},
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> addExternalRevenue(double amount, {String? description}) async {
    final response = await _api.post(
      '${ApiConstants.treasury}/external-revenue',
      data: {'amount': amount, if (description != null) 'description': description},
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> withdraw(double amount, {String? description}) async {
    final response = await _api.post(
      '${ApiConstants.treasury}/withdraw',
      data: {'amount': amount, if (description != null) 'description': description},
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> resetMainTreasury() async {
    final response = await _api.post('${ApiConstants.treasury}/reset');
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<TreasuryEntryItem>> listEntries(TreasuryCategory category) async {
    final response = await _api.get(
      '${ApiConstants.treasury}/entries',
      queryParameters: {'category': category.apiValue},
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['data'] as List;
    return list.map((e) => TreasuryEntryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> listEmployees() async {
    final response = await _api.get('${ApiConstants.treasury}/employees');
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<TreasurySummaryModel> createCollectionEntry({
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
  }) async {
    final response = await _api.post(
      '${ApiConstants.treasury}/entries',
      data: {
        'category': 'collection',
        'clientId': clientId,
        'employeeId': employeeId,
        'collectionDate': collectionDate.toIso8601String(),
        'amountPaid': amountPaid,
        'amountDeducted': amountDeducted,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(payload['summary'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> updateCollectionEntry({
    required String id,
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
  }) async {
    final response = await _api.patch(
      '${ApiConstants.treasury}/entries/$id',
      queryParameters: {'category': 'collection'},
      data: {
        'clientId': clientId,
        'employeeId': employeeId,
        'collectionDate': collectionDate.toIso8601String(),
        'amountPaid': amountPaid,
        'amountDeducted': amountDeducted,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> createEntry({
    required TreasuryCategory category,
    required double amount,
    String? description,
    String? employeeId,
    String? supplierId,
    double amountDeducted = 0,
  }) async {
    final response = await _api.post(
      '${ApiConstants.treasury}/entries',
      data: {
        'category': category.apiValue,
        'amount': amount,
        if (description != null) 'description': description,
        if (employeeId != null) 'employeeId': employeeId,
        if (supplierId != null) 'supplierId': supplierId,
        if (category == TreasuryCategory.loading) 'amountDeducted': amountDeducted,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(payload['summary'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> updateEntry({
    required TreasuryCategory category,
    required String id,
    double? amount,
    String? description,
  }) async {
    final response = await _api.patch(
      '${ApiConstants.treasury}/entries/$id',
      queryParameters: {'category': category.apiValue},
      data: {
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<TreasurySummaryModel> deleteEntry({
    required TreasuryCategory category,
    required String id,
  }) async {
    final response = await _api.delete(
      '${ApiConstants.treasury}/entries/$id',
      queryParameters: {'category': category.apiValue},
    );
    final data = response.data as Map<String, dynamic>;
    return TreasurySummaryModel.fromJson(data['data'] as Map<String, dynamic>);
  }
}
