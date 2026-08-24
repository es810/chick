import 'package:dio/dio.dart';

/// User-facing message from an API error response.
String apiErrorMessage(Object error, {String? fallback}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return fallback ?? 'انتهت الجلسة. سجّل الدخول مرة أخرى.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'الاتصال بالخادم استغرق وقتاً طويلاً. أعد المحاولة.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وأعد المحاولة.';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return _localizeServerMessage(
        data['message'].toString(),
        data['errors'],
      );
    }
    if (status == 500) {
      return fallback ?? 'خطأ في السيرفر. حاول مرة أخرى.';
    }
    if (status == 400) {
      return fallback ?? 'الطلب غير صالح. راجع البيانات وحاول مرة أخرى.';
    }
    return fallback ?? error.message ?? 'فشل الطلب';
  }
  return error.toString();
}

String _localizeServerMessage(String message, Object? errors) {
  if (message == 'Only open loads can be finished') {
    return 'القيد ده اتقفل أو مستني تأكيد الهلاك — حدّث الصفحة';
  }
  if (message == 'invoiceNumber already exists' ||
      message.contains('invoiceNumber already exists')) {
    return 'تعذر إنشاء رقم الفاتورة. حاول مرة أخرى.';
  }
  if (message == 'Validation failed') {
    final detail = _firstValidationDetail(errors);
    if (detail != null) return detail;
    return 'بيانات غير مكتملة أو غير صحيحة';
  }
  if (message == 'Payment and discount cannot exceed supplier debt' ||
      message == 'Payment amount cannot exceed supplier debt') {
    return 'المبلغ المدفوع والخصم لا يمكن أن يتجاوزا مديونية المورد';
  }
  if (message == 'Deducted amount cannot be negative') {
    return 'مبلغ الخصم غير صالح';
  }
  if (message == 'Insufficient employee treasury balance') {
    return 'رصيد خزنة الموظف غير كافٍ';
  }
  if (message == 'Cannot transfer to the same employee') {
    return 'لا يمكن التحويل لنفس الموظف';
  }
  if (message == 'Source employee not found') {
    return 'الموظف المحوّل منه غير موجود';
  }
  if (message == 'Destination employee not found') {
    return 'الموظف المحوّل إليه غير موجود';
  }
  if (message.startsWith('Insufficient stock for')) {
    final type = message.replaceFirst('Insufficient stock for ', '').trim();
    return 'مخزون غير كافٍ لـ $type';
  }
  if (message == 'Invalid stock deduction quantity') {
    return 'عدد الطيور غير صالح';
  }
  if (message == 'Client not found') {
    return 'العميل غير موجود';
  }
  if (message.startsWith('Stock not found for type:')) {
    return 'نوع المخزون غير موجود';
  }
  if (message == 'Invalid ID format') {
    return 'معرّف غير صالح';
  }
  return message;
}

String? _firstValidationDetail(Object? errors) {
  if (errors is! List || errors.isEmpty) return null;
  final first = errors.first;
  if (first is! Map) return null;
  final path = first['path']?.toString() ?? '';
  final msg = first['msg']?.toString() ?? '';
  if (path.contains('clientId')) return 'اختر العميل';
  if (path.contains('quantity')) return 'أدخل العدد بشكل صحيح';
  if (path.contains('chickenType')) return 'اختر نوع الدجاج';
  if (path.contains('items')) return 'أضف صنفاً واحداً على الأقل';
  if (msg.isNotEmpty) return msg;
  return null;
}
