import 'package:chorely/features/dashboard/domain/calendar_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Civil fields remain the selected date without converting through UTC offsets', () {
    final picked = DateTime(2026, 10, 29);
    expect(civilDate(civilFields(picked)), '2026-10-29');
    expect(selectableCivilDate(DateTime(2000, 1, 1)), isTrue);
    expect(selectableCivilDate(DateTime(2100, 12, 31)), isTrue);
  });
  test('Invalid normalized dates and out-of-range years are rejected', () {
    for (final date in [
      '2026-02-30',
      '2100-02-29',
      '1999-12-31',
      '2101-01-01',
      '2026-1-2',
    ]) {
      expect(() => parseCivilDate(date), throwsFormatException);
    }
    expect(civilDate(parseCivilDate('2028-02-29')), '2028-02-29');
  });
  test(
    'Changing month clamps the date and preserves leap-year calendar fields',
    () {
      expect(civilDate(shiftMonth(DateTime.utc(2028, 1, 31), 1)), '2028-02-29');
      expect(civilDate(shiftMonth(DateTime.utc(2026, 1, 31), 1)), '2026-02-28');
      expect(
        civilDate(shiftMonth(DateTime.utc(2026, 1, 31), -1)),
        '2025-12-31',
      );
    },
  );
  test(
    'Month grid is six complete Monday-start weeks with the actual month days',
    () {
      final cells = monthCells(DateTime.utc(2026, 11, 18));
      expect(cells.length, 42);
      expect(cells.first.weekday, DateTime.monday);
      expect(cells.where((d) => d.month == 11).length, 30);
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].difference(cells[i - 1]), const Duration(days: 1));
      }
    },
  );
}
