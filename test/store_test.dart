import 'dart:math';

import 'package:putzwuerfel/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ChoreStore> newStore() async {
  final prefs = await SharedPreferences.getInstance();
  return ChoreStore(prefs, seedDefaults: false);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('einmalige Aufgabe wird beim Erledigen gelöscht', () async {
    final s = await newStore();
    final c = (await s.add('Glühbirne wechseln'))!;
    expect(s.pot.map((e) => e.title), ['Glühbirne wechseln']);
    await s.complete(c.id);
    expect(s.pot, isEmpty);
    expect(s.byId(c.id), isNull);
  });

  test('wiederkehrende bleibt in der Bibliothek und kann zurück', () async {
    final s = await newStore();
    final c = (await s.add('Spülmaschine ausräumen', repeating: true))!;
    await s.complete(c.id);
    expect(s.pot, isEmpty);
    expect(s.library.single.title, 'Spülmaschine ausräumen');
    expect(s.hasRepeatingOutsidePot, isTrue);
    await s.addToPot(c.id);
    expect(s.pot.single.id, c.id);
  });

  test('roll zieht nur aus dem Topf, leer -> null', () async {
    final s = await newStore();
    expect(s.roll(), isNull);
    final a = (await s.add('A', repeating: true))!;
    final b = (await s.add('B'))!;
    await s.complete(a.id);
    final rnd = Random(1);
    for (var i = 0; i < 50; i++) {
      expect(s.roll(rnd)!.id, b.id);
    }
  });

  test('roll erreicht alle Aufgaben', () async {
    final s = await newStore();
    for (final t in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']) {
      await s.add(t);
    }
    final rnd = Random(42);
    final seen = {for (var i = 0; i < 500; i++) s.roll(rnd)!.title};
    expect(seen.length, 8);
  });

  test('leere Titel werden ignoriert', () async {
    final s = await newStore();
    expect(await s.add('   '), isNull);
    expect(s.pot, isEmpty);
  });

  test('Persistenz-Roundtrip', () async {
    final s = await newStore();
    final r = (await s.add('Bad putzen', repeating: true))!;
    await s.add('Paket abholen');
    await s.complete(r.id);
    final s2 = await newStore();
    expect(s2.pot.map((e) => e.title), ['Paket abholen']);
    expect(s2.library.single.title, 'Bad putzen');
    expect(s2.library.single.inPot, isFalse);
  });

  test('restore macht Erledigen rückgängig', () async {
    final s = await newStore();
    final c = (await s.add('Müll'))!;
    await s.complete(c.id);
    await s.restore(Chore(id: c.id, title: c.title));
    expect(s.pot.single.title, 'Müll');
  });

  test('draw merkt sich die aktuelle Aufgabe, Erledigen löscht sie', () async {
    final s = await newStore();
    final c = (await s.add('Bad putzen', repeating: true))!;
    expect((await s.draw(Random(1)))!.id, c.id);
    expect(s.current!.id, c.id);
    expect((await newStore()).current!.id, c.id);
    await s.complete(c.id);
    expect(s.current, isNull);
    expect((await newStore()).current, isNull);
  });

  test('makeRepeating ändert nur den Typ', () async {
    final s = await newStore();
    final c = (await s.add('Keller'))!;
    await s.setCurrent(c.id);
    await s.makeRepeating(c.id);
    expect(s.current!.repeating, isTrue);
    expect(s.current!.inPot, isTrue);
    expect(s.library.single.id, c.id);
  });

  test(
    'addToLibrary holt erledigte einmalige als wiederkehrend zurück',
    () async {
      final s = await newStore();
      final c = (await s.add('Fenster'))!;
      await s.complete(c.id);
      expect(s.byId(c.id), isNull);
      await s.addToLibrary(Chore(id: c.id, title: c.title));
      expect(s.library.single.title, 'Fenster');
      expect(s.library.single.inPot, isFalse);
      expect(s.pot, isEmpty);
    },
  );

  test(
    'erster Start: Vorschläge in der Bibliothek, Topf leer, löschbar',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final s = ChoreStore(prefs);
      expect(s.library.length, ChoreStore.defaultChores.length);
      expect(s.pot, isEmpty);
      for (final c in s.library) {
        await s.delete(c.id);
      }
      expect(ChoreStore(prefs).library, isEmpty);
    },
  );

  test('bestehende Daten werden nicht mit Vorschlägen ergänzt', () async {
    final prefs = await SharedPreferences.getInstance();
    await ChoreStore(prefs, seedDefaults: false).add('Eigenes');
    expect(ChoreStore(prefs).library, isEmpty);
    expect(ChoreStore(prefs).pot.single.title, 'Eigenes');
  });
}
