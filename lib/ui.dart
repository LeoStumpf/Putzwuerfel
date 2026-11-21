import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Farben und Schriften des Putzwürfel-Designs (Spieltisch-Grün + Pop).
abstract final class K {
  static const green = Color(0xFF1F4D3A);
  static const greenDark = Color(0xFF173B2C);
  static const cream = Color(0xFFF6F1E4);
  static const red = Color(0xFFB23A24);
  static const mustard = Color(0xFFE9A23B);
  static const ink = Color(0xFF0B1F16);
  static const muted = Color(0xFFB9D3C4);
  static const soft = Color(0xFFCFE0D6);

  static const display = 'ArchivoBlack';
  static const body = 'Nunito';

  static const headline = TextStyle(
    fontFamily: display,
    fontSize: 40,
    height: 0.92,
    letterSpacing: -0.8,
    color: cream,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    color: muted,
  );
}

const _inkBorder = RoundedRectangleBorder(
    side: BorderSide(color: K.ink, width: 4));

/// Haupt-Theme: dunkles Grün mit cremefarbener Schrift.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: K.green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: K.cream,
    onPrimary: K.green,
    secondary: K.mustard,
    onSecondary: K.ink,
    surface: K.green,
    onSurface: K.cream,
    error: K.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: K.body,
    scaffoldBackgroundColor: K.green,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: K.cream,
      contentTextStyle: TextStyle(
          fontFamily: K.body,
          color: K.ink,
          fontWeight: FontWeight.w800,
          fontSize: 14),
      actionTextColor: K.red,
      shape: RoundedRectangleBorder(side: BorderSide(color: K.ink, width: 3)),
      elevation: 0,
    ),
  );
}

/// Helles Theme für Dialoge und Bottom-Sheets (creme Fläche, dunkle Schrift).
ThemeData creamTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: K.green).copyWith(
    primary: K.green,
    onPrimary: K.cream,
    surface: K.cream,
    onSurface: K.ink,
    error: K.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: K.body,
    dialogTheme: const DialogThemeData(
      backgroundColor: K.cream,
      shape: _inkBorder,
      titleTextStyle:
          TextStyle(fontFamily: K.display, fontSize: 22, color: K.ink),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: K.cream,
      shape: _inkBorder,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: K.green,
        foregroundColor: K.cream,
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(
            fontFamily: K.body, fontWeight: FontWeight.w900, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: K.green,
        textStyle: const TextStyle(
            fontFamily: K.body, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
  );
}

/// Knopf im Pop-Stil: dicker Rahmen, harter Schatten, gibt beim Drücken nach.
class PopButton extends StatefulWidget {
  const PopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = K.red,
    this.foreground = Colors.white,
    this.height = 62,
    this.fontSize = 22,
    this.shadowOffset = 6,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double height;
  final double fontSize;
  final double shadowOffset;

  @override
  State<PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<PopButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onPressed != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final full = widget.shadowOffset;
    final off = _down ? full / 3 : full;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: Padding(
          padding: EdgeInsets.only(right: full, bottom: full),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            height: widget.height,
            transform: Matrix4.translationValues(full - off, full - off, 0),
            decoration: BoxDecoration(
              color: enabled
                  ? widget.background
                  : Color.lerp(widget.background, K.green, 0.55),
              border: Border.all(color: K.ink, width: 4),
              boxShadow: [
                BoxShadow(color: K.ink, offset: Offset(off, off)),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon,
                            color: widget.foreground,
                            size: widget.fontSize + 4),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: K.display,
                          fontSize: widget.fontSize,
                          color: widget.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Putzeimer-Lostopf. [slip] 0 = Los steckt im Eimer, 1 = springt heraus;
/// [shake] dreht den Eimer (Radiant) um seinen Boden.
class Bucket extends StatelessWidget {
  const Bucket({super.key, this.size = 200, this.slip = 1, this.shake = 0});

  final double size;
  final double slip;
  final double shake;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Putzeimer mit Aufgaben-Losen',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Transform.rotate(
          angle: shake,
          alignment: const Alignment(0, 0.75),
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, (1 - slip) * size * 0.42),
                child: Opacity(
                  opacity: slip.clamp(0.0, 1.0),
                  child: SvgPicture.asset('assets/bucket_slip.svg',
                      width: size, height: size),
                ),
              ),
              SvgPicture.asset('assets/bucket_body.svg',
                  width: size, height: size),
            ],
          ),
        ),
      ),
    );
  }

  /// Animationskurve fürs Würfeln: Los fällt rein, Eimer wackelt, Los springt.
  static (double slip, double shake) at(double t) {
    double slip;
    if (t < 0.15) {
      slip = 1 - Curves.easeIn.transform(t / 0.15);
    } else if (t < 0.78) {
      slip = 0;
    } else {
      slip = Curves.elasticOut.transform((t - 0.78) / 0.22);
    }
    var shake = 0.0;
    if (t > 0.1 && t < 0.85) {
      final u = (t - 0.1) / 0.75;
      shake = sin(u * pi * 9) * 0.14 * sin(u * pi);
    }
    return (slip, shake);
  }
}

/// Kleines Kästchen vor einer Aufgabe: „1×“ für einmalig, Pfeil für
/// wiederkehrend.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.repeating, this.size = 26});

  final bool repeating;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (repeating) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: K.muted, width: 2),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.repeat,
            size: size * 0.55, color: K.muted, semanticLabel: 'wiederkehrend'),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: K.cream,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text('1×',
          semanticsLabel: 'einmalig',
          style: TextStyle(
              color: K.green,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900)),
    );
  }
}

/// Eine Zeile in der Topf-Liste.
class ChoreRow extends StatelessWidget {
  const ChoreRow(
      {super.key,
      required this.title,
      required this.repeating,
      this.compact = false});

  final String title;
  final bool repeating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: K.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
      ),
      child: Row(
        children: [
          KindBadge(repeating: repeating, size: compact ? 22 : 26),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: K.cream,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 15)),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: K.label)),
          if (trailing != null) Text(trailing!, style: K.label),
        ],
      ),
    );
  }
}

/// Gestrichelter Rahmen (für Bibliotheks-Kacheln, die nicht im Topf sind).
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.width = 3});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final rect = Offset(width / 2, width / 2) &
        Size(size.width - width, size.height - width);
    final path = Path()..addRect(rect);
    const dash = 9.0, gap = 6.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.width != width;
}
