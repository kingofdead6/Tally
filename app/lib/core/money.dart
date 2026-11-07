import 'package:intl/intl.dart';

/// DA formatting the way it's written here: "12 500 DA", "1 250,50 DA".
class Money {
  Money._();

  static const _nbsp = ' ';

  static String format(double value, {bool withSign = false, bool income = true, bool currency = true}) {
    final abs = value.abs();
    final whole = abs.truncate();
    final cents = ((abs - whole) * 100).round();

    final grouped = _group(cents == 100 ? whole + 1 : whole);
    final decimals = (cents == 0 || cents == 100) ? '' : ',${cents.toString().padLeft(2, '0')}';

    String sign = '';
    if (withSign) {
      sign = income ? '+' : '−';
    } else if (value < 0) {
      sign = '−';
    }
    return '$sign$grouped$decimals${currency ? '${_nbsp}DA' : ''}';
  }

  /// Compact for chart axes: 1,2k / 45k / 1,3M
  static String compact(double value) {
    final v = value.abs();
    String out;
    if (v >= 1000000) {
      out = '${_trim(v / 1000000)}M';
    } else if (v >= 1000) {
      out = '${_trim(v / 1000)}k';
    } else {
      out = v.round().toString();
    }
    return value < 0 ? '−$out' : out;
  }

  static String _trim(double v) {
    final s = v >= 100 ? v.round().toString() : v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
  }

  static String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(_nbsp);
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// Accepts "12 500", "12500,5", "12500.5". Returns null if not a number.
  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
    return double.tryParse(cleaned);
  }
}

class Dates {
  Dates._();

  static final _day = DateFormat('EEEE d MMMM');
  static final _short = DateFormat('d MMM yyyy');
  static final _month = DateFormat('MMMM yyyy');
  static final _monthShort = DateFormat('MMM');

  static String dayHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (d.year != now.year) return _short.format(d);
    return _day.format(d);
  }

  static String short(DateTime d) => _short.format(d);
  static String month(DateTime d) => _month.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1));
}
