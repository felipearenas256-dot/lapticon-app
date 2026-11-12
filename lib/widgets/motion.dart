import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Duraciones y curvas compartidas por todas las animaciones de la app.
///
/// Todas respetan la opción del teléfono "Quitar animaciones": si está
/// activa, los cambios ocurren al instante.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 420);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Transición entre pantallas: la nueva entra deslizándose un poco desde la
/// derecha mientras aparece, y la anterior se corre levemente a la izquierda.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  Duration get reverseTransitionDuration => Motion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;

    final incoming = CurvedAnimation(
      parent: animation,
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    );

    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0))
          .animate(outgoing),
      child: SlideTransition(
        position: Tween(begin: const Offset(0.12, 0), end: Offset.zero)
            .animate(incoming),
        child: FadeTransition(opacity: incoming, child: child),
      ),
    );
  }
}

/// Encoge un poco lo que se toca, como respuesta inmediata al dedo.
///
/// Si el dedo se desliza (por ejemplo, al hacer scroll en una lista), la
/// tarjeta vuelve a su tamaño para no quedarse "hundida".
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  Offset? _origin;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (event) {
        _origin = event.position;
        _set(true);
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (origin != null && (event.position - origin).distance > 8) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: _pressed ? const Duration(milliseconds: 90) : Motion.fast,
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Hace aparecer un elemento subiendo un poco mientras se vuelve visible.
///
/// Con [index] los elementos de una lista aparecen uno detrás de otro. Desde
/// el elemento 8 en adelante ya no se anima, para que el scroll largo no
/// se sienta lento.
class EntranceAnimation extends StatefulWidget {
  const EntranceAnimation({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  static const _step = 50;
  static const _maxAnimated = 8;

  late final int _delay = _step * math.min(widget.index, _maxAnimated);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: Motion.slow.inMilliseconds + _delay),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay / _controller.duration!.inMilliseconds,
      1,
      curve: Motion.enter,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.index >= _maxAnimated || Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(_curve),
          child: widget.child,
        ),
      );
}

/// Igual que [IndexedStack], pero al cambiar de pestaña la nueva aparece con
/// un fundido corto. Conserva el estado de cada pestaña.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Motion.enter);

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !Motion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
              .animate(_curve),
          child: IndexedStack(index: widget.index, children: widget.children),
        ),
      );
}

/// Círculo con un check que aparece con un pequeño rebote. Se usa para
/// confirmar que algo salió bien.
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: size * 0.66, color: scheme.onTertiary),
    );
    if (Motion.reduced(context)) return circle;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: circle,
    );
  }
}
