import 'package:intl/intl.dart';

/// Money is integer minor units + ISO currency straight from the API.
abstract final class Money {
  static String _symbol(String currency) => switch (currency.toUpperCase()) {
    'EUR' => '€',
    'NOK' => 'kr',
    'USD' => r'$',
    'GBP' => '£',
    'SEK' => 'kr',
    'DKK' => 'kr',
    _ => currency.toUpperCase(),
  };

  /// 1250 EUR -> "€12.50"; NOK -> "12.50 kr". Always two decimals so columns align.
  static String format(int minor, String currency) {
    final amount = NumberFormat('#,##0.00', 'en_US').format(minor / 100);
    final symbol = _symbol(currency);
    return symbol.length <= 1 ? '$symbol$amount' : '$amount $symbol';
  }

  /// Signed variant for breakdown rows ("+€1.00").
  static String formatSigned(int minor, String currency) =>
      '${minor >= 0 ? '+' : '-'}${format(minor.abs(), currency)}';
}

abstract final class Fmt {
  static String distance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
  }

  static String duration(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// 24-hour time (Norwegian convention), e.g. 14:23.
  static String time(DateTime t) => DateFormat('HH:mm').format(t.toLocal());

  static String dateTime(DateTime t) {
    final l = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(l.year, l.month, l.day);
    final diff = today.difference(day).inDays;
    final hm = time(l);
    if (diff == 0) return 'Today, $hm';
    if (diff == 1) return 'Yesterday, $hm';
    return '${DateFormat('d MMM').format(l)}, $hm';
  }

  static String fullDateTime(DateTime t) =>
      DateFormat('d MMM yyyy, HH:mm').format(t.toLocal());
}
