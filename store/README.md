# Play-Store-Grafiken

| Datei | Zweck |
|---|---|
| `icon.svg` | Quelle des App-Icons (Putzeimer-Lostopf, 512×512) |
| `icon-512.png` | Play-Store-App-Icon 512×512 |
| `banner.html` | Quelle der Feature-Grafik (nutzt `../assets/fonts`) |
| `feature-graphic.png` | Play-Store-Feature-Grafik 1024×500 |

Neu rendern:

```sh
inkscape store/icon.svg -o store/icon-512.png -w 512 -h 512
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  inkscape store/icon.svg -o android/app/src/main/res/mipmap-${d%%:*}/ic_launcher.png -w ${d##*:} -h ${d##*:}
done
google-chrome --headless=new --hide-scrollbars --window-size=1024,500 \
  --screenshot=$PWD/store/feature-graphic.png file://$PWD/store/banner.html
```

Das Adaptive-Icon (Android 8+) ist `android/app/src/main/res/drawable/ic_launcher_foreground.xml`,
von Hand aus `icon.svg` übertragen – bei Änderungen am Icon dort mitziehen.
Schriften: Archivo Black und Nunito, SIL Open Font License (`assets/fonts/OFL-*.txt`).
