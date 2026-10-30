import '../features/sync/presentation/confirm_account_exit.dart';
import '../features/sync/presentation/sync_status_frame.dart';
import '../features/sync/presentation/chore_command_scope.dart';
import '../features/notifications/presentation/device_reminder_scope.dart';

import 'dart:async';

import '../features/notifications/domain/notifications_repository.dart';
import '../features/chores/presentation/chore_panel.dart';

import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/account_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/households/domain/household_repository.dart';
import '../features/households/presentation/households_screen.dart';
import '../features/family/domain/family_repository.dart';
import '../features/family/presentation/child_home_screen.dart';
import '../features/family/presentation/join_screen.dart';
import '../shared/widgets/page_frame.dart';
import '../features/chores/domain/chore_repository.dart';
import 'theme.dart';

class ChorelyApp extends StatefulWidget {
  const ChorelyApp({
    required this.auth,
    required this.households,
    required this.family,
    required this.chores,
    required this.notifications,
    this.notificationLaunches,
    super.key,
  });
  final AuthRepository auth;
  final HouseholdRepository households;
  final FamilyRepository family;
  final ChoreRepository chores;
  final NotificationsRepository notifications;
  final NotificationLaunchSource? notificationLaunches;
  @override
  State<ChorelyApp> createState() => _ChorelyAppState();
}

class _ChorelyAppState extends State<ChorelyApp> {
  bool _introFinished = false;
  bool _linkChild = false;
  late final Stream<AccountSession?> _session = widget.auth.watchSession();
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<NotificationLink>? _notificationTaps;
  NotificationLink? _pendingLink;
  AccountSession? _linkSession;
  String? _linkUid, _activeNotificationRoute;
  int _routeGeneration = 0;
  bool _authLoading = true, _openingLink = false;

  @override
  void initState() {
    super.initState();
    final source = widget.notificationLaunches;
    if (source != null) {
      _notificationTaps = source.taps.listen(
        _receiveLink,
        onError: (Object error) {},
      );
      source.initial().then((link) {
        if (link != null && mounted) _receiveLink(link);
      }, onError: (Object error) {});
    }
  }

  @override
  void dispose() {
    _notificationTaps?.cancel();
    super.dispose();
  }

