import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/motion.dart';
import '../../widgets/tickets.dart';
import '../../widgets/viajeros.dart';
import '../assistant/assistant_screen.dart';
import '../encomiendas/encomienda_detail_screen.dart';
import '../encomiendas/encomienda_form_screen.dart';
import '../viajes/viaje_detail_screen.dart';
import '../viajes/viaje_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.watch<Session>();
    final firstName = session.perfil?.nombre;
    final api = context.read<LapticonApi>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<Revision>().bump();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: pagePadding,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    firstName == null ? 'Hola' : 'Hola, $firstName',
                    style: theme.textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Asistente',
                  icon: const Icon(Icons.support_agent),
                  onPressed: () => _push(context, const AssistantScreen()),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '¿Qué vas a hacer hoy?',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Enviar',
                    subtitle: 'Publica una encomienda',
                    background: scheme.secondary,
                    foreground: scheme.onSecondary,
                    onTap: () =>
                        _push(context, const EncomiendaFormScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.flight_takeoff,
                    title: 'Viajar',
                    subtitle: 'Registra tu vuelo',
                    background: scheme.primary,
                    foreground: scheme.onPrimary,
                    onTap: () => _push(context, const ViajeFormScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionTitle('Tu próximo viaje'),
            Loader<Viaje?>(
              load: api.miViajeDisponible,
              placeholder: const TicketSkeletons(count: 1),
              builder: (context, viaje, _) {
                if (viaje == null) {
                  return _Hint(
                    icon: Icons.flight_outlined,
                    text: 'Si vas a viajar, regístralo y lleva una encomienda.',
                    onTap: () => _push(context, const ViajeFormScreen()),
                  );
                }
                return ViajeTicket(
                  viaje: viaje,
                  highlighted: true,
                  onTap: () => _push(context, ViajeDetailScreen(viaje: viaje)),
                );
              },
            ),
            const SizedBox(height: 14),
            SectionTitle(
              'Encomiendas en curso',
              action: TextButton(
                onPressed: () =>
                    context.read<ShellTab>().value = ShellTab.encomiendas,
                child: const Text('Ver todas'),
              ),
            ),
            Loader<List<Encomienda>>(
              load: api.misEncomiendas,
              placeholder: const TicketSkeletons(count: 1),
              builder: (context, encomiendas, _) {
                final enCurso = encomiendas
                    .where((e) => const {
                          'disponible',
                          'tomada',
                          'entregada',
                        }.contains(e.estado))
                    .take(3)
                    .toList();
                if (enCurso.isEmpty) {
                  return _Hint(
                    icon: Icons.inventory_2_outlined,
                    text: 'No tienes encomiendas activas.',
                    onTap: () =>
                        _push(context, const EncomiendaFormScreen()),
                  );
                }
                return Column(
                  children: [
                    for (final (index, encomienda) in enCurso.indexed)
                      Padding(
                        key: ValueKey(encomienda.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EncomiendaTicket(
                          encomienda: encomienda,
                          index: index,
                          onTap: () => _push(
                            context,
                            EncomiendaDetailScreen(encomienda: encomienda),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const _ViajerosParaTi(),
          ],
        ),
      ),
    );
  }
}

/// Viajes de otras personas que coinciden con la ruta de tus encomiendas
/// publicadas: así se entera el remitente de que alguien puede llevarla.
class _ViajerosParaTi extends StatelessWidget {
  const _ViajerosParaTi();

  static const _maxRutas = 3;

  Future<List<(Viaje, Encomienda)>> _load(BuildContext context) async {
    final api = context.read<LapticonApi>();
    final uid = context.read<Session>().uid;
    final disponibles = (await api.misEncomiendas())
        .where((e) => e.estado == 'disponible')
        .toList();
    final rutas = <String, Encomienda>{};
    for (final e in disponibles) {
      rutas.putIfAbsent(
        '${e.ciudadOrigen}|${e.ciudadDestino}'.toLowerCase(),
        () => e,
      );
    }
    final resultados = await Future.wait([
      for (final e in rutas.values.take(_maxRutas))
        api
            .viajesDisponibles(origen: e.ciudadOrigen, destino: e.ciudadDestino)
            .then((viajes) => [
                  for (final v in viajes)
                    if (v.uid != uid) (v, e),
                ])
            .catchError((Object _) => <(Viaje, Encomienda)>[]),
    ]);
    return resultados.expand((r) => r).toList();
  }

  @override
  Widget build(BuildContext context) => Loader<List<(Viaje, Encomienda)>>(
        load: () => _load(context),
        placeholder: const SizedBox.shrink(),
        builder: (context, ofertas, _) {
          if (ofertas.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              const SectionTitle('Viajeros para tus encomiendas'),
              for (final (index, (viaje, encomienda))
                  in ofertas.take(4).indexed)
                Padding(
                  key: ValueKey('${viaje.uid}-${encomienda.id}-$index'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ViajeroTicket(
                    viaje: viaje,
                    index: index,
                    onTap: () => showViajeroSheet(
                      context,
                      viaje: viaje,
                      actionLabel: 'Ver mi encomienda',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              EncomiendaDetailScreen(encomienda: encomienda),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      child: Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground, size: 26),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: text.titleLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon),
          title: Text(text),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
