import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eine Aufgabe.
///
/// * Einmalig (`repeating == false`): existiert nur, solange sie im Topf ist,
///   und wird beim Erledigen gelöscht.
/// * Wiederkehrend (`repeating == true`): bleibt immer in der Bibliothek;
///   [inPot] bestimmt, ob sie gerade gewürfelt werden kann.
///
/// Eine einmalige Aufgabe wird durch „Zur Bibliothek hinzufügen“ dauerhaft
/// wiederkehrend.
class Chore {
  Chore({
    required this.id,
    required this.title,
    this.repeating = false,
    this.inPot = true,
  });

  final String id;
  String title;
  bool repeating;
  bool inPot;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'repeating': repeating,
        'inPot': inPot,
      };

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        title: json['title'] as String,
        repeating: json['repeating'] as bool? ?? false,
        inPot: json['inPot'] as bool? ?? true,
      );
}

class ChoreStore extends ChangeNotifier {
  ChoreStore(this._prefs) {
    _load();
  }

  static const _key = 'chores_v1';
  static const _currentKey = 'current_v1';

  final SharedPreferences _prefs;
  final List<Chore> _chores = [];
  int _nextId = 0;
  String? _currentId;

  /// Die gezogene Aufgabe, die gerade dran ist (bis sie erledigt ist).
  Chore? get current {
    final id = _currentId;
    if (id == null) return null;
    final c = byId(id);
    return (c != null && c.inPot) ? c : null;
  }

  /// Aufgaben, aus denen gewürfelt wird.
  List<Chore> get pot => _chores.where((c) => c.inPot).toList();

  /// Alle wiederkehrenden Aufgaben (die Bibliothek), alphabetisch.
  List<Chore> get library => _chores.where((c) => c.repeating).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  bool get hasRepeatingOutsidePot =>
      _chores.any((c) => c.repeating && !c.inPot);

  Chore? byId(String id) {
    for (final c in _chores) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _load() {
    _currentId = _prefs.getString(_currentKey);
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _chores
      ..clear()
      ..addAll(list.map(Chore.fromJson));
  }

  Future<void> _save() async {
    if (_currentId != null && current == null) _currentId = null;
    notifyListeners();
    await _prefs.setString(
        _key, jsonEncode(_chores.map((c) => c.toJson()).toList()));
    if (_currentId == null) {
      await _prefs.remove(_currentKey);
    } else {
      await _prefs.setString(_currentKey, _currentId!);
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  Future<Chore?> add(String title, {bool repeating = false}) async {
    final t = title.trim();
    if (t.isEmpty) return null;
    final chore = Chore(id: _newId(), title: t, repeating: repeating);
    _chores.add(chore);
    await _save();
    return chore;
  }

  /// Zieht gleichverteilt eine Aufgabe aus dem Topf (null, wenn leer).
  Chore? roll([Random? random]) {
    final p = pot;
    if (p.isEmpty) return null;
    return p[(random ?? Random()).nextInt(p.length)];
  }

  /// Macht [id] zur aktuellen Aufgabe (nach dem Würfeln).
  Future<void> setCurrent(String id) async {
    if (byId(id)?.inPot != true) return;
    _currentId = id;
    await _save();
  }

  /// Würfelt und merkt sich das Ergebnis als aktuelle Aufgabe.
  Future<Chore?> draw([Random? random]) async {
    final c = roll(random);
    if (c != null) await setCurrent(c.id);
    return c;
  }

  /// „Zur Bibliothek hinzufügen“: die Aufgabe bleibt, wie sie ist (auch im
  /// Topf bzw. aktuell), wird ab jetzt aber wiederkehrend.
  Future<void> makeRepeating(String id) async {
    final c = byId(id);
    if (c == null || c.repeating) return;
    c.repeating = true;
    await _save();
  }

  /// Nimmt eine schon erledigte (gelöschte) einmalige Aufgabe als
  /// wiederkehrende in die Bibliothek auf (nicht im Topf).
  Future<void> addToLibrary(Chore snapshot) async {
    final existing = byId(snapshot.id);
    if (existing != null) {
      existing.repeating = true;
    } else {
      _chores.add(Chore(
          id: snapshot.id,
          title: snapshot.title,
          repeating: true,
          inPot: false));
    }
    await _save();
  }

  /// Erledigt: einmalige werden gelöscht, wiederkehrende wandern zurück in
  /// die Bibliothek (raus aus dem Topf).
  Future<void> complete(String id) async {
    final c = byId(id);
    if (c == null) return;
    if (c.repeating) {
      c.inPot = false;
    } else {
      _chores.remove(c);
    }
    await _save();
  }

  /// Aus dem Topf nehmen, ohne zu erledigen (einmalige werden gelöscht).
  Future<void> removeFromPot(String id) => complete(id);

  Future<void> addToPot(String id) async {
    final c = byId(id);
    if (c == null || c.inPot) return;
    c.inPot = true;
    await _save();
  }

  Future<void> addAllRepeatingToPot() async {
    for (final c in _chores) {
      if (c.repeating) c.inPot = true;
    }
    await _save();
  }

  Future<void> rename(String id, String title) async {
    final c = byId(id);
    final t = title.trim();
    if (c == null || t.isEmpty) return;
    c.title = t;
    await _save();
  }

  Future<void> delete(String id) async {
    _chores.removeWhere((c) => c.id == id);
    await _save();
  }

  /// Stellt eine zuvor entfernte Aufgabe wieder her (für „Rückgängig“).
  Future<void> restore(Chore chore) async {
    final existing = byId(chore.id);
    if (existing != null) {
      existing.inPot = chore.inPot;
      existing.repeating = chore.repeating;
    } else {
      _chores.add(chore);
    }
    await _save();
  }
}
