import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../main.dart';
import 'theme.dart';
import 'phone_field.dart';
import 'widgets.dart';

/// Accesso e registrazione, nella stessa schermata.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, required this.onSession});

  final AuthService auth;
  final ValueChanged<Session> onSession;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _phoneCountry = 'IT';
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _registering
        ? await widget.auth.register(
            username: _username.text,
            email: _email.text,
            phoneCountry: _phoneCountry,
            phone: _phone.text,
            password: _password.text,
            confirm: _confirm.text,
          )
        : await widget.auth.login(_username.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.session != null) {
      widget.onSession(result.session!);
    } else {
      setState(() {
        _error = result.error;
        _password.clear();
        _confirm.clear();
      });
    }
  }

  void _toggle() => setState(() {
        _registering = !_registering;
        _error = null;
        _confirm.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Image.asset('assets/vaultly.png', width: 44, height: 44),
                      const SizedBox(width: 12),
                      const Text('VAULTLY',
                          style: TextStyle(color: VColors.accent, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                      child: Column(
                        key: ValueKey(_registering),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_registering ? 'Crea il tuo account' : 'Bentornato',
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Muted(
                            _registering
                                ? 'I tuoi dati restano solo su questo telefono, cifrati con la tua password.'
                                : 'Accedi per vedere i tuoi conti.',
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const FieldLabel('Username'),
                    TextField(
                      controller: _username,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'Il tuo username'),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      child: _registering
                          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              const FieldLabel('Email'),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: const InputDecoration(hintText: 'nome@esempio.it'),
                              ),
                              const FieldLabel('Numero di telefono'),
                              PhoneField(
                                country: _phoneCountry,
                                onCountryChanged: (iso) => setState(() => _phoneCountry = iso),
                                controller: _phone,
                                textInputAction: TextInputAction.next,
                              ),
                            ])
                          : const SizedBox(width: double.infinity),
                    ),
                    const FieldLabel('Password'),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: [_registering ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: _registering ? TextInputAction.next : TextInputAction.go,
                      onSubmitted: (_) => _registering ? null : _submit(),
                      decoration: InputDecoration(
                          hintText: _registering ? 'Almeno ${AuthService.minPasswordLength} caratteri' : 'La tua password'),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      child: _registering
                          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              const FieldLabel('Conferma password'),
                              TextField(
                                controller: _confirm,
                                obscureText: true,
                                textInputAction: TextInputAction.go,
                                onSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(hintText: 'Ripeti la password'),
                              ),
                            ])
                          : const SizedBox(width: double.infinity),
                    ),
                    ErrorBox(_error),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                          : Text(_registering ? 'Crea account' : 'Accedi'),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Muted(_registering ? 'Hai già un account?' : 'Non hai un account?'),
                      TextButton(onPressed: _toggle, child: Text(_registering ? 'Accedi' : 'Registrati')),
                    ]),
                    const SizedBox(height: 8),
                    const Muted('Versione $appVersion · i dati non lasciano mai il telefono',
                        size: 11.5, align: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
