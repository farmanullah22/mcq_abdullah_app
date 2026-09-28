import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String currency(num? value) {
    final v = value ?? 0;
    final n = NumberFormat('#,##,##0', 'en_PK');
    return 'Rs. ${n.format(v.round())}';
  }

  static String number(num? value) {
    final v = value ?? 0;
    return NumberFormat('#,##,##0', 'en_PK').format(v.round());
  }

  static String date(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd-MMM-yyyy').format(value.toLocal());
  }

  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd-MMM-yyyy hh:mm a').format(value.toLocal());
  }

  static String time(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('hh:mm a').format(value.toLocal());
  }

  static String compact(num? value) {
    final v = value ?? 0;
    final abs = v.abs();
    if (abs >= 10000000) return '${_trim(v / 10000000)} Cr';
    if (abs >= 100000) return '${_trim(v / 100000)} L';
    if (abs >= 1000) return '${_trim(v / 1000)}K';
    return '${v.round()}';
  }

  static String _trim(double d) {
    final s = d.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
