import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Public holidays list (same as in home_page.dart)
final Set<String> publicHolidays = {
  '2025-01-25', // Thaipusam
  '2025-02-01', // Federal Territory Day
  '2025-02-10', // Chinese New Year
  '2025-02-11', // Chinese New Year (replacement)
  '2025-03-28', // Nuzul Al-Quran
  '2025-04-10', // Hari Raya Aidilfitri
  '2025-04-11', // Hari Raya Aidilfitri (replacement)
  '2025-05-01', // Labour Day
  '2025-05-22', // Wesak Day
  '2025-06-03', // Agong\'s Birthday
  '2025-07-07', // Awal Muharram
  '2025-07-30', // Nuzul Al-Quran
  '2025-08-31', // National Day
  '2025-09-16', // Malaysia Day
  '2025-10-24', // Deepavali
  '2025-12-25', // Christmas Day
  '2026-01-01', // New Year
  '2026-01-29', // Thaipusam
  '2026-02-10', // Chinese New Year
  '2026-02-11', // Chinese New Year (replacement)
  '2026-02-14', // Federal Territory Day
  '2026-04-10', // Nuzul Al-Quran
  '2026-05-01', // Labour Day
  '2026-05-24', // Hari Raya Aidilfitri
  '2026-06-03', // Agong\'s Birthday
  '2026-07-07', // Awal Muharram
  '2026-08-31', // National Day
  '2026-09-16', // Malaysia Day
  '2026-10-29', // Deepavali
  '2026-12-25', // Christmas Day
};

bool _isPublicHoliday(DateTime date) {
  final dateString = DateFormat('yyyy-MM-dd').format(date);
  return publicHolidays.contains(dateString);
}

/// Calculate next occurrence of a session day
DateTime _getNextSessionDate(DateTime baseDate, int sessionDayOfWeek, DateTime referenceDate) {
  var daysUntilNextOccurrence = (sessionDayOfWeek - referenceDate.weekday) % 7;
  // If it's the same day, show next week's occurrence
  if (daysUntilNextOccurrence == 0) {
    daysUntilNextOccurrence = 7;
  }
  
  final nextSessionDate = referenceDate.add(Duration(days: daysUntilNextOccurrence));
  
  return DateTime(
    nextSessionDate.year,
    nextSessionDate.month,
    nextSessionDate.day,
    baseDate.hour,
    baseDate.minute,
    baseDate.second,
  );
}

void main() {
  group('Weekly Session Logic Tests', () {
    
    test('Session on Monday should be calculated correctly', () {
      // Create a reference date that is NOT Monday
      final referenceDate = DateTime(2025, 1, 24); // Friday
      final sessionDate = DateTime(2025, 1, 20, 10, 0, 0); // Original session on Monday
      
      final result = _getNextSessionDate(sessionDate, 1, referenceDate);
      
      // Next Monday should be 2025-01-27
      expect(result.weekday, 1); // Monday
      expect(result.day, 27);
      expect(result.month, 1);
    });

    test('Session on public holiday should be marked as cancelled', () {
      final chineseNewYear = DateTime(2025, 2, 10); // Known public holiday
      expect(_isPublicHoliday(chineseNewYear), true);
    });

    test('Session on non-holiday should not be cancelled', () {
      final normalDay = DateTime(2025, 1, 24); // Random day (not a holiday)
      expect(_isPublicHoliday(normalDay), false);
    });

    test('All public holidays in list should be recognized', () {
      final holidays = [
        DateTime(2025, 1, 25), // Thaipusam
        DateTime(2025, 2, 10), // Chinese New Year
        DateTime(2025, 12, 25), // Christmas
        DateTime(2026, 1, 1), // New Year
      ];

      for (var holiday in holidays) {
        expect(
          _isPublicHoliday(holiday),
          true,
          reason: 'Should recognize ${DateFormat('yyyy-MM-dd').format(holiday)} as holiday',
        );
      }
    });

    test('Random non-holiday dates should not be marked as holidays', () {
      final nonHolidays = [
        DateTime(2025, 1, 15),
        DateTime(2025, 6, 15),
        DateTime(2025, 11, 15),
      ];

      for (var date in nonHolidays) {
        expect(
          _isPublicHoliday(date),
          false,
          reason: 'Should NOT recognize ${DateFormat('yyyy-MM-dd').format(date)} as holiday',
        );
      }
    });

    test('Weekly session calculation for each day of week', () {
      final referenceDate = DateTime(2025, 1, 20); // Monday
      
      for (int dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++) {
        final testSessionDate = DateTime(2025, 1, 13 + dayOfWeek, 10, 0, 0);
        final result = _getNextSessionDate(testSessionDate, dayOfWeek, referenceDate);
        
        expect(
          result.weekday,
          dayOfWeek,
          reason: 'Day $dayOfWeek should match in calculated next occurrence',
        );
      }
    });

    test('Session falling on holiday should be cancelled', () {
      // Test a session that falls on Chinese New Year (2025-02-10)
      // Simulate a Monday that falls on Chinese New Year
      final nextMonday = _getNextSessionDate(
        DateTime(2025, 2, 10, 10, 0, 0), // This Monday is Chinese New Year
        1, // Monday
        DateTime(2025, 2, 3), // Week before
      );
      
      expect(_isPublicHoliday(nextMonday), true);
    });

    test('Correct calculation of days until next occurrence', () {
      // Today is Friday (2025-01-24)
      final today = DateTime(2025, 1, 24); // Friday (weekday = 5)
      expect(today.weekday, 5);
      
      // Session on Monday (weekday = 1)
      final daysUntil = (1 - today.weekday) % 7; // Should be 3 days
      expect(daysUntil, 3);
      
      final nextOccurrence = today.add(Duration(days: daysUntil));
      expect(nextOccurrence.weekday, 1); // Should be Monday
    });

    test('Session today should show next week occurrence', () {
      // Today is Monday
      final today = DateTime(2025, 1, 20); // Monday
      expect(today.weekday, 1);
      
      // Session on Monday
      var daysUntil = (1 - today.weekday) % 7; // Calculates to 0
      // If same day, should be next week (7 days)
      if (daysUntil == 0) {
        daysUntil = 7;
      }
      expect(daysUntil, 7); // Should be 7 days (next Monday)
      
      final nextOccurrence = today.add(Duration(days: daysUntil));
      expect(nextOccurrence.weekday, 1); // Should be Monday
      expect(nextOccurrence.day, 27); // Next week's Monday
    });

  });
}
