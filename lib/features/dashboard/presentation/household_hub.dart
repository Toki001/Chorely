import '../../sync/presentation/chore_command_scope.dart';
import '../../sync/domain/read_cache.dart';
import '../../notifications/presentation/device_reminder_scope.dart';
import '../../notifications/domain/device_reminders.dart';
import '../../notifications/domain/notifications_repository.dart';
import '../../notifications/presentation/updates_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../chores/domain/chore_repository.dart';
import '../../chores/presentation/chore_editor.dart';
import '../../chores/presentation/chore_panel.dart';
import '../../family/domain/family_repository.dart';
import '../../family/presentation/family_panel.dart';
import '../../households/domain/household_repository.dart';
import '../domain/calendar_dates.dart';
import '../domain/chore_progress.dart';
import 'calendar_controls.dart';

class HouseholdHub extends StatefulWidget {
  const HouseholdHub({
    required this.home,
    required this.uid,
    required this.repository,
    required this.family,
    required this.notifications,
    required this.onExit,
    this.supervisedActorId,
    super.key,
  });
  final Household home;
  final String uid;
  final ChoreRepository repository;
  final FamilyRepository family;
  final NotificationsRepository notifications;
  final String? supervisedActorId;
  final VoidCallback onExit;
  @override
  State<HouseholdHub> createState() => _HouseholdHubState();
}

