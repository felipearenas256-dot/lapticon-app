import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';
import 'profile_fields.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _draft = ProfileDraft();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _form.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().register(
            email: _email.text.trim(),
            password: _password.text,
            datos: _draft.toJson(),
          );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: pagePadding,
            children: [
              Text('Crea tu cuenta', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Tu nombre será visible para quienes busquen viajeros.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) => RegExp(r'^\S+@\S+\.\S+$')
                        .hasMatch((value ?? '').trim())
                    ? null
                    : 'Escribe un correo válido',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hidden,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 6 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _hidden
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? 'Usa al menos 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 14),
              ProfileFields(draft: _draft),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BusyButton(
                label: 'Crear cuenta',
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Ya tengo cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
