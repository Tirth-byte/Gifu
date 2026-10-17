import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/features/commitments/domain/utils/gufi_day_utils.dart';

void main() {
  group('GufiDayUtils Date Boundary and Timezone Calculations', () {
    test('03:59:59 AM local time belongs to the previous Gufi Day', () {
      // In UTC, 2026-10-16 03:59:59 UTC
      final dt = DateTime.utc(2026, 10, 16, 3, 59, 59);
      final gufiDay = GufiDayUtils.getGufiDayForTimestamp(dt, timezone: 'UTC');
      expect(gufiDay, '2026-10-15');
    });

    test('04:00:00 AM local time belongs to the current Gufi Day', () {
      // In UTC, 2026-10-16 04:00:00 UTC
      final dt = DateTime.utc(2026, 10, 16, 4, 0, 0);
      final gufiDay = GufiDayUtils.getGufiDayForTimestamp(dt, timezone: 'UTC');
      expect(gufiDay, '2026-10-16');
    });

    test('23:59:59 local time belongs to the current Gufi Day', () {
      final dt = DateTime.utc(2026, 10, 16, 23, 59, 59);
      final gufiDay = GufiDayUtils.getGufiDayForTimestamp(dt, timezone: 'UTC');
      expect(gufiDay, '2026-10-16');
    });

    test('Timezone offset +05:30 (IST) calculation', () {
      // 2026-10-15 22:30:00 UTC + 5:30 = 2026-10-16 04:00:00 IST -> Gufi Day 2026-10-16
      final dtAtStart = DateTime.utc(2026, 10, 15, 22, 30, 0);
      final dayAtStart = GufiDayUtils.getGufiDayForTimestamp(
        dtAtStart,
        timezone: '+05:30',
      );
      expect(dayAtStart, '2026-10-16');

      // 2026-10-15 22:29:59 UTC + 5:30 = 2026-10-16 03:59:59 IST -> Gufi Day 2026-10-15
      final dtBeforeStart = DateTime.utc(2026, 10, 15, 22, 29, 59);
      final dayBeforeStart = GufiDayUtils.getGufiDayForTimestamp(
        dtBeforeStart,
        timezone: '+05:30',
      );
      expect(dayBeforeStart, '2026-10-15');
    });

    test('Timezone offset -08:00 (PST) calculation', () {
      // 2026-10-16 12:00:00 UTC - 8h = 2026-10-16 04:00:00 PST -> Gufi Day 2026-10-16
      final dt = DateTime.utc(2026, 10, 16, 12, 0, 0);
      final day = GufiDayUtils.getGufiDayForTimestamp(dt, timezone: '-08:00');
      expect(day, '2026-10-16');

      // 2026-10-16 11:59:59 UTC - 8h = 2026-10-16 03:59:59 PST -> Gufi Day 2026-10-15
      final dtBefore = DateTime.utc(2026, 10, 16, 11, 59, 59);
      final dayBefore = GufiDayUtils.getGufiDayForTimestamp(
        dtBefore,
        timezone: '-08:00',
      );
      expect(dayBefore, '2026-10-15');
    });

    test(
      'Default deadline is 03:59:59.999 local time on next calendar day',
      () {
        final deadlineUtc = GufiDayUtils.getDefaultDeadlineUtc(
          '2026-10-16',
          timezone: 'UTC',
        );
        // Next day 03:59:59.999 UTC
        expect(deadlineUtc, DateTime.utc(2026, 10, 17, 3, 59, 59, 999));

        // In IST (+05:30), local deadline is 2026-10-17 03:59:59.999 IST
        // In UTC, this is 2026-10-16 22:29:59.999 UTC
        final deadlineIstInUtc = GufiDayUtils.getDefaultDeadlineUtc(
          '2026-10-16',
          timezone: '+05:30',
        );
        expect(deadlineIstInUtc, DateTime.utc(2026, 10, 16, 22, 29, 59, 999));
      },
    );

    test('Gufi day start is 04:00:00 local time in UTC', () {
      final startUtc = GufiDayUtils.getGufiDayStartUtc(
        '2026-10-16',
        timezone: 'UTC',
      );
      expect(startUtc, DateTime.utc(2026, 10, 16, 4, 0, 0));

      final startIstInUtc = GufiDayUtils.getGufiDayStartUtc(
        '2026-10-16',
        timezone: '+05:30',
      );
      expect(startIstInUtc, DateTime.utc(2026, 10, 15, 22, 30, 0));
    });

    test('IANA timezone America/New_York DST Summer vs Winter transitions', () {
      // Summer (EDT = UTC-4): 2026-07-15 08:00:00 UTC = 04:00:00 EDT -> Gufi Day 2026-07-15
      final summer4am = DateTime.utc(2026, 7, 15, 8, 0, 0);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(
          summer4am,
          timezone: 'America/New_York',
        ),
        '2026-07-15',
      );

      // 1 second before 4 AM EDT: 2026-07-15 07:59:59 UTC = 03:59:59 EDT -> Gufi Day 2026-07-14
      final summerBefore4am = DateTime.utc(2026, 7, 15, 7, 59, 59);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(
          summerBefore4am,
          timezone: 'America/New_York',
        ),
        '2026-07-14',
      );

      // Winter (EST = UTC-5): 2026-01-15 09:00:00 UTC = 04:00:00 EST -> Gufi Day 2026-01-15
      final winter4am = DateTime.utc(2026, 1, 15, 9, 0, 0);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(
          winter4am,
          timezone: 'America/New_York',
        ),
        '2026-01-15',
      );

      // 1 second before 4 AM EST: 2026-01-15 08:59:59 UTC = 03:59:59 EST -> Gufi Day 2026-01-14
      final winterBefore4am = DateTime.utc(2026, 1, 15, 8, 59, 59);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(
          winterBefore4am,
          timezone: 'America/New_York',
        ),
        '2026-01-14',
      );
    });

    test('IANA timezone Europe/London British Summer Time (BST) vs GMT', () {
      // BST (UTC+1) in August: 2026-08-10 03:00:00 UTC = 04:00:00 BST -> Gufi Day 2026-08-10
      final bst4am = DateTime.utc(2026, 8, 10, 3, 0, 0);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(bst4am, timezone: 'Europe/London'),
        '2026-08-10',
      );

      // GMT (UTC+0) in December: 2026-12-10 04:00:00 UTC = 04:00:00 GMT -> Gufi Day 2026-12-10
      final gmt4am = DateTime.utc(2026, 12, 10, 4, 0, 0);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(gmt4am, timezone: 'Europe/London'),
        '2026-12-10',
      );
    });

    test('IANA timezone Asia/Kolkata (IST without DST)', () {
      // 2026-10-15 22:30:00 UTC = 2026-10-16 04:00:00 IST -> Gufi Day 2026-10-16
      final ist4am = DateTime.utc(2026, 10, 15, 22, 30, 0);
      expect(
        GufiDayUtils.getGufiDayForTimestamp(ist4am, timezone: 'Asia/Kolkata'),
        '2026-10-16',
      );
    });
  });
}
