import 'dart:math';

import 'package:choredice/main.dart';
import 'package:choredice/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Aufgabe anlegen, würfeln, erledigen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ChoreStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(ChoreDiceApp(store: store, random: Random(3)));

    expect(find.textContaining('Topf ist leer'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Glühbirne wechseln');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result')), findsOneWidget);
    expect(find.text('Glühbirne wechseln'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(store.pot, isEmpty);
    expect(find.textContaining('Topf ist leer'), findsOneWidget);
  });

  testWidgets('wiederkehrende Aufgabe landet in der Bibliothek',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ChoreStore(await SharedPreferences.getInstance());
    await store.add('Spülmaschine ausräumen', repeating: true);
    await tester.pumpWidget(ChoreDiceApp(store: store, random: Random(3)));

    await tester.tap(find.byKey(const Key('roll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('done')));
    await tester.pumpAndSettle();
    expect(find.text('Wiederkehrende auffüllen'), findsOneWidget);

    await tester.tap(find.text('Bibliothek (1)'));
    await tester.pumpAndSettle();
    expect(find.text('nicht im Topf'), findsOneWidget);
    await tester.tap(find.text('Spülmaschine ausräumen'));
    await tester.pumpAndSettle();
    expect(find.text('im Topf'), findsOneWidget);
    expect(store.pot.length, 1);
  });
}
