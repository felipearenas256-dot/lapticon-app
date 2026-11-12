import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/common.dart';
import 'profile_fields.dart';

/// Aparece cuando la cuenta existe en Firebase pero no tiene perfil en el
/// backend. Sin este paso los demás usuarios la verían como "Anónimo".
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _draft = ProfileDraft();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final form = _form.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().completeProfile(_draft.toJson());
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
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: context.read<Session>().signOut,
            child: const Text('Salir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: pagePadding,
            children: [
              Text('Completa tu perfil', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Solo falta esto para empezar a enviar o llevar encomiendas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ProfileFields(draft: _draft),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              BusyButton(label: 'Guardar', busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
