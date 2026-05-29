import '../core/constants/api_constants.dart';
import '../models/dashboard_model.dart';
import '../services/api_client.dart';

class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> getDashboard() async {
    final response = await _api.get(ApiConstants.dashboard);
    final data = response.data as Map<String, dynamic>;
    return DashboardData.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<SalesReportItem>> getSalesReport({String? startDate, String? endDate}) async {
    final response = await _api.get(
      ApiConstants.salesReport,
      queryParameters: {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final sales = data['data']['sales'] as List;
    return sales.map((e) => SalesReportItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getRevenue() async {
    final response = await _api.get(ApiConstants.revenueReport);
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int page = 1}) async {
    final response = await _api.get(
      ApiConstants.auditLogs,
      queryParameters: {'page': page, 'limit': 50},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
