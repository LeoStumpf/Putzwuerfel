import 'package:flutter/material.dart';

/// Ein Würfel mit 1–6 Augen.
class DiceFace extends StatelessWidget {
  const DiceFace({super.key, required this.value, this.size = 120});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: scheme.primary, width: size * 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: size * 0.1,
              offset: Offset(0, size * 0.05),
            ),
          ],
        ),
        child: CustomPaint(painter: _PipPainter(value, scheme.primary)),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  _PipPainter(this.value, this.color);

  final int value;
  final Color color;

  // Positionen im 3×3-Raster (0..2).
  static const _layouts = <int, List<(int, int)>>{
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final step = size.width / 4;
    final r = size.width * 0.085;
    for (final (x, y) in _layouts[value.clamp(1, 6)]!) {
      canvas.drawCircle(Offset(step * (x + 1), step * (y + 1)), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.value != value || old.color != color;
}
