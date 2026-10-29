import 'package:flutter/material.dart';

import '../domain/calendar_dates.dart';

enum CalendarView { day, week, month }

class CalendarControls extends StatelessWidget {
  const CalendarControls({
    required this.selected,
    required this.today,
    required this.view,
    required this.onSelect,
    required this.onView,
    required this.counts,
    super.key,
  });
  final DateTime selected;
  final DateTime today;
  final CalendarView view;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<CalendarView> onView;
  final Map<String, int> counts;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose a household date',
    );
    if (picked != null) onSelect(civilFields(picked));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    final cells = view == CalendarView.month
        ? monthCells(selected)
        : List.generate(7, (i) => start.add(Duration(days: i)));
    DateTime step(int direction) => view == CalendarView.month
        ? shiftMonth(selected, direction)
        : selected.add(
            Duration(days: direction * (view == CalendarView.week ? 7 : 1)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in CalendarView.values)
              ChoiceChip(
                label: Text(switch (option) {
                  CalendarView.day => 'Day',
                  CalendarView.week => 'Week',
                  CalendarView.month => 'Month',
                }),
                selected: option == view,
                onSelected: (_) => onView(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          localizations.formatMonthYear(selected),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Previous ${view.name}',
              onPressed: selectableCivilDate(step(-1))
                  ? () => onSelect(step(-1))
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            TextButton(
              onPressed: () => _pick(context),
              child: const Text('Choose date'),
            ),
            IconButton(
              tooltip: 'Next ${view.name}',
              onPressed: selectableCivilDate(step(1))
                  ? () => onSelect(step(1))
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            TextButton(
              onPressed: () => onSelect(today),
              child: const Text('Go to today'),
            ),
          ],
        ),
        if (view != CalendarView.day)
          LayoutBuilder(
            builder: (context, constraints) {
              // Keep each target >=48dp, even at 320dp with enlarged text. Each
              // week wraps independently so dates retain their calendar order.
              final minimum =
                  48.0 * MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = (constraints.maxWidth / minimum).floor().clamp(
                1,
                7,
              );
              final width = constraints.maxWidth / columns;
              return Column(
                children: [
                  for (var i = 0; i < cells.length; i += 7)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        children: [
                          for (final date in cells.skip(i).take(7))
                            SizedBox(
                              width: width,
                              child: Semantics(
                                selected: date == selected,
                                button: true,
                                enabled: selectableCivilDate(date),
                                onTap: selectableCivilDate(date)
                                    ? () => onSelect(date)
                                    : null,
                                label:
                                    '${localizations.formatFullDate(date)}${view == CalendarView.month && date.month != selected.month ? '' : ', ${counts[civilDate(date)] ?? 0} chores'}',
                                excludeSemantics: true,
                                child: TextButton(
                                  key: ValueKey('calendar-${civilDate(date)}'),
                                  onPressed: selectableCivilDate(date)
                                      ? () => onSelect(date)
                                      : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 2,
                                    ),
                                    backgroundColor: date == selected
                                        ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        localizations
                                            .narrowWeekdays[date.weekday % 7],
                                      ),
                                      Text('${date.day}'),
                                      Text(
                                        view == CalendarView.month &&
                                                date.month != selected.month
                                            ? '—'
                                            : '${counts[civilDate(date)] ?? 0}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        Text(localizations.formatFullDate(selected)),
        const SizedBox(height: 12),
      ],
    );
  }
}
