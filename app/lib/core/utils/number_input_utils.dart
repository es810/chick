/// Plain number text for invoice inputs — no trailing zeros (70 not 70.00).
String formatInputNumber(num? value, {bool emptyIfZero = false}) {
  if (value == null) return '';
  final d = value.toDouble();
  if (emptyIfZero && d.abs() < 0.000001) return '';
  final fixed = d.toStringAsFixed(4);
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

double parseInputNumber(String text, {double fallback = 0}) {
  final t = text.trim();
  if (t.isEmpty) return fallback;
  return double.tryParse(t) ?? fallback;
}

int parseInputInt(String text, {int fallback = 0}) {
  final t = text.trim();
  if (t.isEmpty) return fallback;
  return int.tryParse(t) ?? fallback;
}
