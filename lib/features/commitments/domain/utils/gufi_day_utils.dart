import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Single authoritative utility for Gufi Day calculations.
///
/// Rules:
/// - One Gufi day runs from 04:00:00 local time to 03:59:59.999 next calendar day.
/// - Example: 01:30 AM local time belongs to the previous Gufi day.
/// - 04:00 AM local time belongs to the current Gufi day.
/// - Supports both full IANA timezone names (e.g. 'America/New_York', 'Europe/London', 'Asia/Kolkata')
///   which automatically handle Daylight Saving Time (DST) shifts, as well as fixed offsets (+05:30, UTC).
class GufiDayUtils {
  GufiDayUtils._();

  static bool _tzInitialized = false;

  static void ensureInitialized() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  static String _formatDate(int year, int month, int day) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Converts a UTC timestamp to local DateTime in the target timezone (IANA or fixed offset).
  static DateTime toLocalTime(DateTime timestampUtc, String timezone) {
    ensureInitialized();
    final clean = timezone.trim();
    if (clean.isEmpty ||
        clean.toUpperCase() == 'UTC' ||
        clean.toUpperCase() == 'Z') {
      return timestampUtc.toUtc();
    }

    // Try IANA timezone lookup first (e.g. 'America/New_York', 'Asia/Kolkata')
    try {
      final location = tz.getLocation(clean);
      final tzDt = tz.TZDateTime.from(timestampUtc.toUtc(), location);
      return DateTime(
        tzDt.year,
        tzDt.month,
        tzDt.day,
        tzDt.hour,
        tzDt.minute,
        tzDt.second,
        tzDt.millisecond,
        tzDt.microsecond,
      );
    } catch (_) {
      // Fallback: parse fixed offset like +05:30 or -08:00
      final offset = parseTimezoneOffset(clean);
      return timestampUtc.toUtc().add(offset);
    }
  }

  /// Parses timezone offset string like '+05:30', '-08:00', 'UTC', 'Z' into Duration.
  static Duration parseTimezoneOffset(String timezone) {
    final clean = timezone.trim().toUpperCase();
    if (clean == 'UTC' || clean == 'Z' || clean.isEmpty) {
      return Duration.zero;
    }

    final match = RegExp(r'^([+-])(\d{1,2}):?(\d{2})?$').firstMatch(clean);
    if (match != null) {
      final sign = match.group(1) == '-' ? -1 : 1;
      final hours = int.parse(match.group(2)!);
      final minutes = match.group(3) != null ? int.parse(match.group(3)!) : 0;
      return Duration(minutes: sign * (hours * 60 + minutes));
    }

    return Duration.zero;
  }

  /// Authoritative calculation: returns the Gufi day ('YYYY-MM-DD') for a given UTC timestamp and timezone.
  static String getGufiDayForTimestamp(
    DateTime timestampUtc, {
    String timezone = 'UTC',
    Duration? offsetOverride,
  }) {
    DateTime localTime;
    if (offsetOverride != null) {
      localTime = timestampUtc.toUtc().add(offsetOverride);
    } else {
      localTime = toLocalTime(timestampUtc, timezone);
    }

    // If local hour is before 4 AM, belongs to the previous calendar day
    final effectiveDate = localTime.hour < 4
        ? localTime.subtract(const Duration(days: 1))
        : localTime;

    return _formatDate(
      effectiveDate.year,
      effectiveDate.month,
      effectiveDate.day,
    );
  }

  /// Calculates the default deadline (03:59:59.999 local time next day) in UTC for a given Gufi day.
  static DateTime getDefaultDeadlineUtc(
    String gufiDay, {
    String timezone = 'UTC',
    Duration? offsetOverride,
  }) {
    ensureInitialized();
    final parts = gufiDay.split('-').map(int.parse).toList();
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];

    if (offsetOverride != null) {
      final nextDayLocalDate = DateTime.utc(
        year,
        month,
        day,
      ).add(const Duration(days: 1));
      final localDeadline = DateTime.utc(
        nextDayLocalDate.year,
        nextDayLocalDate.month,
        nextDayLocalDate.day,
        3,
        59,
        59,
        999,
      );
      return localDeadline.subtract(offsetOverride);
    }

    final clean = timezone.trim();
    if (clean.isEmpty ||
        clean.toUpperCase() == 'UTC' ||
        clean.toUpperCase() == 'Z') {
      final nextDay = DateTime.utc(
        year,
        month,
        day,
      ).add(const Duration(days: 1));
      return DateTime.utc(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        3,
        59,
        59,
        999,
      );
    }

    try {
      final location = tz.getLocation(clean);
      final nextDay = DateTime(year, month, day).add(const Duration(days: 1));
      final tzLocal = tz.TZDateTime(
        location,
        nextDay.year,
        nextDay.month,
        nextDay.day,
        3,
        59,
        59,
        999,
      );
      return tzLocal.toUtc();
    } catch (_) {
      final offset = parseTimezoneOffset(clean);
      final nextDay = DateTime.utc(
        year,
        month,
        day,
      ).add(const Duration(days: 1));
      final localDeadline = DateTime.utc(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        3,
        59,
        59,
        999,
      );
      return localDeadline.subtract(offset);
    }
  }

  /// Calculates the start of a Gufi Day (04:00:00 local time) in UTC.
  static DateTime getGufiDayStartUtc(
    String gufiDay, {
    String timezone = 'UTC',
    Duration? offsetOverride,
  }) {
    ensureInitialized();
    final parts = gufiDay.split('-').map(int.parse).toList();
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];

    if (offsetOverride != null) {
      final localStart = DateTime.utc(year, month, day, 4, 0, 0);
      return localStart.subtract(offsetOverride);
    }

    final clean = timezone.trim();
    if (clean.isEmpty ||
        clean.toUpperCase() == 'UTC' ||
        clean.toUpperCase() == 'Z') {
      return DateTime.utc(year, month, day, 4, 0, 0);
    }

    try {
      final location = tz.getLocation(clean);
      final tzLocal = tz.TZDateTime(location, year, month, day, 4, 0, 0);
      return tzLocal.toUtc();
    } catch (_) {
      final offset = parseTimezoneOffset(clean);
      final localStart = DateTime.utc(year, month, day, 4, 0, 0);
      return localStart.subtract(offset);
    }
  }
}
