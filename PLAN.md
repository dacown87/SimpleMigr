# SimpleMigr – Plan

Einfaches Migräne-Tagebuch für Android, nachgebaut nach der Papiertabelle
(Zeilen = Symptome, Spalten = Tage eines Monats).

## Rahmen

- **Plattform:** nur Android
- **Technik:** Flutter + Drift (SQLite), alle Daten lokal auf dem Gerät
- **Nutzer:** eine Person, kein Konto, kein Internet
- **Leitlinie:** Die Erfassung muss **während einer Attacke** in wenigen Taps gehen.
  Alles, was nicht sofort nötig ist, kann später nachgetragen werden.

## Fachliche Regeln

| Begriff | Bedeutung |
|---|---|
| Migräne | Migränetag ja/nein (gelb auf Papier) |
| Schmerzen | Stärke 0–3, nur der Schmerz (0 = keine, 3 = stärkste) |
| Neue Attacke (`/`) | An diesem Tag endet eine Attacke und eine neue beginnt |
| Periode | ja/nein (rot auf Papier) |
| Übelkeit | ja/nein |
| Aura | ja/nein, eigener Schalter |
| Aura-Symptome | eigener, erweiterbarer Bereich: Sicht, Sprache, später z. B. Kribbeln, Taubheit, Schwindel |
| Auslöser | Auswahl aus einer erweiterbaren Liste plus freie Notiz |

**Attacken zählen:** Zusammenhängende Migränetage bilden eine Attacke.
Ist an einem Tag „neue Attacke“ gesetzt, beginnt dort eine neue.
Beispiel 2.–6.9. mit `/` am 4.9. ergibt zwei Attacken.

## Datenmodell (Drift)

```
symptoms        id, name, kind (flag | scale0to3), group (general | aura),
                color, sort_order, is_system, archived
                vorbelegt: Migräne (gelb, System), Schmerzen (0–3, System),
                Periode (rot), Übelkeit, Aura;
                Aura-Gruppe: Sicht, Sprache

day_values      date, symptom_id, value            PK(date, symptom_id)
day_meta        date PK, new_attack (bool), note (text)
triggers        id, name, sort_order, archived
                vorbelegt: Stress, Schlafmangel, Wetter, Alkohol,
                Mahlzeit ausgelassen, Bildschirm
day_triggers    date, trigger_id                   PK(date, trigger_id)
```

- Datum als `TEXT` im Format `YYYY-MM-DD`
- Tage ohne Eintrag werden nicht gespeichert
- Symptome und Auslöser werden nur archiviert, nie gelöscht, damit alte Einträge vollständig bleiben
- Android Auto-Backup ist aktiv (Sicherung der Datenbank in Google Drive)

## Bedienung

**„Heute“-Bildschirm (Start der App)**
- Großer Schalter `MIGRÄNE`
- Schmerz als vier große Felder `0 · 1 · 2 · 3`
- Schalter `Aura`; wenn an, klappen die Aura-Symptome auf
- „Neue Attacke“ ist nur sichtbar, wenn Migräne an ist
- Kein Speichern-Button: jeder Tap wird sofort gespeichert
- Eingeklappt „Mehr“: Periode, Übelkeit, eigene Symptome, Auslöser, Notiz

**Monat (zweiter Tab)**
- Raster wie auf Papier: Symptomnamen fest links, Tage horizontal scrollbar
- Farben wie auf Papier: gelb für Migräne, rot für Periode; Schmerz als Zahl, sonst X; `/` für neue Attacke
- Ein Tag antippen öffnet dieselbe Eingabe wie „Heute“ für diesen Tag

**Design:** dunkel, kontrastarm, große Schrift, weil Licht während einer Attacke oft unangenehm ist

## Phasen

### Phase 0 – Setup ✅
- [x] JDK 17, Flutter 3.47.8, Android SDK (Platform 36, Build-Tools 37)
- [x] Emulator `Pixel_API36` (Pixel 7, Android 16), läuft mit KVM
- [x] Flutter-Projekt `de.simplemigr.simplemigr` angelegt, Demo-App auf dem Emulator getestet
- [ ] Erster Git-Commit

### Phase 1 – Datenbasis
- [ ] Drift-Schema, Vorbelegung beim ersten Start
- [ ] Repository: Tag laden/speichern/löschen, Monat laden, Symptome und Auslöser verwalten
- [ ] Logik zum Zählen der Attacken
- [ ] Unit-Tests (In-Memory-Datenbank)

### Phase 2 – Kern-UI
- [ ] Dunkles Theme, Navigation „Heute“ / „Monat“ / „Einstellungen“
- [ ] „Heute“-Bildschirm mit sofortigem Speichern
- [ ] Monatsraster mit Monatsnavigation
- [ ] Tag aus dem Raster bearbeiten
- [ ] Einstellungen: Symptome (inkl. Aura-Symptome) und Auslöser hinzufügen, umbenennen, einfärben, sortieren, archivieren
- [ ] Papierdaten August/September 2026 als Testdaten, Abgleich mit dem Foto

### Phase 3 – Erinnerung
- [ ] Tägliche Notification, Uhrzeit einstellbar, an/aus
- [ ] Antippen öffnet „Heute“
- [ ] Berechtigung für Benachrichtigungen (ab Android 13) abfragen

### Phase 4 – Home-Screen-Widget
- [ ] Zeigt den heutigen Status (Migräne, Schmerz)
- [ ] Ein Tap auf „Migräne heute“ speichert direkt, ohne die App zu öffnen
- [ ] Button „Eintragen“ öffnet „Heute“
- [ ] Widget aktualisiert sich, sobald in der App gespeichert wird (`home_widget`)

### Phase 5 – PDF-Export
- [ ] Zeitraum wählen (ein oder mehrere Monate)
- [ ] A4 quer, Tabelle wie die Papiervorlage, Legende, Auslöser je Tag
- [ ] Teilen über den Android-Teilen-Dialog (Mail, Messenger, Drucken)

### Phase 6 – Fertigstellen
- [ ] App-Icon und Name
- [ ] Release-APK bauen und aufs Handy installieren

## TODO (nach v1)

- Statistik (Migränetage, Attacken, Schmerz-Durchschnitt, Zusammenhang mit der Periode)
- CSV-Export
- Backup/Restore als Datei
- Medikamente erfassen
- Aura-Symptome mit Details (z. B. Dauer)

## Entwicklung

```bash
emulator -avd Pixel_API36 &      # Emulator starten
flutter run                      # im Projektordner ausführen
flutter test                     # Tests
```
