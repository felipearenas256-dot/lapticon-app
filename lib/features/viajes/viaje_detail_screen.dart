import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/tickets.dart';
import '../encomiendas/encomienda_detail_screen.dart';

class ViajeDetailScreen extends StatefulWidget {
  const ViajeDetailScreen({super.key, required this.viaje});

  final Viaje viaje;

  @override
  State<ViajeDetailScreen> createState() => _ViajeDetailScreenState();
}

class _ViajeDetailScreenState extends State<ViajeDetailScreen> {
  late Viaje _viaje = widget.viaje;
  bool _busy = false;

  Future<void> _changeState(String estado, String done) async {
    final id = _viaje.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await context.read<LapticonApi>().cambiarEstadoViaje(id, estado);
      if (!mounted) return;
      setState(() => _viaje = _viaje.copyWith(estado: estado));
      context.read<Revision>().bump();
      showSuccess(context, done);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Completar viaje',
      message: 'Después podrás registrar un viaje nuevo.',
      confirmLabel: 'Completar',
    );
    if (confirmed) await _changeState('completado', 'Viaje completado.');
  }

  Future<void> _cancel() async {
    final confirmed = await confirmAction(
      context,
      title: 'Cancelar viaje',
      message: 'Dejarás de aparecer como viajero en esta ruta.',
      confirmLabel: 'Cancelar viaje',
      destructive: true,
    );
    if (confirmed) await _changeState('cancelado', 'Viaje cancelado.');
  }

  void _openEncomienda(Encomienda encomienda) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EncomiendaDetailScreen(encomienda: encomienda),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final viaje = _viaje;
    final api = context.read<LapticonApi>();
    final uid = context.read<Session>().uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Viaje')),
      body: SafeArea(
        child: ListView(
          padding: pagePadding,
          children: [
            ViajeTicket(viaje: viaje, highlighted: viaje.activo),
            if (viaje.activo) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _cancel,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BusyButton(
                      label: 'Completar',
                      busy: _busy,
                      onPressed: _complete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Loader<EncomiendasEnRuta>(
                placeholder: const TicketSkeletons(count: 1),
                load: () => api.encomiendasEnRuta(
                  origen: viaje.ciudadOrigen,
                  destino: viaje.ciudadDestino,
                ),
                builder: (context, data, _) {
                  final disponibles =
                      data.disponibles.where((e) => e.uid != uid).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.tomadas.isNotEmpty) ...[
                        const SectionTitle('Encomiendas a tu cargo'),
                        _EncomiendaList(data.tomadas, _openEncomienda),
                      ],
                      const SectionTitle('Disponibles en tu ruta'),
                      if (disponibles.isEmpty)
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Nada por ahora',
                          message: 'Cuando alguien publique una encomienda en '
                              'esta ruta aparecerá aquí.',
                        )
                      else
                        _EncomiendaList(disponibles, _openEncomienda),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EncomiendaList extends StatelessWidget {
  const _EncomiendaList(this.encomiendas, this.onOpen);

  final List<Encomienda> encomiendas;
  final ValueChanged<Encomienda> onOpen;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, encomienda) in encomiendas.indexed)
            Padding(
              key: ValueKey(encomienda.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: EncomiendaTicket(
                encomienda: encomienda,
                index: index,
                onTap: () => onOpen(encomienda),
              ),
            ),
        ],
      );
}
