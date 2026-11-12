import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/lapticon_api.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'loader.dart';

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.size = 18});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Semantics(
      label: '${value.toStringAsFixed(1)} de 5 estrellas',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              value >= star
                  ? Icons.star_rounded
                  : (value >= star - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
              size: size,
              color: color,
            ),
        ],
      ),
    );
  }
}

/// Promedio compacto de un usuario, para tarjetas y encabezados.
class RatingBadge extends StatefulWidget {
  const RatingBadge({super.key, required this.uid});

  final String uid;

  @override
  State<RatingBadge> createState() => _RatingBadgeState();
}

class _RatingBadgeState extends State<RatingBadge> {
  late final Future<RatingResumen> _future =
      context.read<LapticonApi>().calificaciones(widget.uid);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<RatingResumen>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final average = data?.promedio;
        if (average == null) {
          return Text(
            snapshot.connectionState == ConnectionState.waiting
                ? ' '
                : 'Sin calificaciones',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 16,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                '${formatAverage(average)} (${data!.total})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Resumen de reputación y reseñas de cualquier usuario.
class RatingsSection extends StatelessWidget {
  const RatingsSection({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) => Loader<RatingResumen>(
        load: () => context.read<LapticonApi>().calificaciones(uid),
        placeholder: const TicketSkeletons(count: 1),
        builder: (context, data, _) => _RatingsBody(data),
      );
}

class _RatingsBody extends StatelessWidget {
  const _RatingsBody(this.data);

  final RatingResumen data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.total == 0) {
      return const EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Aún no tiene calificaciones',
        message: 'Aparecen cuando se completa una entrega.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              formatAverage(data.promedio),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRow(value: data.promedio ?? 0),
                const SizedBox(height: 2),
                Text(
                  data.total == 1
                      ? '1 calificación'
                      : '${data.total} calificaciones',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final rating in data.calificaciones.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StarRow(value: rating.calificacion, size: 15),
                    const Spacer(),
                    if (rating.timestamp != null)
                      Text(
                        formatDateOnly(rating.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (rating.comentario != null) ...[
                  const SizedBox(height: 4),
                  Text(rating.comentario!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showUserSheet(
  BuildContext context, {
  required String uid,
  required String? name,
  String role = 'Viajero',
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
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
                      Text(
                        name ?? 'Usuario',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(role),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RatingsSection(uid: uid),
          ],
        ),
      ),
    );

/// Devuelve `true` si la calificación se guardó.
Future<bool> showRateSheet(
  BuildContext context, {
  required String usuarioDestino,
  required String rolDestino,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _RateSheet(
      usuarioDestino: usuarioDestino,
      rolDestino: rolDestino,
    ),
  );
  return saved ?? false;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.usuarioDestino, required this.rolDestino});

  final String usuarioDestino;
  final String rolDestino;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _comment = TextEditingController();
  int _stars = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LapticonApi>().calificar(
            usuarioDestino: widget.usuarioDestino,
            rolDestino: widget.rolDestino,
            calificacion: _stars,
            comentario: _comment.text.trim(),
          );
      if (!mounted) return;
      context.read<Revision>().bump();
      Navigator.pop(context, true);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Califica al ${widget.rolDestino}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  iconSize: 38,
                  tooltip: '$star de 5',
                  color: theme.colorScheme.secondary,
                  onPressed: _busy ? null : () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          BusyButton(
            label: 'Enviar calificación',
            busy: _busy,
            onPressed: _stars == 0 ? null : _submit,
          ),
        ],
      ),
    );
  }
}
