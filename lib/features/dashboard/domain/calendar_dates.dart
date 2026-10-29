/// Calendar dates keep civil fields; no conversion through the phone's timezone.
String civilDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime parseCivilDate(String value) {
  if (!RegExp(r'^(20\d{2}|2100)-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid household date');
  }
  final date = DateTime.utc(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
  if (civilDate(date) != value) {
    throw const FormatException('Invalid household date');
  }
  return date;
}

DateTime civilFields(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
DateTime firstOfMonth(DateTime date) => DateTime.utc(date.year, date.month);
DateTime lastOfMonth(DateTime date) =>
    DateTime.utc(date.year, date.month + 1, 0);
DateTime shiftMonth(DateTime date, int delta) {
  final first = DateTime.utc(date.year, date.month + delta);
  final last = lastOfMonth(first).day;
  return DateTime.utc(
    first.year,
    first.month,
    date.day > last ? last : date.day,
  );
}

List<DateTime> monthCells(DateTime month) {
  final first = firstOfMonth(month),
      start = firstOfMonth(month).subtract(Duration(days: first.weekday - 1));
  return List.generate(42, (i) => start.add(Duration(days: i)));
}

bool selectableCivilDate(DateTime value) =>
    !civilFields(value).isBefore(DateTime.utc(2000)) &&
    !civilFields(value).isAfter(DateTime.utc(2100, 12, 31));