class _HouseholdHubState extends State<HouseholdHub>
    with WidgetsBindingObserver {
  DeviceReminderController? _reminders;
  HouseholdReadCache? _readCache;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reminders = DeviceReminderScope.maybeOf(context);
    _readCache = ChoreCommandScope.cacheOf(context);
    if (_person != null) {
      _reminders?.bind(widget.uid, widget.home.id, _person!.id);
    }
  }

  StreamSubscription<ChoreActor?>? _actorSubscription;
  StreamSubscription<List<FamilyPerson>>? _peopleSubscription;
  ChoreActor? _person;
  List<FamilyPerson>? _roster;
  bool _actorReady = false, _peopleError = false;
  final _elapsed = Stopwatch();
  HouseholdClock? _clock;
  String? _lastToday;
  String? _clockError;
  bool _loading = false;
  Timer? _timer;
  DateTime? _selected;
  int _tab = 0;
  CalendarView _view = CalendarView.week;
  String _member = 'all';
  String _status = 'all';
  String? _queryKey;
  Stream<List<ChoreOccurrence>>? _rows;
  int _visible = 20;
  bool get _child => widget.supervisedActorId != null;
  DateTime get _now => _clock!.serverNow.add(_elapsed.elapsed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchAccess();
    _loadClock();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_clock == null || !mounted) return;
      if (_readCache?.stale(widget.home.id) == true ||
          !_now.isBefore(_clock!.nextMidnight)) {
        _loadClock();
      } else {
        setState(() {});
      }
    });
  }

  void _watchAccess() {
    _queryKey = null;
    _actorSubscription?.cancel();
    _peopleSubscription?.cancel();
    _actorSubscription = widget.repository
        .watchActor(widget.home.id, widget.uid)
        .listen(
          (value) {
            if (mounted) {
              setState(() {
                if (_person?.id != value?.id) _queryKey = null;
                _person = value;
                _actorReady = true;
                if (value == null) {
                  _reminders?.unbind(widget.home.id);
                } else {
                  _reminders?.bind(widget.uid, widget.home.id, value.id);
                }
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _person = null;
                _reminders?.unbind(widget.home.id);
                _actorReady = true;
                _queryKey = null;
              });
            }
          },
        );
    _peopleSubscription = widget.family
        .watchPeople(widget.home.id)
        .listen(
          (value) {
            if (mounted) {
              setState(() {
                _roster = value;
                _peopleError = false;
              });
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _roster = null;
                _peopleError = true;
                _queryKey = null;
              });
            }
          },
        );
  }

  @override
  void didUpdateWidget(HouseholdHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.home.timezone != widget.home.timezone) _loadClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadClock();
      _reminders?.refresh();
    }
  }

  Future<void> _loadClock() async {
    if (_loading) return;
    _loading = true;
    final oldToday = _lastToday;
    if (mounted) {
      setState(() {
        _clock = null;
        _clockError = null;
        _queryKey = null;
      });
    }
    try {
      final value = await widget.repository.loadClock(widget.home.id);
      if (!mounted) return;
      _elapsed
        ..reset()
        ..start();
      setState(() {
        _clock = value;
        _lastToday = value.today;
        if (_selected == null || civilDate(_selected!) == oldToday) {
          _selected = parseCivilDate(value.today);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _clockError = 'Couldn’t load your household day. Check your connection and access.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _reminders?.unbind(widget.home.id);
    _actorSubscription?.cancel();
    _peopleSubscription?.cancel();
    _timer?.cancel();
    _elapsed.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _queryKey = null);
  }

  Widget _exit() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 28),
      OutlinedButton(
        onPressed: widget.onExit,
        child: const Text('Leave supervised mode'),
      ),
      const Text('A guardian must sign in again to open adult controls.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final navigation = _HubNavigation(
      vertical: wide,
      selected: _tab,
      onSelect: (value) => setState(() {
        _tab = value;
        _visible = 20;
        _queryKey = null;
      }),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_child ? 'My home' : 'Our household'),
        leading: _child
            ? null
            : IconButton(
                tooltip: 'Back to your homes',
                onPressed: widget.onExit,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          IconButton(
            tooltip: 'Your updates',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _person == null
                ? null
                : () => _open(
                    UpdatesScreen(
                      home: widget.home,
                      uid: widget.uid,
                      actor: _person!,
                      repository: widget.notifications,
                      chores: widget.repository,
                      family: widget.family,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Refresh household day',
            onPressed: _loading ? null : _loadClock,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(top: false, child: navigation),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            SizedBox(
              width: 156,
              child: SafeArea(child: SingleChildScrollView(child: navigation)),
            ),
          Expanded(child: PageFrame(maxWidth: 760, child: _body())),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_actorReady) {
      return _loadingState('Checking household access');
    }
    final person = _person;
    if (person == null) {
      return Column(
        children: [
          const InlineError(
            'Household access is unavailable. Ask a guardian to check your membership.',
          ),
          TextButton(
            onPressed: () {
              setState(() => _actorReady = false);
              _watchAccess();
            },
            child: const Text('Retry household access'),
          ),
          if (_child) _exit(),
        ],
      );
    }
    if (_child &&
        (person.role != 'child' || person.id != widget.supervisedActorId)) {
      return Column(
        children: [
          const InlineError('This supervised profile is unavailable.'),
          _exit(),
        ],
      );
    }
    if (_clockError != null) {
      return Column(
        children: [
          InlineError(_clockError!),
          TextButton(
            onPressed: _loadClock,
            child: const Text('Retry household day'),
          ),
          if (_child) _exit(),
        ],
      );
    }
    if (_clock == null) {
      return _loadingState('Loading household day');
    }
    if (_peopleError) {
      return Column(
        children: [
          const InlineError(
            'Couldn’t load the home team. Check your connection or access.',
          ),
          TextButton(
            onPressed: _watchAccess,
            child: const Text('Reload home team'),
          ),
          if (_child) _exit(),
        ],
      );
    }
    if (_roster == null) {
      return _loadingState('Loading home team');
    }
    final roster = _roster!.where((p) => p.active).toList();
    final own = roster.where((p) => p.id == person.id).firstOrNull;
    if (_child && own == null) {
      return Column(
        children: [
          const InlineError('Your profile is no longer active.'),
          _exit(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tab == 0) ...[
          Text(
            _child
                ? 'Hi, ${own!.nickname}.'
                : 'A little teamwork,\na happier home.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(widget.home.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FamilyRoster(people: roster),
        ] else
          Text(
            ['Today', 'Chores', 'Calendar', 'The home team'][_tab],
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        const SizedBox(height: 16),
        if (_tab == 3)
          _child
              ? FamilyRoster(people: roster)
              : FamilyPanel(
                  householdId: widget.home.id,
                  uid: widget.uid,
                  repository: widget.family,
                )
        else
          _content(person, roster),
        if (_child) _exit(),
      ],
    );
  }

  Widget _loadingState(String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LinearProgressIndicator(semanticsLabel: label),
      if (_child) _exit(),
    ],
  );

  Widget _content(ChoreActor actor, List<FamilyPerson> people) {
    final today = parseCivilDate(_clock!.today);
    final selected = _tab == 0 ? today : _selected!;
    final view = _tab == 0 ? CalendarView.day : _view;
    final from = switch (view) {
      CalendarView.day => selected,
      CalendarView.week => selected.subtract(
        Duration(days: selected.weekday - 1),
      ),
      CalendarView.month => firstOfMonth(selected),
    };
    final through = view == CalendarView.week
        ? from.add(const Duration(days: 6))
        : (view == CalendarView.month ? lastOfMonth(selected) : selected);
    final effectiveMember = _child
        ? actor.id
        : (_member == 'mine'
              ? actor.id
              : (_member == 'all' ? null : _member.substring(7)));
    final key =
        '$_tab:${civilDate(from)}:${civilDate(through)}:$effectiveMember';
    if (_queryKey != key) {
      _queryKey = key;
      _rows = widget.repository.watchRange(
        widget.home.id,
        civilDate(from),
        civilDate(through),
        actorId: effectiveMember,
      );
      _visible = 20;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Household time · ${_clock!.timezone}'),
        const SizedBox(height: 12),
        if (!_child)
          DropdownButtonFormField<String>(
            key: ValueKey('member-filter-$_member'),
            initialValue: _member,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Show chores for'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('Everyone')),
              const DropdownMenuItem(value: 'mine', child: Text('Just me')),
              for (final p in people)
                DropdownMenuItem(
                  value: 'member:${p.id}',
                  child: Text(p.nickname, overflow: TextOverflow.ellipsis),
                ),
              if (![
                'all',
                'mine',
                ...people.map((p) => 'member:${p.id}'),
              ].contains(_member))
                DropdownMenuItem(
                  value: _member,
                  child: const Text('Former member'),
                ),
            ],
            onChanged: (value) => setState(() => _member = value!),
          ),
        const SizedBox(height: 12),
        StreamBuilder<List<ChoreOccurrence>>(
          key: ValueKey(key),
          stream: _rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  const InlineError(
                    'Couldn’t load this calendar. Check your connection or household access.',
                  ),
                  TextButton(
                    onPressed: () => setState(() => _queryKey = null),
                    child: const Text('Reload calendar'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator(
                semanticsLabel: 'Loading saved chores',
              );
            }
            final rows = snapshot.data!;
            final counts = <String, int>{};
            for (final row in rows.where(
              (r) => !['cancelled', 'skipped'].contains(r.status),
            )) {
              counts.update(row.localDate, (v) => v + 1, ifAbsent: () => 1);
            }
            final dayRows = _tab == 2
                ? rows.where((r) => r.localDate == civilDate(selected)).toList()
                : rows;
            final progress = ChoreProgress(dayRows);
            final filtered = dayRows
                .where(
                  (r) => switch (_status) {
                    'assigned' => [
                      'scheduled',
                      'needs_redo',
                    ].contains(r.status),
                    'review' => r.status == 'pending_review',
                    'done' => ['completed', 'approved'].contains(r.status),
                    _ => true,
                  },
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_tab != 0)
                  CalendarControls(
                    selected: selected,
                    today: today,
                    view: view,
                    onSelect: (value) => setState(() {
                      _selected = value;
                      _visible = 20;
                    }),
                    onView: (value) => setState(() => _view = value),
                    counts: counts,
                  )
                else
                  Text(MaterialLocalizations.of(context).formatFullDate(today)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ChorelyColors.lavender,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${progress.done} of ${progress.total} finished',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress.fraction,
                        semanticsLabel:
                            '${progress.done} of ${progress.total} saved chores finished',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        progress.total == 0
                            ? 'Room for a fresh start.'
                            : '${progress.waiting} waiting for review. Every little bit helps.',
                      ),
                    ],
                  ),
                ),
                if (_tab == 1)
                  Text('Showing ${civilDate(from)} to ${civilDate(through)}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in {
                      'all': 'All',
                      'assigned': 'Assigned',
                      'review': 'Review',
                      'done': 'Finished',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _status == entry.key,
                        onSelected: (_) => setState(() {
                          _status = entry.key;
                          _visible = 20;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _child ? 'Your chores' : 'Chores to share',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _status == 'all'
                          ? (_child
                                ? 'No chores here yet. Your guardian can add a little teamwork.'
                                : 'Nothing scheduled here. Add a chore or choose another date.')
                          : 'No chores match this filter. Try All or another date.',
                    ),
                  ),
                for (final chore in filtered.take(_visible))
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _open(
                        ChoreDetail(
                          home: widget.home,
                          occurrenceId: chore.id,
                          uid: widget.uid,
                          repository: widget.repository,
                          family: widget.family,
                          supervised: _child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              chore.draft.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(chore.timingLabel),
                            if (chore.timezone != _clock!.timezone)
                              Text('Recorded in ${chore.timezone}'),
                            Text(chore.statusLabel),
                            if (chore.pastDueAt(_now))
                              const Text(
                                'Past due · ask for help if you need it',
                                style: TextStyle(
                                  color: ChorelyColors.attention,
                                ),
                              ),
                            Text(
                              chore.draft.assignedActorIds
                                  .map(
                                    (id) =>
                                        people
                                            .where((p) => p.id == id)
                                            .firstOrNull
                                            ?.nickname ??
                                        'Former member',
                                  )
                                  .join(', '),
                            ),
                            if (chore.draft.completionPolicy ==
                                'all_members_complete')
                              Text(
                                '${chore.contributions.length} of ${chore.draft.assignedActorIds.length} parts received',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (filtered.length > _visible)
                  OutlinedButton(
                    onPressed: () => setState(() => _visible += 20),
                    child: const Text('Show more chores'),
                  ),
                if (!_child && actor.canManage) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _open(
                      ChoreEditor(
                        home: widget.home,
                        repository: widget.repository,
                        family: widget.family,
                        initialDate: civilDate(selected),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a chore'),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class FamilyRoster extends StatelessWidget {
  const FamilyRoster({required this.people, super.key});
  final List<FamilyPerson> people;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final person in people)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: ChorelyColors.lavender,
                child: Text(person.nickname.characters.firstOrNull ?? '?'),
              ),
              label: Text(person.nickname),
            ),
          ),
      ],
    ),
  );
}

class _HubNavigation extends StatelessWidget {
  const _HubNavigation({
    required this.vertical,
    required this.selected,
    required this.onSelect,
  });
  final bool vertical;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(14) > 21 ? 2 : 4;
      final width = vertical
          ? constraints.maxWidth
          : constraints.maxWidth / columns;
      final children = [
        for (var i = 0; i < 4; i++)
          SizedBox(
            width: width,
            child: Semantics(
              selected: selected == i,
              child: TextButton(
                key: ValueKey('hub-tab-$i'),
                onPressed: () => onSelect(i),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 64),
                  padding: const EdgeInsets.all(8),
                  backgroundColor: selected == i
                      ? ChorelyColors.lavender
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      [
                        Icons.wb_sunny_outlined,
                        Icons.checklist_rounded,
                        Icons.calendar_month_rounded,
                        Icons.people_outline_rounded,
                      ][i],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ['Today', 'Chores', 'Calendar', 'Family'][i],
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ];
      return Material(
        color: Colors.white,
        child: vertical ? Column(children: children) : Wrap(children: children),
      );
    },
  );
}
