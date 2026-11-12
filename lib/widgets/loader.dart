import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api_exception.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'motion.dart';

/// Carga datos y resuelve los estados de espera, error y recarga.
///
/// Se actualiza solo cuando otra pantalla avisa por [Revision]. Si una recarga
/// falla pero ya había datos, los conserva en lugar de vaciar la pantalla.
class Loader<T> extends StatefulWidget {
  const Loader({
    super.key,
    required this.load,
    required this.builder,
    this.placeholder,
    this.padding = EdgeInsets.zero,
  });

  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  ) builder;
  final Widget? placeholder;

  /// Margen de los estados de espera y error cuando el contenido ocupa la
  /// pantalla completa.
  final EdgeInsets padding;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late T _data;
  bool _hasData = false;
  Object? _error;
  bool _slow = false;
  int _generation = 0;
  Timer? _slowTimer;
  Revision? _revision;

  @override
  void initState() {
    super.initState();
    _revision = context.read<Revision>()..addListener(_onRevision);
    _load();
  }

  void _onRevision() => _load(silent: true);

  Future<void> _reload() => _load();

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    _slowTimer?.cancel();
    if (!_hasData) {
      setState(() {
        _error = null;
        _slow = false;
      });
      _slowTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _slow = true);
      });
    }
    try {
      final data = await widget.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _hasData = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (_hasData) {
        if (!silent) showMessage(context, friendlyError(error));
      } else {
        setState(() => _error = error);
      }
    } finally {
      if (generation == _generation) _slowTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _revision?.removeListener(_onRevision);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Al pasar de "cargando" al contenido (o al error) hay un fundido corto.
    final state = _hasData ? 'data' : (_error != null ? 'error' : 'loading');
    return AnimatedSwitcher(
      duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(state), child: _content()),
    );
  }

  Widget _content() {
    if (_hasData) return widget.builder(context, _data, _reload);
    return SingleChildScrollView(
      padding: widget.padding,
      child: _error != null
          ? ErrorState(error: _error!, onRetry: _reload)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.placeholder ?? const TicketSkeletons(),
                if (_slow) const WakingServerNotice(),
              ],
            ),
    );
  }
}

/// Render apaga el servidor gratuito por inactividad y despertarlo toma tiempo.
class WakingServerNotice extends StatelessWidget {
  const WakingServerNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'El servidor está despertando. Puede tardar hasta un minuto.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class TicketSkeletons extends StatefulWidget {
  const TicketSkeletons({super.key, this.count = 3});

  final int count;

  @override
  State<TicketSkeletons> createState() => _TicketSkeletonsState();
}

class _TicketSkeletonsState extends State<TicketSkeletons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.7;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Semantics(
      label: 'Cargando',
      child: FadeTransition(
        opacity: _controller,
        child: Column(
          children: [
            for (var i = 0; i < widget.count; i++)
              Container(
                height: 138,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
