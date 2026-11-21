# Putzwürfel (putzwuerfel)

Lifehack „Chores würfeln“: Aufgaben in den Topf (Putzeimer) werfen, „Jetzt würfeln!“, die gezogene Aufgabe erledigen.

- Die gezogene Aufgabe bleibt dran, bis sie **erledigt** ist – kein „Nochmal würfeln“, keine Ausreden (auch nach App-Neustart).
- **Einmalige Aufgaben** (Standard, z. B. „Glühbirne einsetzen“) werden nach „Erledigt“ gelöscht. Während sie dran sind („Zur Bibliothek hinzufügen“) oder direkt danach („+ Bibliothek“ in der Meldung) lassen sie sich in die Bibliothek übernehmen – ab dann sind sie wiederkehrend.
- **Wiederkehrende Aufgaben** (z. B. „Spülmaschine ausräumen“) wandern nach „Erledigt“ zurück in die **Bibliothek** und können mit einem Tipp (oder „Alle in den Topf“) wieder in den Topf.
- Beim ersten Öffnen liegen ein paar typische Hausarbeiten (Bad putzen, Staubsaugen, Müll rausbringen …) als Vorschläge in der Bibliothek – noch nicht im Topf und per langem Tippen löschbar.
- Gewürfelt wird gleichverteilt aus allen Aufgaben im Topf. Daten bleiben lokal (shared_preferences).
- Design: Grün/Creme mit Pop-Elementen, Schriften Archivo Black + Nunito (OFL, gebündelt). Store-Grafiken: `store/`.

## Build
```sh
flutter test
flutter build apk --release   # signiert mit android/key.properties (gitignored), sonst Debug-Key
xiaomi install build/app/outputs/flutter-apk/app-release.apk
```
applicationId: `io.github.leostumpf.putzwuerfel`

## Lizenz
GNU Affero General Public License v3.0 – siehe [LICENSE](LICENSE). Die gebündelten Schriften stehen unter der SIL Open Font License (`assets/fonts/OFL-*.txt`).
