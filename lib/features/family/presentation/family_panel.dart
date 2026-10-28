import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../domain/access_code.dart';
import '../domain/family_repository.dart';
import 'access_code_widgets.dart';

class FamilyPanel extends StatefulWidget {
  const FamilyPanel({
    required this.householdId,
    required this.uid,
    required this.repository,
    super.key,
  });
  final String householdId;
  final String uid;
  final FamilyRepository repository;
  @override
  State<FamilyPanel> createState() => _FamilyPanelState();
}

class _FamilyPanelState extends State<FamilyPanel> {
  late final _people = widget.repository.watchPeople(widget.householdId);
  late final _role = widget.repository.watchRole(
    widget.householdId,
    widget.uid,
  );
  String? _action;
  FamilyPerson? _child;
  String? _error;
  bool _busy = false;
  int _accessVersion = 0;
  Future<void> _revoke(String id, String kind) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this access?'),
        content: Text(
          kind == 'member'
              ? 'This member will lose access to your household. At least one guardian must remain.'
              : 'This code or device will no longer have access. A new guardian approval will be needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep access'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.revoke(
        householdId: widget.householdId,
        targetId: id,
        kind: kind,
      );
      if (mounted) setState(() => _accessVersion++);
    } on FamilyFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t confirm removal. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _role,
    builder: (context, role) {
      if (role.hasError ||
          (role.connectionState == ConnectionState.active &&
              role.data == null)) {
        return const InlineError(
          'Your household access changed. Return to your homes or sign out.',
        );
      }
      final guardian = role.data == 'guardian';
      if (_action != null && guardian) {
        return FamilyActionForm(
          key: ValueKey('$_action:${_child?.id}'),
          householdId: widget.householdId,
          repository: widget.repository,
          action: _action!,
          childProfile: _child,
          onBack: () => setState(() {
            _action = null;
            _child = null;
          }),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) InlineError(_error!),
          if (_busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Confirming access change',
            ),
          StreamBuilder<List<FamilyPerson>>(
            stream: _people,
            builder: (context, people) {
              if (people.hasError) {
                return const InlineError('Couldn’t load your home team.');
              }
              if (!people.hasData) {
                return const LinearProgressIndicator(
                  semanticsLabel: 'Loading home team',
                );
              }
              final active = people.data!.where((p) => p.active).toList();
              return Column(
                children: active
                    .map(
                      (person) => Card(
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                person.nickname,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                person.role == 'child'
                                    ? 'Supervised child'
                                    : person.role == 'guardian'
                                    ? 'Guardian'
                                    : 'Adult member',
                              ),
                              if (guardian && person.role == 'child')
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _action = 'pairing';
                                          _child = person;
                                        }),
                                  icon: const Icon(Icons.phonelink_rounded),
                                  label: const Text('Link a device'),
                                ),
                              if (guardian && person.role != 'child')
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _revoke(person.id, 'member'),
                                  child: Text(
                                    person.id == widget.uid
                                        ? 'Leave household'
                                        : 'Remove member access',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (guardian) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _action = 'invite'),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Invite an adult'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => setState(() => _action = 'child'),
              icon: const Icon(Icons.child_care_rounded),
              label: const Text('Add a child profile'),
            ),
            const SizedBox(height: 28),
            Text(
              'Access controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final kind in ['invite', 'pairing', 'device'])
              AccessList(
                key: ValueKey('$kind:$_accessVersion'),
                householdId: widget.householdId,
                repository: widget.repository,
                kind: kind,
                onRevoke: _busy ? null : (id) => _revoke(id, kind),
              ),
          ],
        ],
      );
    },
  );
}

class AccessList extends StatefulWidget {
  const AccessList({
    required this.householdId,
    required this.repository,
    required this.kind,
    required this.onRevoke,
    super.key,
  });
  final String householdId;
  final FamilyRepository repository;
  final String kind;
  final ValueChanged<String>? onRevoke;
  @override
  State<AccessList> createState() => _AccessListState();
}

