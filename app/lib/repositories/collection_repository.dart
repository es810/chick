import '../core/constants/api_constants.dart';
import '../models/treasury_entry_item.dart';
import '../models/treasury_summary_model.dart';
import '../services/api_client.dart';

class CollectionRepository {
  CollectionRepository(this._api);

  final ApiClient _api;

  Future<List<TreasuryEntryItem>> listInvoices() async {
    final response = await _api.get(ApiConstants.collections);
    final data = response.data as Map<String, dynamic>;
    final list = data['data'] as List;
    return list.map((e) => TreasuryEntryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> listEmployees() async {
    final response = await _api.get('${ApiConstants.collections}/employees');
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<TreasurySummaryModel?> createInvoice({
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
  }) async {
    final response = await _api.post(
      ApiConstants.collections,
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
    final payload = data['data'] as Map<String, dynamic>?;
    if (payload?['summary'] != null) {
      return TreasurySummaryModel.fromJson(payload!['summary'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> updateInvoice({
    required String id,
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
  }) async {
    await _api.patch(
      '${ApiConstants.collections}/$id',
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
  }

  Future<void> deleteInvoice(String id) async {
    await _api.delete('${ApiConstants.collections}/$id');
  }
}
