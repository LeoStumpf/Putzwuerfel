import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putzwuerfel/main.dart';
import 'package:putzwuerfel/store.dart';
import 'package:putzwuerfel/timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotifier implements TimerNotifier {
  final log = <String>[];
  @override
  Future<void> requestPermission() async => log.add('perm');
  @override
  Future<void> showRunning({
    required DateTime endsAt,
    required int minutes,
    required int done,
  }) async => log.add('show $minutes $done');
  @override
  Future<void> cancel() async => log.add('cancel');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Timer zählt Erledigtes nur während der Laufzeit, ohne Klingeln',
    () async {
      var now = DateTime(2026, 11, 21, 18);
      final n = _FakeNotifier();
      final prefs = await SharedPreferences.getInstance();
      final t = ChoreTimer(prefs, notifier: n, clock: () => now);
      expect(t.active, isFalse);
      expect(t.lastMinutes, 15);

      await t.start(10);
      expect(t.running, isTrue);
      expect(t.remaining, const Duration(minutes: 10));
      await t.countDone();
      await t.countDone();
      await t.uncountDone();
      expect(t.done, 1);
      expect(n.log, [
        'perm',
        'show 10 0',
        'show 10 1',
        'show 10 2',
        'show 10 1',
      ]);

      // Übersteht einen Neustart.
      final t2 = ChoreTimer(prefs, clock: () => now);
      expect(t2.running, isTrue);
      expect(t2.done, 1);
      expect(t2.lastMinutes, 10);

      now = now.add(const Duration(minutes: 11));
      expect(t.isOver, isTrue);
      expect(t.remaining, Duration.zero);
      await t.countDone(); // zählt nicht mehr
      expect(t.done, 1);

      await t.stop();
      expect(t.active, isFalse);
      expect(n.log.last, 'cancel');
    },
  );

  testWidgets('Timer stellen, würfeln, erledigen zählt mit', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = ChoreStore(prefs, seedDefaults: false);
    await store.add('Müll rausbringen');
    final timer = ChoreTimer(prefs);
    await tester.pumpWidget(ChoreDiceApp(store: store, timer: timer));

    await tester.tap(find.byKey(const Key('timerOpen')));
    await tester.pumpAndSettle();
    expect(find.text('15 min'), findsOneWidget); // Vorauswahl
    await tester.tap(find.byKey(const Key('preset-30')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timerPlus')));
    await tester.pump();
    expect(find.text('35 min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('preset-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timerGo')));
    await tester.pumpAndSettle();

    expect(timer.running, isTrue);
    expect(timer.minutes, 10);
    expect(find.byKey(const Key('timerBar')), findsOneWidget);
    expect(find.byKey(const Key('timerOpen')), findsNothing);

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timerBar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(timer.done, 1);
    expect(find.text('1 Aufgabe erledigt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timerStop')));
    await tester.pumpAndSettle();
    expect(timer.active, isFalse);
    expect(find.byKey(const Key('timerBar')), findsNothing);
  });
}
