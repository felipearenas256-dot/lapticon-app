import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../auth/profile_fields.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _draft = ProfileDraft(widget.usuario);
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
      await context.read<Session>().updateProfile(_draft.toJson());
      if (!mounted) return;
      showMessage(context, 'Perfil actualizado.');
      Navigator.pop(context);
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editar perfil')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: pagePadding,
              children: [
                ProfileFields(draft: _draft),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
