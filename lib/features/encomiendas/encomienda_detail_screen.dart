import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/api_exception.dart';
import '../../data/lapticon_api.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/loader.dart';
import '../../widgets/motion.dart';
import '../../widgets/ratings.dart';
import '../../widgets/route_ticket.dart';
import '../../widgets/tickets.dart';
import '../../widgets/viajeros.dart';
import '../chat/chat_screen.dart';

/// La API no tiene un endpoint para consultar una encomienda por id, así que
/// esta pantalla parte del objeto de la lista y lo actualiza tras cada acción.
///
/// Estados aceptados por el servidor: disponible, tomada, entregada, recibida y
/// vencida. El spec omite `entregada` y la colección de Postman usa `cancelada`,
/// que el servidor rechaza con 400. Por eso retirar una publicación la deja
/// como `vencida`.
class EncomiendaDetailScreen extends StatefulWidget {
  const EncomiendaDetailScreen({super.key, required this.encomienda});

  final Encomienda encomienda;

  @override
  State<EncomiendaDetailScreen> createState() => _EncomiendaDetailScreenState();
}

class _EncomiendaDetailScreenState extends State<EncomiendaDetailScreen> {
  late Encomienda _encomienda = widget.encomienda;
  bool _busy = false;
  bool _rated = false;

  LapticonApi get _api => context.read<LapticonApi>();

