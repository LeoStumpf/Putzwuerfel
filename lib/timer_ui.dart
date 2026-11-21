import 'dart:async';

import 'package:flutter/material.dart';

import 'timer.dart';
import 'ui.dart';

String _mmss(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _tasks(int n) => '$n ${n == 1 ? 'Aufgabe' : 'Aufgaben'}';

/// Leiste oben, solange ein Putz-Timer läuft (oder gerade abgelaufen ist).
class TimerBar extends StatefulWidget {
  const TimerBar({super.key, required this.timer});

  final ChoreTimer timer;

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.timer;
    final over = t.isOver;
    final title = over ? 'ZEIT UM!' : _mmss(t.remaining);
    final sub = over
        ? (t.done == 0
              ? '${t.minutes} Minuten sind vorbei.'
              : '${_tasks(t.done)} in ${t.minutes} min geschafft!')
        : (t.done == 0
              ? 'Putz-Timer · los geht\'s!'
              : '${_tasks(t.done)} erledigt');
    return Container(
      key: const Key('timerBar'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: over ? K.cream : K.mustard,
        border: const Border.fromBorderSide(BorderSide(color: K.ink, width: 3)),
        boxShadow: const [BoxShadow(color: K.ink, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          Icon(
            over ? Icons.emoji_events_outlined : Icons.timer_outlined,
            color: K.ink,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  key: const Key('timerTitle'),
                  style: const TextStyle(
                    fontFamily: K.display,
                    fontSize: 22,
                    height: 1.1,
                    color: K.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    color: K.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key(over ? 'timerOk' : 'timerStop'),
            style: TextButton.styleFrom(
              foregroundColor: K.ink,
              textStyle: const TextStyle(
                fontFamily: K.body,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            onPressed: t.stop,
            child: Text(over ? 'OK' : 'Stopp'),
          ),
        ],
      ),
    );
  }
}

/// Unauffälliger Knopf unter „Jetzt würfeln!“.
class TimerOpenButton extends StatelessWidget {
  const TimerOpenButton({super.key, required this.timer});

  final ChoreTimer timer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const Key('timerOpen'),
        style: TextButton.styleFrom(
          foregroundColor: K.soft,
          textStyle: const TextStyle(
            fontFamily: K.body,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        onPressed: () => showTimerSheet(context, timer),
        icon: const Icon(Icons.timer_outlined),
        label: const Text('Putz-Timer stellen'),
      ),
    );
  }
}

Future<void> showTimerSheet(BuildContext context, ChoreTimer timer) async {
  final minutes = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TimerSheet(initial: timer.lastMinutes),
  );
  if (minutes != null) await timer.start(minutes);
}

class _TimerSheet extends StatefulWidget {
  const _TimerSheet({required this.initial});

  final int initial;

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  late int _min = widget.initial;

  void _step(int d) => setState(() {
    final next = d > 0 ? (_min < 5 ? 5 : _min + 5) : (_min <= 5 ? 1 : _min - 5);
    _min = next.clamp(ChoreTimer.minMinutes, ChoreTimer.maxMinutes);
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: creamTheme(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PUTZ-TIMER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: K.display,
                  fontSize: 24,
                  color: K.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nimm dir ein paar Minuten und schau, wie weit du kommst. '
                'Kein Klingeln – nur ein stiller Hinweis, solange er läuft.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: K.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final p in ChoreTimer.presets) ...[
                    if (p != ChoreTimer.presets.first)
                      const SizedBox(width: 10),
                    Expanded(child: _preset(p)),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    key: const Key('timerMinus'),
                    onPressed: _min > ChoreTimer.minMinutes
                        ? () => _step(-1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      '$_min min',
                      key: const Key('timerValue'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: K.display,
                        fontSize: 26,
                        color: K.ink,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('timerPlus'),
                    onPressed: _min < ChoreTimer.maxMinutes
                        ? () => _step(1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PopButton(
                key: const Key('timerGo'),
                label: 'TIMER STARTEN',
                icon: Icons.play_arrow_rounded,
                height: 56,
                fontSize: 18,
                shadowOffset: 5,
                onPressed: () => Navigator.pop(context, _min),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preset(int p) {
    final sel = p == _min;
    return GestureDetector(
      key: Key('preset-$p'),
      onTap: () => setState(() => _min = p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? K.green : Colors.transparent,
          border: const Border.fromBorderSide(
            BorderSide(color: K.ink, width: 3),
          ),
          boxShadow: sel
              ? const [BoxShadow(color: K.ink, offset: Offset(3, 3))]
              : null,
        ),
        child: Text(
          '$p MIN',
          style: TextStyle(
            fontFamily: K.display,
            fontSize: 18,
            color: sel ? K.cream : K.ink,
          ),
        ),
      ),
    );
  }
}
