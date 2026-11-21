# Aufgabenwürfel (choredice)

Lifehack „Chores würfeln“: Aufgaben aufschreiben, würfeln, die gezogene Aufgabe als Nächstes erledigen.

- **Einmalige Aufgaben** (Standard, z. B. „Glühbirne einsetzen“) werden nach „Erledigt“ gelöscht.
- **Wiederkehrende Aufgaben** (z. B. „Spülmaschine ausräumen“) wandern nach „Erledigt“ zurück in die **Bibliothek** und können mit einem Tipp (oder „Alle in den Topf“) wieder in den Topf.
- Gewürfelt wird gleichverteilt aus allen Aufgaben im Topf. Daten bleiben lokal (shared_preferences).

## Build
```sh
flutter test
flutter build apk --release   # signiert mit android/key.properties (gitignored), sonst Debug-Key
xiaomi install build/app/outputs/flutter-apk/app-release.apk
```
applicationId: `io.github.leostumpf.choredice`
