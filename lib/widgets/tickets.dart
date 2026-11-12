import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'route_ticket.dart';
import 'status_chip.dart';

class ViajeTicket extends StatelessWidget {
  const ViajeTicket({
    super.key,
    required this.viaje,
    this.onTap,
    this.highlighted = false,
    this.index = 0,
  });

  final Viaje viaje;
  final int index;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [
      formatDateOnly(viaje.fechaViaje),
      ?viaje.numeroVuelo,
    ].join('  ·  ');

    return RouteTicket(
      origen: viaje.ciudadOrigen,
      destino: viaje.ciudadDestino,
      onTap: onTap,
      highlighted: highlighted,
      index: index,
      semanticLabel: 'Viaje de ${viaje.ciudadOrigen} a ${viaje.ciudadDestino}, '
          '$detail, estado ${viaje.estado}',
      footer: Row(
        children: [
          const Icon(Icons.event_outlined, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: highlighted ? theme.colorScheme.onPrimary : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(viaje.estado),
        ],
      ),
    );
  }
}

class EncomiendaTicket extends StatelessWidget {
  const EncomiendaTicket({
    super.key,
    required this.encomienda,
    this.onTap,
    this.index = 0,
  });

  final Encomienda encomienda;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final value = formatMoney(encomienda.valor, encomienda.moneda);

    return RouteTicket(
      origen: encomienda.ciudadOrigen,
      destino: encomienda.ciudadDestino,
      icon: Icons.inventory_2_outlined,
      onTap: onTap,
      index: index,
      semanticLabel:
          'Encomienda de ${encomienda.ciudadOrigen} a '
          '${encomienda.ciudadDestino}, valor $value, '
          'estado ${encomienda.estado}',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(encomienda.estado),
            ],
          ),
          if (encomienda.observaciones != null) ...[
            const SizedBox(height: 4),
            Text(
              encomienda.observaciones!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
          if (encomienda.nombreRemitente != null) ...[
            const SizedBox(height: 4),
            Text(
              'Enviada por ${encomienda.nombreRemitente}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
