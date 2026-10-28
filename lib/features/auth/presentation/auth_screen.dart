import 'package:flutter/material.dart';

import '../../../shared/widgets/page_frame.dart';
import '../domain/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.repository, super.key});
  final AuthRepository repository;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_register) {
        await widget.repository.register(_email.text.trim(), _password.text);
      } else {
        await widget.repository.signIn(_email.text.trim(), _password.text);
      }
    } on AccountFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(email);
      if (mounted) {
        setState(
          () => _notice = 'If this account exists, a reset link is on its way.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t send a reset link. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your home, together')),
    body: PageFrame(
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                _register ? 'Start with you.' : 'Welcome back.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'An adult sets up the household. Children join through a guardian, without an email account.',
              ),
              const SizedBox(height: 28),
              if (_error != null) InlineError(_error!),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Adult email'),
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                autocorrect: false,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _register ? 'At least 12 characters' : null,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => (v?.length ?? 0) >= (_register ? 12 : 1)
                    ? null
                    : (_register
                          ? 'Use at least 12 characters.'
                          : 'Enter your password.'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Connecting…'
                      : _register
                      ? 'Create adult account'
                      : 'Sign in',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _error = null;
                        _notice = null;
                        _form.currentState?.reset();
                      }),
                child: Text(
                  _register
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
              if (!_register)
                TextButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Forgot password?'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