class _AccessListState extends State<AccessList> {
  late final _stream = widget.repository.watchAccess(
    widget.householdId,
    widget.kind,
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FamilyAccess>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const InlineError('Couldn’t load access controls.');
      }
      if (!snapshot.hasData) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Loading access controls',
        );
      }
      final items = snapshot.data!
          .where(
            (a) =>
                a.status == 'active' &&
                (a.expiresAt == null || a.expiresAt!.isAfter(DateTime.now())),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in items)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.kind == 'device'
                          ? 'Linked child device'
                          : widget.kind == 'pairing'
                          ? 'Child pairing approval'
                          : '${a.role == 'guardian' ? 'Guardian' : 'Adult'} invitation',
                    ),
                    Text(
                      'Reference ${a.id.length > 8 ? a.id.substring(a.id.length - 8) : a.id}',
                    ),
                    TextButton(
                      onPressed: widget.onRevoke == null
                          ? null
                          : () => widget.onRevoke!(a.id),
                      child: const Text('Revoke access'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class FamilyActionForm extends StatefulWidget {
  const FamilyActionForm({
    required this.householdId,
    required this.repository,
    required this.action,
    required this.onBack,
    this.childProfile,
    super.key,
  });
  final String householdId;
  final FamilyRepository repository;
  final String action;
  final FamilyPerson? childProfile;
  final VoidCallback onBack;
  @override
  State<FamilyActionForm> createState() => _FamilyActionFormState();
}

class _FamilyActionFormState extends State<FamilyActionForm> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _commandId = const Uuid().v4();
  final _nonce = newAccessCode();
  String _role = 'adult';
  String? _error;
  bool _busy = false;
  bool _complete = false;
  DateTime? _expiresAt;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (widget.action) {
        case 'invite':
          _expiresAt = await widget.repository.invite(
            householdId: widget.householdId,
            nonce: _nonce,
            recipientEmail: _text.text.trim(),
            role: _role,
            commandId: _commandId,
          );
        case 'child':
          await widget.repository.addChild(
            householdId: widget.householdId,
            nickname: _text.text.trim(),
            commandId: _commandId,
          );
        case 'pairing':
          _expiresAt = await widget.repository.approvePairing(
            householdId: widget.householdId,
            profileId: widget.childProfile!.id,
            nonce: _nonce,
          );
      }
      if (mounted) setState(() => _complete = true);
    } on FamilyFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t confirm this change. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : widget.onBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Back to the home team'),
      ),
      const SizedBox(height: 16),
      if (_complete) ...[
        if (widget.action == 'child')
          const Text(
            'Child profile saved. You can now approve a device from the home team.',
          )
        else
          ApprovedCode(
            code: _nonce,
            child: widget.action == 'pairing',
            expiresAt: _expiresAt!,
          ),
      ] else
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (widget.action) {
                'invite' => 'Grow your home team.',
                'child' => 'A place in the team.',
                _ => 'Approve a child device.',
              }, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              if (_error != null) InlineError(_error!),
              if (widget.action != 'pairing')
                TextFormField(
                  controller: _text,
                  enabled: !_busy,
                  maxLength: widget.action == 'invite' ? 254 : 40,
                  keyboardType: widget.action == 'invite'
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: widget.action == 'invite'
                        ? 'Adult recipient email'
                        : 'Child nickname',
                    helperText: widget.action == 'child'
                        ? 'No email or birthday needed'
                        : null,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a ${widget.action == 'invite' ? 'recipient email' : 'nickname'}.'
                      : widget.action == 'invite' &&
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                      ? 'Enter a valid adult email.'
                      : null,
                ),
              if (widget.action == 'invite') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Membership role',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'adult',
                      child: Text('Adult member'),
                    ),
                    DropdownMenuItem(
                      value: 'guardian',
                      child: Text('Guardian'),
                    ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _role = v!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guardians can invite and remove people, approve child devices and manage household rules. Adult members cannot grant those permissions.',
                ),
              ],
              if (widget.action == 'pairing')
                Text(
                  'Approve supervised access for ${widget.childProfile!.nickname}. Only share this one-use code with the device you want to link. To return to guardian controls on a shared device, sign in again with adult credentials.',
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Confirming…'
                      : switch (widget.action) {
                          'invite' => 'Create one-use invite',
                          'child' => 'Save child profile',
                          _ => 'Approve and create code',
                        },
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
