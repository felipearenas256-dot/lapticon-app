import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/chat_service.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/status_chip.dart';

/// Chat entre el remitente y el viajero de una encomienda, al estilo de las
/// apps de transporte: quién es la otra persona, la ruta, mensajes rápidos,
/// aviso de "escribiendo" y de "visto".
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.encomienda,
    required this.miUid,
    required this.miNombre,
    required this.otroUid,
    required this.otroEsViajero,
    this.otroNombre,
  });

  final Encomienda encomienda;
  final String miUid;
  final String miNombre;
  final String otroUid;

  /// Si la otra persona es quien lleva la encomienda.
  final bool otroEsViajero;

  /// Nombre conocido de antemano (el remitente viene en la encomienda).
  final String? otroNombre;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final ChatService _chat = context.read<ChatService>();
  late final String _chatId = widget.encomienda.id;

  late final Future<void> _opening = _chat.abrir(
    chatId: _chatId,
    participantes: widget.otroEsViajero
        ? [widget.miUid, widget.otroUid]
        : [widget.otroUid, widget.miUid],
    miUid: widget.miUid,
    miNombre: widget.miNombre,
  );

  // Se leen después de abrir el chat: antes no existe y las reglas de
  // Firestore rechazarían la lectura.
  late final Stream<ChatInfo> _info = Stream.fromFuture(_opening)
      .asyncExpand((_) => _chat.info(_chatId))
      .asBroadcastStream();
  late final Stream<List<ChatMessage>> _mensajes =
      Stream.fromFuture(_opening).asyncExpand((_) => _chat.mensajes(_chatId));

  /// Los mensajes que ya estaban al abrir no se animan; solo los nuevos.
  Set<String>? _initialIds;
  bool _typingSent = false;
  Timer? _typingTimer;
  int _lastCount = 0;

  List<String> get _quickReplies => widget.otroEsViajero
      ? const [
          '¿Dónde nos vemos?',
          '¿Cómo va el viaje?',
          'Ya la recibí, ¡gracias!',
          'Te espero a la hora acordada',
        ]
      : const [
          'Ya tengo tu encomienda',
          'Voy en camino',
          'Llegué al destino',
          '¿Dónde te la entrego?',
        ];

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_typingSent) _chat.escribiendo(_chatId, widget.miUid, false);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    final hasText = _text.text.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      _chat.escribiendo(_chatId, widget.miUid, true).ignore();
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (_typingSent) {
        _typingSent = false;
        _chat.escribiendo(_chatId, widget.miUid, false).ignore();
      }
    });
  }

  Future<void> _send([String? quick]) async {
    final texto = (quick ?? _text.text).trim();
    if (texto.isEmpty) return;
    if (quick == null) _text.clear();
    _typingSent = false;
    try {
      await _opening;
      await _chat.enviar(_chatId, widget.miUid, texto);
    } catch (error) {
      if (!mounted) return;
      if (quick == null && _text.text.isEmpty) _text.text = texto;
      showMessage(context, 'No se pudo enviar: ${_friendly(error)}');
    }
  }

  String _friendly(Object error) => error is ChatUnavailable
      ? error.toString()
      : 'revisa tu conexión e inténtalo de nuevo.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<ChatInfo>(
      stream: _info,
      builder: (context, infoSnapshot) {
        final info = infoSnapshot.data ?? const ChatInfo();
        final otroNombre = info.nombres[widget.otroUid] ??
            widget.otroNombre ??
            (widget.otroEsViajero ? 'Tu viajero' : 'Remitente');
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: _Header(
              nombre: otroNombre,
              rol: widget.otroEsViajero ? 'Lleva tu encomienda' : 'Remitente',
              escribiendo: info.estaEscribiendo(widget.otroUid),
            ),
          ),
          body: Column(
            children: [
              _TripBar(encomienda: widget.encomienda),
              Expanded(
                child: FutureBuilder<void>(
                  future: _opening,
                  builder: (context, opened) {
                    if (opened.hasError) {
                      return _ChatError(message: _friendly(opened.error!));
                    }
                    return StreamBuilder<List<ChatMessage>>(
                      stream: _mensajes,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _ChatError(
                            message: _friendly(snapshot.error!),
                          );
                        }
                        final mensajes = snapshot.data;
                        if (mensajes == null) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        _initialIds ??= {for (final m in mensajes) m.id};
                        if (mensajes.length != _lastCount) {
                          _lastCount = mensajes.length;
                          _chat.marcarLeido(_chatId, widget.miUid).ignore();
                        }
                        return _Messages(
                          mensajes: mensajes,
                          miUid: widget.miUid,
                          otroNombre: otroNombre,
                          leidoPorOtro: info.leido[widget.otroUid],
                          escribiendo: info.estaEscribiendo(widget.otroUid),
                          initialIds: _initialIds!,
                        );
                      },
                    );
                  },
                ),
              ),
              _QuickReplies(replies: _quickReplies, onTap: _send),
              _Composer(
                controller: _text,
                focus: _focus,
                onSend: _send,
                color: scheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.nombre,
    required this.rol,
    required this.escribiendo,
  });

  final String nombre;
  final String rol;
  final bool escribiendo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = escribiendo ? 'escribiendo…' : rol;
    return Row(
      children: [
        UserAvatar(name: nombre, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              AnimatedSwitcher(
                duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
                child: Text(
                  subtitle,
                  key: ValueKey(subtitle),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: escribiendo
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: escribiendo ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Franja con la ruta y el estado, para no perder el contexto del envío.
class _TripBar extends StatelessWidget {
  const _TripBar({required this.encomienda});

  final Encomienda encomienda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${encomienda.ciudadOrigen} → ${encomienda.ciudadDestino}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(encomienda.estado),
        ],
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({
    required this.mensajes,
    required this.miUid,
    required this.otroNombre,
    required this.leidoPorOtro,
    required this.escribiendo,
    required this.initialIds,
  });

  final List<ChatMessage> mensajes;
  final String miUid;
  final String otroNombre;
  final DateTime? leidoPorOtro;
  final bool escribiendo;
  final Set<String> initialIds;

  @override
  Widget build(BuildContext context) {
    if (mensajes.isEmpty && !escribiendo) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: 'Coordina la entrega con $otroNombre',
        message: 'Acuerden dónde y cuándo se ven. Solo ustedes dos ven esta '
            'conversación.',
      );
    }

    // La lista va al revés para que lo más nuevo quede abajo, junto al
    // teclado, como en cualquier chat.
    final items = <Widget>[
      if (escribiendo) const _TypingBubble(key: ValueKey('typing')),
    ];
    final ultimoMio = mensajes.lastWhere(
      (m) => m.autor == miUid,
      orElse: () => ChatMessage(
        id: '',
        autor: '',
        texto: '',
        enviado: DateTime(0),
      ),
    );
    for (var i = mensajes.length - 1; i >= 0; i--) {
      final m = mensajes[i];
      final mine = m.autor == miUid;
      final prev = i > 0 ? mensajes[i - 1] : null;
      final next = i < mensajes.length - 1 ? mensajes[i + 1] : null;
      final visto = mine &&
          m.id == ultimoMio.id &&
          leidoPorOtro != null &&
          !leidoPorOtro!.isBefore(m.enviado);
      items.add(
        _Bubble(
          key: ValueKey(m.id),
          message: m,
          mine: mine,
          // Varios mensajes seguidos de la misma persona van agrupados.
          joinedAbove: prev != null && prev.autor == m.autor,
          showTime: next == null ||
              next.autor != m.autor ||
              next.enviado.difference(m.enviado).inMinutes > 5,
          visto: visto,
          animate: !initialIds.contains(m.id),
        ),
      );
      if (prev == null || !_sameDay(prev.enviado, m.enviado)) {
        items.add(_DayLabel(date: m.enviado, key: ValueKey('d${m.id}')));
      }
    }

    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: items,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? 'Hoy'
        : day == today.subtract(const Duration(days: 1))
            ? 'Ayer'
            : DateFormat("EEEE d 'de' MMMM", 'es').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.joinedAbove,
    required this.showTime,
    required this.visto,
    required this.animate,
  });

  final ChatMessage message;
  final bool mine;
  final bool joinedAbove;
  final bool showTime;
  final bool visto;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? scheme.primary : scheme.surfaceContainerLowest,
        border: mine ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.only(
          topLeft: !mine && joinedAbove ? small : big,
          topRight: mine && joinedAbove ? small : big,
          bottomLeft: mine ? big : small,
          bottomRight: mine ? small : big,
        ),
      ),
      child: Text(
        message.texto,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: mine ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
    );

    final time = DateFormat.jm('es').format(message.enviado);
    final content = Padding(
      padding: EdgeInsets.only(top: joinedAbove ? 3 : 10),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${mine ? 'Tú' : 'Mensaje'}: ${message.texto}, $time'
                '${visto ? ', visto' : ''}',
            excludeSemantics: true,
            child: bubble,
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (visto) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.done_all_rounded, size: 15, color: scheme.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Visto',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (!animate || Motion.reduced(context)) return content;
    // Los mensajes nuevos entran desde su lado y crecen un poco.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.medium,
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((mine ? 24 : -24) * (1 - t), 8 * (1 - t)),
          child: Transform.scale(
            scale: 0.92 + 0.08 * t,
            alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: content,
    );
  }
}

