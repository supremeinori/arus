import 'package:intl/intl.dart';

class TimezoneConverter {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  static Duration getOffset(String timezone) {
    if (timezone.contains('Jayapura')) {
      return const Duration(hours: 9);
    } else if (timezone.contains('Makassar')) {
      return const Duration(hours: 8);
    } else if (timezone.contains('London')) {
      return const Duration(hours: 1); // BST perkiraan
    }
    return const Duration(hours: 7); // Default WIB Asia/Jakarta
  }

  static String getSuffix(String timezone) {
    if (timezone.contains('Jayapura')) {
      return 'WIT';
    } else if (timezone.contains('Makassar')) {
      return 'WITA';
    } else if (timezone.contains('London')) {
      return 'BST (London)';
    }
    return 'WIB';
  }

  static String formatTime(DateTime dateUtc, String timezone) {
    final utc = dateUtc.isUtc ? dateUtc : dateUtc.toUtc();
    final localTime = utc.add(getOffset(timezone));
    return '${_timeFormat.format(localTime)} ${getSuffix(timezone)}';
  }

  static String formatDateTime(DateTime dateUtc, String timezone) {
    final utc = dateUtc.isUtc ? dateUtc : dateUtc.toUtc();
    final localTime = utc.add(getOffset(timezone));
    return '${_dateTimeFormat.format(localTime)} ${getSuffix(timezone)}';
  }
}
