import 'package:flutter/material.dart';

import '../../../shared/widgets/page_frame.dart';
import '../domain/auth_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.session,
    required this.repository,
    super.key,
  });
  final AccountSession session;
  final AuthRepository repository;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String? _message;
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Couldn’t connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chorely')),
    body: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: 24),
          Text(
            widget.session.verified
                ? 'Your account is ready.'
                : 'Check your inbox.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            widget.session.verified
                ? 'You’re signed in as ${widget.session.email}.'
                : 'We sent a verification link to ${widget.session.email}. Open it to confirm your account.',
          ),
          const SizedBox(height: 24),
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
          if (!widget.session.verified) ...[
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.repository.refresh,
                      'Account checked. If you have just verified, try again in a moment.',
                    ),
              child: const Text('I’ve verified my email'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.repository.sendVerification,
                      'A new verification link is on its way.',
                    ),
              child: const Text('Send another link'),
            ),
          ],
          TextButton(
            onPressed: _busy ? null : () => _run(widget.repository.signOut, ''),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}
