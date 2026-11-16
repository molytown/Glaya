/// Safe numeric coercion for API payloads.
///
/// Postgres `numeric`/`decimal` columns serialize as JSON strings, so raw
/// `(value as num?)` casts crash when the backend returns e.g. "200.00".
/// Use these helpers anywhere an API field may arrive as String or num.

/// Returns [value] as a double, or [fallback] when it isn't numeric.
double toDoubleOr(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Returns [value] as an int, or [fallback] when it isn't numeric.
int toIntOr(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  return fallback;
}

/// Compact count formatting: 999 → "999", 1500 → "1.5k", 100000 → "100k",
/// 1500000 → "1.5M".
String formatCompactCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final k = count / 1000;
    if (k >= 10) return '${k.round()}k';
    final s = k.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
  }
  final m = count / 1000000;
  if (m >= 10) return '${m.round()}M';
  final s = m.toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}M';
}