  Future<void> _run(
    Future<void> Function() action, {
    required String done,
    required Encomienda Function() next,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => _encomienda = next());
      context.read<Revision>().bump();
      showSuccess(context, done);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _take() async {
    final confirmed = await confirmAction(
      context,
      title: 'Tomar esta encomienda',
      message: 'Te comprometes a llevarla de ${_encomienda.ciudadOrigen} a '
          '${_encomienda.ciudadDestino}.',
      confirmLabel: 'Tomarla',
    );
    if (!confirmed || !mounted) return;
    final uid = context.read<Session>().uid;
    await _run(
      () => _api.tomarEncomienda(_encomienda.id),
      done: 'La encomienda quedó a tu cargo.',
      next: () => _encomienda.copyWith(estado: 'tomada', viajeroId: uid),
    );
  }

  Future<void> _markDelivered() async {
    final confirmed = await confirmAction(
      context,
      title: 'Marcar como entregada',
      message: 'Hazlo cuando la encomienda haya llegado a su destino. El '
          'remitente deberá confirmar que la recibió.',
      confirmLabel: 'Marcar entregada',
    );
    if (!confirmed) return;
    await _run(
      () => _api.cambiarEstadoEncomienda(_encomienda.id, 'entregada'),
      done: 'Encomienda marcada como entregada.',
      next: () => _encomienda.copyWith(estado: 'entregada'),
    );
  }

  Future<void> _confirmReceived() async {
    final confirmed = await confirmAction(
      context,
      title: 'Confirmar que la recibiste',
      message: 'Confírmalo solo cuando la encomienda esté en buenas manos.',
      confirmLabel: 'Confirmar',
    );
    if (!confirmed) return;
    await _run(
      () => _api.cambiarEstadoEncomienda(_encomienda.id, 'recibida'),
      done: 'Entrega confirmada.',
      next: () => _encomienda.copyWith(estado: 'recibida'),
    );
  }

  Future<void> _withdraw() async {
    final confirmed = await confirmAction(
      context,
      title: 'Retirar encomienda',
      message: 'Los viajeros dejarán de verla y quedará como vencida en tu '
          'lista.',
      confirmLabel: 'Retirar',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => _api.cambiarEstadoEncomienda(_encomienda.id, 'vencida'),
      done: 'Encomienda retirada.',
      next: () => _encomienda.copyWith(estado: 'vencida'),
    );
  }

  Future<void> _rate(String uid, String rol) async {
    final saved = await showRateSheet(
      context,
      usuarioDestino: uid,
      rolDestino: rol,
    );
    if (saved && mounted) {
      setState(() => _rated = true);
      showSuccess(context, '¡Gracias por tu calificación!');
    }
  }

  void _openChat({required bool otroEsViajero}) {
    final session = context.read<Session>();
    final miUid = session.uid;
    final otroUid =
        otroEsViajero ? _encomienda.viajeroId : _encomienda.uid;
    if (miUid == null || otroUid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          encomienda: _encomienda,
          miUid: miUid,
          miNombre: session.displayName,
          otroUid: otroUid,
          otroEsViajero: otroEsViajero,
          otroNombre: otroEsViajero ? null : _encomienda.nombreRemitente,
        ),
      ),
    );
  }

  void _showSuggestions() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.8,
          child: _SuggestionsSheet(encomienda: _encomienda, api: _api),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = context.select<Session, String?>((session) => session.uid);
    final encomienda = _encomienda;
    final isSender = encomienda.uid != null && encomienda.uid == uid;
    final isTraveler = encomienda.viajeroId != null &&
        encomienda.viajeroId == uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Encomienda')),
      body: SafeArea(
        child: ListView(
          padding: pagePadding,
          children: [
            EncomiendaTicket(encomienda: encomienda),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    _Line(
                      icon: Icons.calendar_today_outlined,
                      label: 'Publicada',
                      value: formatDateTime(encomienda.fechaCreacion),
                    ),
                    _Line(
                      icon: Icons.hourglass_bottom,
                      label: 'Vence',
                      value: formatDateTime(encomienda.fechaVencimiento),
                    ),
                    _Line(
                      icon: Icons.person_outline,
                      label: 'Tu rol',
                      value: isSender
                          ? 'Remitente'
                          : (isTraveler ? 'Viajero asignado' : 'Viajero'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ..._chatButton(encomienda, isSender, isTraveler),
            ..._actions(encomienda, isSender, isTraveler),
            if (encomienda.estado == 'disponible' && isSender)
              _ViajerosEnRuta(encomienda: encomienda, miUid: uid),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (encomienda.estado == 'vencida')
              Text(
                'Esta encomienda ya no está disponible para los viajeros.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Remitente y viajero pueden hablar desde que la encomienda se toma hasta
  /// que se confirma la entrega.
  List<Widget> _chatButton(Encomienda e, bool isSender, bool isTraveler) {
    const activos = {'tomada', 'entregada', 'recibida'};
    if (!activos.contains(e.estado) || e.viajeroId == null || e.uid == null) {
      return const [];
    }
    if (!isSender && !isTraveler) return const [];
    return [
      _ChatButton(
        label: isSender ? 'Chatear con el viajero' : 'Chatear con el remitente',
        onTap: () => _openChat(otroEsViajero: isSender),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _actions(Encomienda e, bool isSender, bool isTraveler) {
    final enabled = !_busy;

    if (e.estado == 'disponible' && !isSender) {
      return [
        FilledButton.icon(
          onPressed: enabled ? _take : null,
          icon: const Icon(Icons.back_hand_outlined),
          label: const Text('Tomar esta encomienda'),
        ),
      ];
    }
    if (e.estado == 'disponible' && isSender) {
      return [
        OutlinedButton.icon(
          onPressed: _showSuggestions,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Ver viajeros sugeridos'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: enabled ? _withdraw : null,
          child: const Text('Retirar encomienda'),
        ),
      ];
    }
    if (e.estado == 'tomada' && isTraveler) {
      return [
        FilledButton.icon(
          onPressed: enabled ? _markDelivered : null,
          icon: const Icon(Icons.where_to_vote_outlined),
          label: const Text('Marcar como entregada'),
        ),
      ];
    }
    if ((e.estado == 'tomada' || e.estado == 'entregada') && isSender) {
      return [
        FilledButton.icon(
          onPressed: enabled ? _confirmReceived : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirmar que la recibí'),
        ),
      ];
    }
    if (e.estado == 'entregada' && isTraveler) {
      return [
        Text(
          'Esperando a que el remitente confirme.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ];
    }
    if (e.estado == 'recibida' && !_rated) {
      final viajero = e.viajeroId;
      final remitente = e.uid;
      if (isSender && viajero != null) {
        return [
          OutlinedButton.icon(
            onPressed: () => _rate(viajero, 'viajero'),
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('Calificar al viajero'),
          ),
        ];
      }
      if (isTraveler && remitente != null) {
        return [
          OutlinedButton.icon(
            onPressed: () => _rate(remitente, 'remitente'),
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('Calificar al remitente'),
          ),
        ];
      }
    }
    return const [];
  }
}

/// Viajes publicados por otras personas en la misma ruta. Cada viajero ve esta
/// encomienda en "Disponibles en tu ruta" de su viaje y puede tomarla.
class _ViajerosEnRuta extends StatelessWidget {
  const _ViajerosEnRuta({required this.encomienda, required this.miUid});

  final Encomienda encomienda;
  final String? miUid;

  bool esMio(Viaje v) => miUid != null && v.uid == miUid;

  String _titulo(List<Viaje> viajes) {
    final otros = viajes.where((v) => !esMio(v)).length;
    if (viajes.isEmpty) return 'Viajeros en tu ruta';
    if (otros == 0) return 'Tu viaje va por esta ruta';
    return otros == 1
        ? '1 viajero va por tu ruta'
        : '$otros viajeros van por tu ruta';
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<LapticonApi>();
    return Loader<List<Viaje>>(
      placeholder: const TicketSkeletons(count: 1),
      load: () async {
        final viajes = await api.viajesDisponibles(
          origen: encomienda.ciudadOrigen,
          destino: encomienda.ciudadDestino,
        );
        // El viaje propio también se muestra, primero y marcado.
        return [
          ...viajes.where((v) => esMio(v)),
          ...viajes.where((v) => !esMio(v)),
        ];
      },
      builder: (context, viajes, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SectionTitle(_titulo(viajes)),
          if (viajes.isEmpty)
            const EmptyState(
              icon: Icons.flight_outlined,
              title: 'Aún nadie viaja por esta ruta',
              message: 'Cuando alguien registre un viaje de '
                  'esta ruta aparecerá aquí y verá tu encomienda.',
            )
          else ...[
            Text(
              viajes.every(esMio)
                  ? 'Tu viaje coincide con esta ruta. Los demás viajeros que '
                      'vayan por aquí también aparecerán y podrán tomarla.'
                  : 'Ya ven tu encomienda en su viaje y pueden tomarla.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            for (final (index, viaje) in viajes.indexed)
              Padding(
                key: ValueKey('${viaje.uid}-$index'),
                padding: const EdgeInsets.only(bottom: 12),
                child: ViajeroTicket(
                  viaje: viaje,
                  index: index,
                  mine: esMio(viaje),
                  onTap: esMio(viaje)
                      ? null
                      : () => showViajeroSheet(context, viaje: viaje),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Acceso al chat, destacado como en las apps de transporte.
class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Acuerden dónde y cuándo se ven',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsSheet extends StatefulWidget {
  const _SuggestionsSheet({required this.encomienda, required this.api});

  final Encomienda encomienda;
  final LapticonApi api;

  @override
  State<_SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends State<_SuggestionsSheet> {
  late final Future<List<Viaje>> _future = widget.api.sugerirViajes(
    ciudadOrigen: widget.encomienda.ciudadOrigen,
    ciudadDestino: widget.encomienda.ciudadDestino,
    valorEncomienda: widget.encomienda.valor ?? 0,
    fechaEncomienda: widget.encomienda.fechaCreacion,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Viaje>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Sugerencias no disponibles',
              message: error is ApiException &&
                      error.kind == ApiErrorKind.server
                  ? 'El servicio de sugerencias no responde por ahora.'
                  : friendlyError(error!),
            );
          }
          final viajes = snapshot.data ?? const <Viaje>[];
          if (viajes.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Sin sugerencias por ahora',
              message: 'Cuando un viajero la tome verás el cambio de estado aquí.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                'Viajeros sugeridos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final (index, viaje) in viajes.indexed)
                Padding(
                  key: ValueKey('${viaje.id}-$index'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionTicket(viaje),
                ),
            ],
          );
        },
      );
}

/// Las sugerencias traen el `uid`, pero no el nombre del viajero.
class _SuggestionTicket extends StatelessWidget {
  const _SuggestionTicket(this.viaje);

  final Viaje viaje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = viaje.uid;
    final afinidad = viaje.afinidad;

    return RouteTicket(
      origen: viaje.ciudadOrigen,
      destino: viaje.ciudadDestino,
      onTap: uid == null
          ? null
          : () => showUserSheet(context, uid: uid, name: null),
      footer: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateOnly(viaje.fechaViaje),
                  style: theme.textTheme.bodyMedium,
                ),
                if (uid != null) RatingBadge(uid: uid),
              ],
            ),
          ),
          if (afinidad != null)
            Text(
              '${(afinidad * 100).round()} % de afinidad',
              style: theme.textTheme.labelLarge,
            ),
        ],
      ),
    );
  }
}
