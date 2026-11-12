import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/tickets.dart';
import 'viaje_detail_screen.dart';
import 'viaje_form_screen.dart';

class ViajesScreen extends StatelessWidget {
  const ViajesScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Text('Mis viajes', style: theme.textTheme.headlineMedium),
          ),
          Expanded(
            child: Loader<List<Viaje>>(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              load: context.read<LapticonApi>().misViajes,
              builder: (context, viajes, reload) {
                final activos = viajes.where((v) => v.activo).toList();
                final pasados = viajes.where((v) => !v.activo).toList();

                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      if (activos.isEmpty)
                        EmptyState(
                          icon: Icons.flight_takeoff,
                          title: 'No tienes un viaje activo',
                          message: 'Registra tu vuelo y mira qué encomiendas '
                              'puedes llevar.',
                          action: FilledButton.icon(
                            onPressed: () =>
                                _open(context, const ViajeFormScreen()),
                            icon: const Icon(Icons.add),
                            label: const Text('Registrar viaje'),
                          ),
                        ),
                      for (final (index, viaje) in activos.indexed) ...[
                        ViajeTicket(
                          key: ValueKey(viaje.id),
                          viaje: viaje,
                          index: index,
                          highlighted: true,
                          onTap: () => _open(
                            context,
                            ViajeDetailScreen(viaje: viaje),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (activos.isNotEmpty)
                        Text(
                          'Solo puedes tener un viaje activo a la vez.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (pasados.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const SectionTitle('Historial'),
                        for (final (index, viaje) in pasados.indexed) ...[
                          ViajeTicket(
                            key: ValueKey(viaje.id),
                            viaje: viaje,
                            index: activos.length + index,
                            onTap: () => _open(
                              context,
                              ViajeDetailScreen(viaje: viaje),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
