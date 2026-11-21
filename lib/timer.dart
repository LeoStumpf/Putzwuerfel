import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optionaler Motivations-Timer: „Ich nehme mir 15 Minuten und schaue, wie
/// weit ich komme.“ Klingelt nicht – läuft nur mit, zählt die erledigten
/// Aufgaben und zeigt währenddessen eine stille Benachrichtigung.
class ChoreTimer extends ChangeNotifier {
  ChoreTimer(this._prefs, {this.notifier, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  static const presets = [10, 15, 30];
  static const minMinutes = 1;
  static const maxMinutes = 120;

  static const _endKey = 'timer_end_v1';
  static const _minutesKey = 'timer_minutes_v1';
  static const _doneKey = 'timer_done_v1';
  static const _lastKey = 'timer_last_minutes_v1';

  final SharedPreferences? _prefs;
  final TimerNotifier? notifier;
  final DateTime Function() _clock;

  DateTime? _endsAt;
  int _minutes = 15;
  int _done = 0;
  int _lastMinutes = 15;

  /// Ende der laufenden Runde (null = kein Timer).
  DateTime? get endsAt => _endsAt;

  /// Länge der laufenden (bzw. abgelaufenen) Runde in Minuten.
  int get minutes => _minutes;

  /// In dieser Runde erledigte Aufgaben.
  int get done => _done;

  /// Zuletzt gewählte Dauer – Vorauswahl beim nächsten Start.
  int get lastMinutes => _lastMinutes;

  bool get active => _endsAt != null;
  bool get isOver => active && !_clock().isBefore(_endsAt!);
  bool get running => active && !isOver;

  Duration get remaining {
    final e = _endsAt;
    if (e == null) return Duration.zero;
    final r = e.difference(_clock());
    return r.isNegative ? Duration.zero : r;
  }

  void _load() {
    final p = _prefs;
    if (p == null) return;
    final end = p.getInt(_endKey);
    _endsAt = end == null ? null : DateTime.fromMillisecondsSinceEpoch(end);
    _minutes = p.getInt(_minutesKey) ?? 15;
    _done = p.getInt(_doneKey) ?? 0;
    _lastMinutes = p.getInt(_lastKey) ?? 15;
  }

  Future<void> _save() async {
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    final e = _endsAt;
    if (e == null) {
      await p.remove(_endKey);
    } else {
      await p.setInt(_endKey, e.millisecondsSinceEpoch);
    }
    await p.setInt(_minutesKey, _minutes);
    await p.setInt(_doneKey, _done);
    await p.setInt(_lastKey, _lastMinutes);
  }

  Future<void> start(int minutes) async {
    final m = minutes.clamp(minMinutes, maxMinutes);
    _minutes = m;
    _lastMinutes = m;
    _done = 0;
    _endsAt = _clock().add(Duration(minutes: m));
    await _save();
    await notifier?.requestPermission();
    await _notify();
  }

  /// Beendet die Runde (vorzeitig oder nach „Zeit um“).
  Future<void> stop() async {
    _endsAt = null;
    _done = 0;
    await _save();
    await notifier?.cancel();
  }

  /// Eine Aufgabe wurde erledigt – zählt nur, solange die Zeit läuft.
  Future<void> countDone() async {
    if (!running) return;
    _done++;
    await _save();
    await _notify();
  }

  /// „Rückgängig“ nach dem Erledigen.
  Future<void> uncountDone() async {
    if (!running || _done == 0) return;
    _done--;
    await _save();
    await _notify();
  }

  Future<void> _notify() async {
    final e = _endsAt;
    if (e == null || !running) return;
    await notifier?.showRunning(endsAt: e, minutes: _minutes, done: _done);
  }
}

/// Zeigt die stille, laufende Timer-Benachrichtigung an.
abstract interface class TimerNotifier {
  Future<void> requestPermission();
  Future<void> showRunning({
    required DateTime endsAt,
    required int minutes,
    required int done,
  });
  Future<void> cancel();
}

/// Android-Benachrichtigung mit Countdown-Chronometer. Sie ist dauerhaft
/// (nicht wegwischbar), macht keinen Ton und verschwindet am Ende von selbst
/// (`timeoutAfter`) – kein Klingeln.
class LocalTimerNotifier implements TimerNotifier {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_timer'),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> requestPermission() async {
    try {
      await _init();
      await _android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Timer-Benachrichtigung: $e');
    }
  }

  @override
  Future<void> showRunning({
    required DateTime endsAt,
    required int minutes,
    required int done,
  }) async {
    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) return;
    try {
      await _init();
      await _plugin.show(
        id: _id,
        title: 'Putz-Timer läuft · $minutes min',
        body: done == 0
            ? 'Mal sehen, wie weit du kommst!'
            : '$done ${done == 1 ? 'Aufgabe' : 'Aufgaben'} erledigt – weiter so!',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'putz_timer',
            'Putz-Timer',
            channelDescription: 'Zeigt den laufenden Putz-Timer an (ohne Ton).',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            silent: true,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: true,
            when: endsAt.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: left.inMilliseconds,
            category: AndroidNotificationCategory.stopwatch,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Timer-Benachrichtigung: $e');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('Timer-Benachrichtigung: $e');
    }
  }
}