  void _receiveLink(NotificationLink link) {
    if (!mounted || link.encode() == _activeNotificationRoute) return;
    setState(() => _pendingLink = link);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingLink());
  }

  void _notificationFallback() {
    final context = _navigator.currentContext;
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'This update is unavailable for this session. Your home has the latest chores.',
          ),
        ),
      );
    }
  }

  Future<void> _openPendingLink() async {
    final session = _linkSession, link = _pendingLink;
    if (!mounted ||
        _authLoading ||
        _openingLink ||
        session == null ||
        link == null ||
        (!session.supervised && !session.verified)) {
      return;
    }
    final actorId = session.supervised ? session.profileId : session.uid;
    _pendingLink = null;
    if (link.actorId != actorId) {
      _notificationFallback();
      return;
    }
    final generation = _routeGeneration;
    _openingLink = true;
    try {
      final target = await widget.notifications.open(
        link.householdId,
        link.notificationId,
      );
      if (!mounted || generation != _routeGeneration) return;
      if (target == null ||
          target.actorId != actorId ||
          target.householdId != link.householdId) {
        _notificationFallback();
        return;
      }
      final home = await widget.households
          .watchHousehold(target.householdId)
          .first;
      if (!mounted || generation != _routeGeneration) return;
      final navigator = _navigator.currentState;
      if (home == null || navigator == null) {
        _notificationFallback();
        return;
      }
      final routeKey = link.encode();
      _activeNotificationRoute = routeKey;
      unawaited(
        navigator
            .push<void>(
              MaterialPageRoute(
                builder: (_) => ChoreDetail(
                  home: home,
                  occurrenceId: target.occurrenceId,
                  uid: session.uid,
                  repository: widget.chores,
                  family: widget.family,
                  supervised: session.supervised,
                ),
              ),
            )
            .then((_) {
              if (generation == _routeGeneration &&
                  _activeNotificationRoute == routeKey) {
                _activeNotificationRoute = null;
              }
            }),
      );
    } catch (_) {
      if (mounted && generation == _routeGeneration) _notificationFallback();
    } finally {
      if (generation == _routeGeneration) {
        _openingLink = false;
        if (_pendingLink?.encode() == link.encode()) _pendingLink = null;
        if (mounted && _pendingLink != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _openPendingLink(),
          );
        }
      }
    }
  }

  Widget _home(AsyncSnapshot<AccountSession?> snapshot) {
    if (snapshot.hasError) {
      return Scaffold(
        body: PageFrame(
          child: Column(
            children: [
              const InlineError('Couldn’t load your account.'),
              FilledButton(
                onPressed: widget.auth.refresh,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () =>
                    confirmAccountExit(context, widget.auth.signOut),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting ||
        snapshot.data?.restoring == true) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading account'),
        ),
      );
    }
    final session = snapshot.data;
    if (session != null) {
      if (session.supervised) {
        if (session.householdId == null || session.profileId == null) {
          return Scaffold(
            body: PageFrame(
              child: Column(
                children: [
                  const InlineError('This supervised session is unavailable.'),
                  TextButton(
                    onPressed: () =>
                        confirmAccountExit(context, widget.auth.signOut),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }
        return ChildHomeScreen(
          session: session,
          auth: widget.auth,
          households: widget.households,
          family: widget.family,
          chores: widget.chores,
          notifications: widget.notifications,
        );
      }
      if (session.verified) {
        return HouseholdsScreen(
          key: ValueKey(session.uid),
          session: session,
          auth: widget.auth,
          repository: widget.households,
          family: widget.family,
          chores: widget.chores,
          notifications: widget.notifications,
        );
      }
      return AccountScreen(session: session, repository: widget.auth);
    }
    if (_linkChild) {
      return JoinScreen(
        childDevice: true,
        repository: widget.family,
        onBack: () => setState(() => _linkChild = false),
        onJoined: (_) => setState(() => _linkChild = false),
      );
    }
    if (_pendingLink != null) {
      return AuthScreen(
        repository: widget.auth,
        onLinkChild: () => setState(() => _linkChild = true),
      );
    }
    if (!_introFinished) {
      return OnboardingScreen(
        onFinish: () => setState(() => _introFinished = true),
        onLinkChild: () => setState(() => _linkChild = true),
      );
    }
    return AuthScreen(
      repository: widget.auth,
      onLinkChild: () => setState(() => _linkChild = true),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AccountSession?>(
    stream: _session,
    builder: (context, snapshot) {
      _linkSession = snapshot.hasError ? null : snapshot.data;
      _authLoading =
          snapshot.hasError ||
          snapshot.connectionState == ConnectionState.waiting ||
          _linkSession?.restoring == true;
      final uid = _linkSession?.uid;
      DeviceReminderScope.maybeOf(context)?.identity(uid);
      final session = _linkSession;
      final outbox = ChoreCommandScope.maybeOf(context);
      final cache = ChoreCommandScope.cacheOf(context);
      if (_authLoading) {
        cache?.suspend();
      } else {
        cache?.identity(
          session != null && (session.verified || session.supervised)
              ? uid
              : null,
          householdId: session?.supervised == true
              ? session?.householdId
              : null,
          actorId: session?.supervised == true ? session?.profileId : null,
        );
      }
      if (_authLoading) {
        outbox?.suspend();
      } else {
        outbox?.identity(
          session != null && (session.verified || session.supervised)
              ? uid
              : null,
        );
      }
      if (_linkUid != uid) {
        if (_linkUid != null) _pendingLink = null;
        _linkUid = uid;
        _routeGeneration++;
        _openingLink = false;
        _activeNotificationRoute = null;
        _navigator = GlobalKey<NavigatorState>();
      }
      if (_pendingLink != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingLink());
      }
      return MaterialApp(
        // Auth identity changes discard route overlays and all previous profile UI.
        key: ValueKey(uid ?? 'signed-out'),
        navigatorKey: _navigator,
        title: 'Chorely',
        builder: outbox != null && cache != null
            ? (context, child) =>
                  SyncStatusFrame(outbox: outbox, cache: cache, child: child!)
            : null,
        debugShowCheckedModeBanner: false,
        theme: chorelyTheme(),
        home: _home(snapshot),
      );
    },
  );
}
