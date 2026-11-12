import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/ratings.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<Session>();
    final confirmed = await confirmAction(
      context,
      title: 'Cerrar sesión',
      message: 'Tendrás que volver a entrar con tu correo.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<Session>();
    final perfil = session.perfil;
    final uid = session.uid;
    final name = session.displayName;

    return SafeArea(
      child: ListView(
        padding: pagePadding,
        children: [
          Text('Perfil', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              UserAvatar(name: name, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleLarge),
                    if (session.user?.email != null)
                      Text(
                        session.user!.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (perfil == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('No pudimos cargar tu perfil'),
                trailing: TextButton(
                  onPressed: session.loadProfile,
                  child: const Text('Reintentar'),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _Item(
                    Icons.phone_outlined,
                    'Teléfono',
                    perfil.telefono ?? 'Sin registrar',
                  ),
                  const Divider(),
                  _Item(
                    Icons.public,
                    'Nacionalidad',
                    perfil.nacionalidad ?? 'Sin registrar',
                  ),
                  const Divider(),
                  _Item(
                    Icons.cake_outlined,
                    'Fecha de nacimiento',
                    perfil.fechaNacimiento == null
                        ? 'Sin registrar'
                        : formatDateOnly(perfil.fechaNacimiento),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: perfil == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EditProfileScreen(usuario: perfil),
                      ),
                    ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil'),
          ),
          const SizedBox(height: 14),
          const SectionTitle('Tu reputación'),
          if (uid != null) RatingsSection(uid: uid),
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      );
}
