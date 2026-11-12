import 'package:flutter/material.dart';

enum _Tone { primary, accent, success, neutral, danger }

class _Status {
  const _Status(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final _Tone tone;
}

const _statuses = {
  'disponible': _Status('Disponible', Icons.schedule, _Tone.primary),
  'contactado': _Status('Contactado', Icons.forum_outlined, _Tone.accent),
  'tomada': _Status('Tomada', Icons.local_shipping_outlined, _Tone.accent),
  'entregada': _Status('Entregada', Icons.where_to_vote_outlined, _Tone.accent),
  'recibida': _Status('Recibida', Icons.check_circle_outline, _Tone.success),
  'completado': _Status('Completado', Icons.check_circle_outline, _Tone.success),
  'vencida': _Status('Vencida', Icons.event_busy_outlined, _Tone.neutral),
  'cancelada': _Status('Cancelada', Icons.cancel_outlined, _Tone.danger),
  'cancelado': _Status('Cancelado', Icons.cancel_outlined, _Tone.danger),
};

/// Estado de un viaje o una encomienda. Siempre combina color, ícono y texto,
/// para que no dependa solo del color.
class StatusChip extends StatelessWidget {
  const StatusChip(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statuses[estado] ??
        _Status(estado, Icons.info_outline, _Tone.neutral);
    final (background, foreground) = switch (status.tone) {
      _Tone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _Tone.accent => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _Tone.success => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _Tone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      _Tone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
