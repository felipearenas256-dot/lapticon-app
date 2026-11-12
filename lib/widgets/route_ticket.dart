import 'package:flutter/material.dart';

/// Tarjeta de ruta con forma de pase de abordar. Es el elemento de identidad
/// de la app: viajes y encomiendas se presentan siempre de esta manera.
class RouteTicket extends StatelessWidget {
  const RouteTicket({
    super.key,
    required this.origen,
    required this.destino,
    required this.footer,
    this.icon = Icons.flight_takeoff,
    this.onTap,
    this.highlighted = false,
    this.semanticLabel,
  });

  final String origen;
  final String destino;
  final Widget footer;
  final IconData icon;
  final VoidCallback? onTap;

  /// Variante azul, para el viaje activo.
  final bool highlighted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background =
        highlighted ? scheme.primary : scheme.surfaceContainerLowest;
    final foreground = highlighted ? scheme.onPrimary : scheme.onSurface;
    final muted = highlighted
        ? scheme.onPrimary.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? 'Ruta de $origen a $destino',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: scheme.onSurface.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: background,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Stop(
                          label: 'DESDE',
                          city: origen,
                          color: foreground,
                          muted: muted,
                        ),
                      ),
                      _Connector(icon: icon, color: muted),
                      Expanded(
                        child: _Stop(
                          label: 'HASTA',
                          city: destino,
                          color: foreground,
                          muted: muted,
                          end: true,
                        ),
                      ),
                    ],
                  ),
                ),
                _Perforation(
                  notchColor: theme.scaffoldBackgroundColor,
                  dashColor: highlighted
                      ? scheme.onPrimary.withValues(alpha: 0.4)
                      : scheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: foreground),
                    child: IconTheme.merge(
                      data: IconThemeData(color: muted),
                      child: footer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.label,
    required this.city,
    required this.color,
    required this.muted,
    this.end = false,
  });

  final String label;
  final String city;
  final Color color;
  final Color muted;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment:
          end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: muted, letterSpacing: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.end : TextAlign.start,
          style: text.titleLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              right: 8,
              top: 34,
              child: CustomPaint(
                size: const Size(double.infinity, 1.5),
                painter: _DashPainter(color),
              ),
            ),
            Positioned(top: 8, child: Icon(icon, size: 22, color: color)),
          ],
        ),
      );
}

/// Línea punteada con dos muescas laterales que simulan el corte del tiquete.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.notchColor, required this.dashColor});

  final Color notchColor;
  final Color dashColor;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    Widget notch() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: notchColor, shape: BoxShape.circle),
        );

    return SizedBox(
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            right: 20,
            child: CustomPaint(
              size: const Size(double.infinity, 1.5),
              painter: _DashPainter(dashColor),
            ),
          ),
          Positioned(left: -size / 2, child: notch()),
          Positioned(right: -size / 2, child: notch()),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      final end = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}
