import 'package:flutter/material.dart';

/// Marca de Lapticon: una "L" trazada como ruta, de un punto de partida a un
/// punto de llegada.
class LapticonMark extends StatelessWidget {
  const LapticonMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.secondary,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: CustomPaint(painter: _MarkPainter(scheme.onSecondary)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * unit
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(34 * unit, 30 * unit)
      ..lineTo(34 * unit, 58 * unit)
      ..quadraticBezierTo(34 * unit, 72 * unit, 48 * unit, 72 * unit)
      ..lineTo(66 * unit, 72 * unit);
    canvas.drawPath(path, stroke);

    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(34 * unit, 26 * unit), 8 * unit, dot);
    canvas.drawCircle(Offset(72 * unit, 72 * unit), 8 * unit, dot);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
