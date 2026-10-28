import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/widgets/page_frame.dart';
import '../domain/access_code.dart';
import '../domain/family_repository.dart';
import 'access_code_widgets.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({
    required this.childDevice,
    required this.repository,
    required this.onBack,
    required this.onJoined,
    super.key,
  });
  final bool childDevice;
  final FamilyRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String?> onJoined;
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _nickname = TextEditingController();
  final _commandId = const Uuid().v4();
  final _deviceSecret = newAccessCode();
  bool _busy = false;
  bool _scanning = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _scanning = false;
    });
    try {
      if (widget.childDevice) {
        await widget.repository.pairDevice(
          nonce: _code.text.trim(),
          deviceSecret: _deviceSecret,
        );
        if (mounted) widget.onJoined(null);
      } else {
        final id = await widget.repository.accept(
          nonce: _code.text.trim(),
          nickname: _nickname.text.trim(),
          commandId: _commandId,
        );
        if (mounted) widget.onJoined(id);
      }
    } on FamilyFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t confirm access. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _busy ? null : widget.onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        widget.childDevice ? 'Supervised device' : 'Join a household',
      ),
    ),
    body: PageFrame(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.childDevice
                  ? 'Your own little\ncorner of home.'
                  : 'Come on in.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(
              widget.childDevice
                  ? 'Ask a guardian to approve a code for your profile. This device will have supervised access. No child email or birthday needed.'
                  : 'Sign in with the adult email your guardian invited, then enter the one-use code.',
            ),
            const SizedBox(height: 24),
            if (_error != null) InlineError(_error!),
            if (_scanning)
              AccessCodeScanner(
                onCode: (code) => setState(() {
                  _code.text = code;
                  _scanning = false;
                }),
              ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _scanning = !_scanning),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(_scanning ? 'Close camera' : 'Scan QR code'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 43,
              decoration: const InputDecoration(
                labelText: 'One-use code',
                helperText: 'Paste the code shared by your guardian',
              ),
              validator: (v) => parseAccessCode(v ?? '') == null
                  ? 'Enter the complete 43-character code.'
                  : null,
            ),
            if (!widget.childDevice) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _nickname,
                enabled: !_busy,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Your nickname'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter your nickname.'
                    : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text(
                _busy
                    ? 'Confirming access…'
                    : widget.childDevice
                    ? 'Link this device'
                    : 'Join household',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
