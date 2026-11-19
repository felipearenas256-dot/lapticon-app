import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'common.dart';
import 'ratings.dart';
import 'route_ticket.dart';

/// Un viaje publicado por otra persona, ofrecido a quien necesita enviar algo
/// por esa ruta.
class ViajeroTicket extends StatelessWidget {
  const ViajeroTicket({
    super.key,
    required this.viaje,
    this.onTap,
    this.index = 0,
    this.mine = false,
  });

  final Viaje viaje;
  final VoidCallback? onTap;
  final int index;

  /// Es el viaje de quien mira: se marca como suyo y no se le ofrece.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = viaje.uid;
    final name = viaje.nombreUsuario ?? 'Viajero';

    return RouteTicket(
      origen: viaje.ciudadOrigen,
      destino: viaje.ciudadDestino,
      index: index,
      semanticLabel: '${mine ? 'Tu viaje' : name}: viaja de ${viaje.ciudadOrigen} a '
          '${viaje.ciudadDestino} el ${formatDateOnly(viaje.fechaViaje)}',
      highlighted: mine,
      onTap: onTap,
      footer: Row(
        children: [
          UserAvatar(name: name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? 'Tu viaje · así lo ven los demás' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: mine ? theme.colorScheme.onPrimary : null,
                  ),
                ),
                if (uid != null && !mine) RatingBadge(uid: uid),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDateOnly(viaje.fechaViaje),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mine ? theme.colorScheme.onPrimary : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Perfil del viajero con su ruta, fecha y calificaciones, y el botón para
/// enviarle una encomienda.
Future<void> showViajeroSheet(
  BuildContext context, {
  required Viaje viaje,
  String actionLabel = 'Enviar encomienda en este viaje',
  VoidCallback? onAction,
}) {
  final name = viaje.nombreUsuario ?? 'Viajero';
  final uid = viaje.uid;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.66,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                UserAvatar(name: name, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleLarge),
                      const Text('Viajero'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.flight_takeoff, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Viaja de ${viaje.ciudadOrigen} a ${viaje.ciudadDestino} '
                      'el ${formatDateOnly(viaje.fechaViaje)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onAction();
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(actionLabel),
              ),
            ],
            const SizedBox(height: 18),
            if (uid != null) RatingsSection(uid: uid),
          ],
        ),
      );
    },
  );
}