/// Tres puntos que suben y bajan mientras la otra persona escribe.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble({super.key});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Está escribiendo',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Transform.translate(
                    offset: Offset(0, -4 * _bounce(_controller.value, i)),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(
                          alpha: 0.4 + 0.6 * _bounce(_controller.value, i),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cada punto sube en su turno: 0 en reposo, 1 en lo más alto.
  double _bounce(double t, int i) {
    final phase = (t - i * 0.18) % 1.0;
    if (phase > 0.5) return 0;
    final x = phase / 0.5;
    return x < 0.5 ? x * 2 : (1 - x) * 2;
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.replies, required this.onTap});

  final List<String> replies;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: replies.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => Pressable(
            child: ActionChip(
              label: Text(replies[index]),
              onPressed: () => onTap(replies[index]),
            ),
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.color,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final reduced = Motion.reduced(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // El botón de enviar crece y se pinta cuando hay algo escrito.
            AnimatedScale(
              scale: hasText ? 1 : 0.86,
              duration: reduced ? Duration.zero : Motion.fast,
              curve: Curves.easeOutBack,
              child: IconButton.filled(
                tooltip: 'Enviar',
                onPressed: hasText ? onSend : null,
                iconSize: 22,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: color,
                ),
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'No pudimos abrir el chat',
            message: message,
          ),
        ),
      );
}
