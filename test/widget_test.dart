import 'dart:math';

import 'package:putzwuerfel/main.dart';
import 'package:putzwuerfel/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ChoreStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return ChoreStore(await SharedPreferences.getInstance());
}

void main() {
  testWidgets('anlegen, würfeln, erst nach Erledigt zurück zum Topf',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(ChoreDiceApp(store: store, random: Random(3)));

    expect(find.textContaining('Topf ist leer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Glühbirne wechseln');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Glühbirne wechseln'), findsOneWidget);

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    expect(find.text('GLÜHBIRNE WECHSELN'), findsOneWidget);
    // Kein „Nochmal“, keine Navigation, solange die Aufgabe dran ist.
    expect(find.byKey(const Key('roll')), findsNothing);
    expect(find.byKey(const Key('tab-lib')), findsNothing);
    expect(store.current?.title, 'Glühbirne wechseln');

    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(store.pot, isEmpty);
    expect(store.current, isNull);
    expect(find.textContaining('Topf ist leer'), findsOneWidget);

    // Nach dem Erledigen: „+ Bibliothek“ übernimmt sie als wiederkehrend.
    await tester.tap(find.text('+ Bibliothek'));
    await tester.pumpAndSettle();
    expect(store.library.single.title, 'Glühbirne wechseln');
    expect(store.library.single.inPot, isFalse);
  });

  testWidgets('einmalige schon beim Ziehen zur Bibliothek hinzufügen',
      (tester) async {
    final store = await _store();
    await store.add('Keller entrümpeln');
    await tester.pumpWidget(ChoreDiceApp(store: store, random: Random(1)));

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toLibrary')));
    await tester.pumpAndSettle();
    // Aufgabe bleibt dran, ist jetzt aber wiederkehrend.
    expect(find.byKey(const Key('result')), findsOneWidget);
    expect(find.byKey(const Key('toLibrary')), findsNothing);
    expect(store.current!.repeating, isTrue);

    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(store.library.single.title, 'Keller entrümpeln');
    expect(store.pot, isEmpty);
  });

  testWidgets('wiederkehrende: nur Erledigt, danach in der Bibliothek',
      (tester) async {
    final store = await _store();
    await store.add('Spülmaschine ausräumen', repeating: true);
    await tester.pumpWidget(ChoreDiceApp(store: store, random: Random(3)));

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('toLibrary')), findsNothing);
    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(find.text('WIEDERKEHRENDE AUFFÜLLEN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-lib')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spülmaschine ausräumen'));
    await tester.pumpAndSettle();
    expect(find.text('IM TOPF'), findsOneWidget);
    expect(store.pot.length, 1);
  });

  testWidgets('gezogene Aufgabe bleibt nach Neustart dran', (tester) async {
    final store = await _store();
    final c = (await store.add('Bad putzen', repeating: true))!;
    await store.setCurrent(c.id);
    final reopened = ChoreStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(ChoreDiceApp(store: reopened));
    await tester.pumpAndSettle();
    expect(find.text('BAD PUTZEN'), findsOneWidget);
    expect(find.byKey(const Key('done')), findsOneWidget);
  });
}
