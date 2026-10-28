# SimpleMigr – Plan

Einfaches Migräne-Tagebuch für Android, nachgebaut nach der Papiertabelle
(Zeilen = Symptome, Spalten = Tage eines Monats).

## Rahmen

- **Plattform:** nur Android
- **Technik:** Flutter + Drift (SQLite), alle Daten lokal auf dem Gerät
- **Nutzer:** eine Person, kein Konto; Internet nur für den Wetterabruf (alles andere lokal, App läuft offline weiter)
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
symptoms        id, name, kind (flag | scale0to3), grp (general | aura | trigger),
                key (NULL oder fester Systemschlüssel, UNIQUE), sort_order, archived
                vorbelegt general: Migräne (key=migraine), Schmerzen (key=pain, 0–3),
                                   Periode (key=period), Aura (key=aura), Übelkeit
                vorbelegt aura:    Sicht, Sprache
                vorbelegt trigger: Stress, Schlafmangel, Wetter, Alkohol,
                                   Mahlzeit ausgelassen, Bildschirm

day_values      date, symptom_id, value            PK(date, symptom_id)
day_meta        date PK, new_attack (bool), note (text)
day_weather     date PK, Tageswetter (Luftdruck, Temperatur, …)
app_texts       key PK, value   (z. B. description = „Meine Migräne“)
```

- Auslöser sind Symptome der Gruppe `trigger` (Typ `flag`). Dadurch gibt es nur
  eine Liste, eine Speicherlogik und einen Einstellungsbildschirm.
- Systemsymptome werden über `key` erkannt, nie über den Namen (umbenennen bleibt möglich).
  Symptome mit `key` können nicht archiviert werden.
- Farben hängen fest am `key`: `migraine` gelb, `period` rot, alles andere neutral.
- Datum als `TEXT` im Format `YYYY-MM-DD`, immer lokale Zeit, erzeugt nur über eine Hilfsfunktion
- Gespeichert werden nur Werte ≠ 0/false. Wird ein Wert auf 0/false gesetzt, wird die Zeile gelöscht.
  `day_meta` wird gelöscht, wenn `new_attack` false und die Notiz leer ist.
- Wird Migräne für einen Tag ausgeschaltet, wird `new_attack` für diesen Tag mit zurückgesetzt.
- Symptome lassen sich ausblenden (Haken weg, Einträge bleiben) oder löschen (mit Rückfrage, Einträge dazu werden mitgelöscht). Systemsymptome (mit `key`) lassen sich weder ausblenden noch löschen
- Android Auto-Backup ist aktiv (Standard, Sicherung der Datenbank in Google Drive)

**Architektur (bewusst klein):**

```
UI (Heute, Monat, Einstellungen)
   │  StreamBuilder auf Drift-watch()-Streams, kein State-Management-Paket
   ▼
Repository (eine Klasse)         ── attacks.dart (reine Funktion, ohne DB)
   │
   ▼
Drift AppDatabase (3 Tabellen, schemaVersion 1, Vorbelegung in onCreate)
```

- Eine `DayEditor(date)`-Komponente für „Heute“ und für Tage aus dem Monatsraster
- Jeder Tap ruft direkt eine Repository-Methode auf; die UI aktualisiert sich über den Stream
- Repository wird einmal in `main()` erzeugt und per Konstruktor weitergereicht

**Attacken zählen (reine Funktion):**

```
Eingabe: sortierte Migränetage + Tage mit new_attack
Tag d ist Migränetag:
   Vortag kein Migränetag      → neue Attacke
   Vortag Migränetag, d hat /  → neue Attacke
   sonst                       → gehört zur laufenden Attacke
Monatszählung: Attacken, deren erster Tag im Monat liegt
(dafür wird zusätzlich der letzte Tag des Vormonats geladen)
```

## Bedienung

**„Heute“-Bildschirm (Start der App)**
- Großer Schalter `MIGRÄNE`
- Schmerz als vier große Felder `0 · 1 · 2 · 3`
- Schalter `Aura`; wenn an, klappen die Aura-Symptome auf
- „Neue Attacke“ ist nur sichtbar, wenn Migräne an ist
- Kein Speichern-Button: jeder Tap wird sofort gespeichert
- Eingeklappt „Mehr“: Periode, Übelkeit, eigene Symptome, Auslöser, Notiz
- Erneutes Tippen auf das gewählte Schmerzfeld setzt den Schmerz zurück
- „Heute“ berechnet das Datum neu, wenn die App wieder in den Vordergrund kommt (Tageswechsel)

**Monat (zweiter Tab)**
- Raster wie auf Papier: Symptomnamen fest links, Tage horizontal scrollbar
- Farben wie auf Papier: gelb für Migräne, rot für Periode; Schmerz als Zahl, sonst X; `/` für neue Attacke
- Ein Tag antippen öffnet dieselbe Eingabe wie „Heute“ für diesen Tag
- Unter dem Raster: „Migränetage: X · Attacken: Y“ für den Monat
- Auslöser erscheinen als eigene Zeilen im Raster (wie Symptome, mit X)

**Design:** zartes Rosé/Pastell (gedämpft, kein reines Weiß), große Schrift und große Felder, weil Licht während einer Attacke oft unangenehm ist

## Phasen

### Phase 0 – Setup ✅
- [x] JDK 17, Flutter 3.47.8, Android SDK (Platform 36, Build-Tools 37)
- [x] Emulator `Pixel_API36` (Pixel 7, Android 16), läuft mit KVM
- [x] Flutter-Projekt `de.simplemigr.simplemigr` angelegt, Demo-App auf dem Emulator getestet
- [x] Erster Git-Commit

### Phase 1 – Datenbasis ✅
- [x] Pakete: `drift`, `drift_flutter`, `path_provider`; dev: `drift_dev`, `build_runner`
- [x] Drift-Schema (3 Tabellen), Vorbelegung in `onCreate`
- [x] Datums-Hilfsfunktion (`DateTime` ↔ `YYYY-MM-DD`)
- [x] Repository: Tag beobachten/setzen, Monat beobachten, Symptome anlegen/umbenennen/archivieren
- [x] `attacks.dart`: Attacken zählen als reine Funktion
- [x] Unit-Tests (siehe Testplan unten, In-Memory-Datenbank `NativeDatabase.memory()`)

### Phase 2 – Kern-UI ✅
- [x] Dunkles Theme, Navigation „Heute“ / „Monat“ / „Einstellungen“
- [x] „Heute“-Bildschirm mit sofortigem Speichern
- [x] Monatsraster mit Monatsnavigation
- [x] Tag aus dem Raster bearbeiten
- [x] Einstellungen: eine Liste mit drei Abschnitten (Symptome, Aura, Auslöser): hinzufügen, umbenennen, archivieren
- [x] Papierdaten August/September 2026 als Testdaten, Abgleich mit dem Foto
  (Foto: `docs/papier-aug-sep-2026.png`, Fixture: `test/paper_fixture_test.dart`; Aug 9 Tage/3 Attacken, Sep 11 Tage/5 Attacken; Papier hat Einträge in der nicht existierenden Spalte „31“ des Septembers)

### Phase 3 – Erinnerung ✅
- [x] `flutter_local_notifications` + `timezone`, täglich, **inexakt** (`inexactAllowWhileIdle`, keine Exact-Alarm-Berechtigung nötig)
- [x] Uhrzeit einstellbar, an/aus (gespeichert in einer kleinen `settings`-Tabelle oder `shared_preferences`)
- [x] Antippen öffnet „Heute“
- [x] Berechtigung für Benachrichtigungen (ab Android 13) beim Einschalten abfragen; bei Ablehnung Schalter wieder aus + Hinweis
- [x] Nach Neustart des Handys neu planen (Boot-Receiver des Plugins im Manifest)

### Phase 4 – PDF-Export ✅
- [x] Pakete `pdf` + `printing` (`Printing.sharePdf` öffnet den Teilen-Dialog, kein weiteres Paket nötig)
- [x] Zeitraum wählen (ein oder mehrere Monate), eine Seite pro Monat
- [x] A4 quer, Tabelle wie die Papiervorlage inkl. Auslöser-Zeilen, Legende, Summenzeile
- [x] Teilen über den Android-Teilen-Dialog (Mail, Messenger, Drucken)

### Phase 5 – Fertigstellen (offen: Keystore sichern)
- [x] App-Icon und Name
- [x] Release-APK bauen (signiert mit dem Debug-Key, Template-Standard) und aufs Handy installieren
- [ ] `~/.android/debug.keystore` sichern: ohne denselben Key kein Update, nur Neuinstallation

### Phase 6 – Wetter ✅
- [x] Open-Meteo (gratis, kein Schlüssel, nicht-kommerziell, CC BY 4.0), Ort in den Einstellungen (Ortssuche), kein Gerätestandort
- [x] Tabelle `day_weather` (Schema 2 mit Migration): Luftdruck Mittel/Min/Max, Temperatur, Feuchte, Niederschlag, Wind
- [x] Abruf nur rund um Migräne: 3 Tage vor (der erste nur für die Druckänderung) bis 2 Tage nach jedem Lauf von Migränetagen, nur abgeschlossene Tage
- [x] Abgleich beim Start, beim Zurückkehren in die App, nach Änderungen und bei Ortswechsel; offline = still, später erneut
- [x] Anzeige: Wetterkarte im Tageseditor, Zeilen „Luftdruck“ und „Druck ±“ im Monatsraster (Änderung ≥ 5 hPa rosa) und im PDF

## Phase: Daten, Beschreibung, Einstellungen (1.0.6)

- [x] Sicherung als JSON (alles inklusive Wetter und Beschreibung) und Tabelle als CSV (`;`, UTF-8 mit BOM) speichern
- [x] Import erkennt Sicherung oder Tabelle am Inhalt; Vorschau vor dem Übernehmen, alles in einer Transaktion
- [x] Tabellen-Import: Spalte „Datum“ (ISO oder deutsch), Symptome per Systemschlüssel-Alias oder Name, `Aura: …`/`Auslöser: …` als Gruppe, unbekannte Spalten werden neue Symptome, leere Spalten ignoriert, `/` bei Migräne = neue Attacke
- [x] Import ersetzt für die Tage der Datei nur die enthaltenen Spalten; leere Notizen überschreiben nicht; andere Tage bleiben
- [x] Nach dem Import holt der Wetter-Abgleich das Wetter für die importierten Migränetage (ohne Ort: Hinweis)
- [x] „Meine Migräne“ (eigener Tab): Liste einzelner Punkte wie in einer To-do-App, gespeichert zeilenweise in `app_texts`, im PDF als Aufzählung auf der ersten Seite
- [x] Monatsraster: zugeklappte Abschnitte zeigen Kürzel der gewählten Einträge (ab vier: zwei Kürzel und „+n“)
- [x] Einstellungen in Tabs: Einträge (unterteilt per Segment: Basis, Symptome, Aura, Auslöser), Allgemein, Daten
- [x] Monatsraster: nur der Schalter (Aura, Medikamente) an, nichts gewählt → Haken
- [x] Medikamente mit Substanzen: eigene Gruppe `SymptomGroup.medication` (Einstellungen → Einträge → „Medis“), im Editor als Chips im Block „Medikamente“; eine Substanz wählen setzt „Medikamente genommen“. Triptan = Name enthält „triptan“. CSV-Spalte „Medikament: …“
- [x] Arzt-Zusammenfassung (Einstellungen → Daten), Zeitraum vorausgewählt: letzte 6 Monate bis heute. Rechenregeln in `lib/data/report.dart`:
  Migränetag = Migräne an; Attacke wie im Raster (Lücke oder `/`), gezählt im Monat ihres Starts; Aura-Tag = Aura an oder ein Aura-Symptom;
  Periodenbeginn = erster Periodentag nach 5 periodenfreien Tagen, Zykluslängen über 60 Tage gelten als Erfassungslücke;
  perimenstruell = Start Tag −2 bis +3 um einen Periodenbeginn, sonst Zyklustag; Muster = 4-Tage-Fenster mit ≥ 2 und ≥ der Hälfte der übrigen Attacken;
  Hinweis bei Triptan ≥ 10 bzw. sonstigen Mitteln ≥ 15 Einnahmetagen im Monat;
  Beschreibung per Stichwort gruppiert (Motorik/Sprache fett, Skalen-Zeilen unter die Tabelle); Fragen nur, wenn die Daten sie begründen (max. 6)
  Zeitraum beginnt frühestens mit dem ersten Tagebucheintrag (davor „nicht erfasst“, nicht 0).
  Balkendiagramm (Migränetage, Aura-Tage, Tage Schmerz stark je Monat) neben der Tabelle; passt das nicht auf eine Seite, auf eigener letzter Seite; bei nur einem Monat keins

## Phase: In-App-Update reparieren (1.0.7, offen)

Update 1.0.5 → 1.0.6: neue Version erkannt, APK geladen, Installation scheiterte.
Bereits geprüft und in Ordnung: beide Release-APKs mit demselben Schlüssel signiert
(SHA-256 `3aea8f63…`, auch lokal `~/.simplemigr/release.jks`), versionCode 6 → 7,
1.0.5 hat `REQUEST_INSTALL_PACKAGES` und den FileProvider von open_filex, APK liegt im Cache (freigegeben).
`installUpdate` verschluckt den Fehler („Update fehlgeschlagen“), daher erst per adb geklärt.

**1. Ursache klären (mit Handy)**
- [x] Pixel 9a (Android 17), 1.0.5 per Paket-Installer aus der GitHub-APK, Signatur = Release-Schlüssel → kein Signaturkonflikt
- [x] „Unbekannte Apps installieren“ war für SimpleMigr nicht erlaubt (`appops REQUEST_INSTALL_PACKAGES` = default).
  Ablauf laut logcat: open_filex → Installer → `MANAGE_UNKNOWN_APP_SOURCES` → erlauben → Installer startet neu → Installation ok.
  Beim ersten Versuch ging dieser Umweg verloren; die App erklärt ihn nicht. Zweiter Versuch (28.10.) hat 1.0.6 installiert.
- [ ] Samsung (Handy der Frau): Installation brachte einen Fehler. Genauen Text/Screenshot besorgen, dann per adb + logcat nachstellen.
  Verdacht: Samsung „Automatische Sperre“ (Auto Blocker, One UI 6+) blockiert Apps aus nicht autorisierten Quellen, oder Play Protect

**2. Code (`lib/update/updater.dart`, `lib/ui/version_tile.dart`, `MainActivity.kt`)**
- [x] Fehlergrund anzeigen: `installUpdate` zeigt die Meldung (HTTP-Status, „Download unvollständig“, open_filex-Ergebnis) statt nur „Update fehlgeschlagen“ – als Fenster mit markierbarem Text
- [x] **Hauptursache:** Vor dem Öffnen des Installers `canRequestPackageInstalls()` prüfen (kleiner MethodChannel in `MainActivity`); falls nein: Dialog mit Erklärung („Einmalig erlauben, dann zurück“), dann `ACTION_MANAGE_UNKNOWN_APP_SOURCES` für unser Paket öffnen und nach der Rückkehr (`onResume`/ActivityResult) den Installer selbst erneut starten
- [ ] Hinweis-Text, falls die Installation auf Samsung durch die Automatische Sperre blockiert wird (je nach Befund vom Samsung)
- [x] Download gegen die Größe aus der Release-Abfrage (`assets[].size`) prüfen, nicht nur gegen `contentLength` (fehlt bei manchen Antworten)
- [x] Fortschritt beim Laden (~67 MB) in der SnackBar (Prozent), damit kein Eindruck „hängt“ entsteht
- [x] Alte `SimpleMigr-*.apk` im Cache vor dem Download löschen

**3. Tests**
- [x] `test/updater_test.dart`: `parseRelease` übernimmt `size`
- [x] Widget-Tests: Fehlerfenster mit Grund; ohne Erlaubnis erst Erklärung, dann Einstellung; abgelehnt → Fehlerfenster, kein Download

**4. Prüfen vor dem Release**
- [ ] Emulator: GitHub-APK 1.0.6 installieren, Release 1.0.7 veröffentlichen, Update aus der App durchspielen (mit und ohne Erlaubnis für unbekannte Apps)
- [ ] Hinweis: Die Verbesserungen greifen erst ab dem Update *von* 1.0.7; 1.0.6 → 1.0.7 läuft noch mit dem alten Code

## TODO (nach v1)

- Home-Screen-Widget (`home_widget`): Status anzeigen, „Eintragen“ öffnet „Heute“;
  direktes Speichern ohne App-Start erst danach (braucht Hintergrund-Isolate, der parallel zur App in die DB schreibt)
- Farben und Reihenfolge eigener Symptome einstellbar
- Statistik in der App (die Arzt-Zusammenfassung deckt das als PDF ab)
- Aura-Symptome mit Details (z. B. Dauer)

## Entwicklung

```bash
emulator -avd Pixel_API36 &      # Emulator starten
flutter run                      # im Projektordner ausführen
flutter test                     # Tests
```

## Testplan (Pflicht für Phase 1 und 2)

```
CODE-PFADE                                           NUTZERABLÄUFE
[+] lib/data/dates.dart                              [+] „Heute“ während Attacke
  ├── [GAP] toKey/fromKey, Monatsgrenzen, Schaltjahr   ├── [GAP] Migräne an → sofort gespeichert, Neustart → noch da
  └── [GAP] Tage eines Monats (28/29/30/31)            ├── [GAP] Schmerz 2 → 2 erneut tippen → zurückgesetzt
[+] lib/data/attacks.dart (reine Funktion)           ├── [GAP] Aura an → Aura-Symptome sichtbar; aus → versteckt
  ├── [GAP] leer → 0                                   └── [GAP] „Neue Attacke“ nur sichtbar, wenn Migräne an
  ├── [GAP] 2.–6.9. ohne / → 1                       [+] Monat
  ├── [GAP] 2.–6.9. mit / am 4.9. → 2 (Beispiel)       ├── [GAP] Raster zeigt gelb/rot/Zahl/X//
  ├── [GAP] / am ersten Tag einer Folge → 1, nicht 2   ├── [GAP] Tag antippen → DayEditor für diesen Tag
  ├── [GAP] Lücke 2.,4. → 2                            └── [GAP] Papierdaten Aug/Sep 2026: Summen = Foto
  └── [GAP] Attacke 30.8.–2.9.: zählt im Aug, nicht Sep [+] Einstellungen
[+] lib/data/repository.dart (In-Memory-DB)            ├── [GAP] Auslöser anlegen → erscheint in „Mehr“
  ├── [GAP] Vorbelegung: alle Symptome + keys da       └── [GAP] Systemsymptom: kein Archivieren möglich
  ├── [GAP] Wert setzen → Zeile; 0/false → gelöscht
  ├── [GAP] Migräne aus → new_attack gelöscht
  ├── [GAP] Notiz leer + kein / → day_meta gelöscht
  ├── [GAP] Archiviertes Symptom: alte Werte im Monat sichtbar, nicht mehr in „Heute“
  ├── [GAP] Umbenennen ändert key nicht
  └── [GAP] Monat beobachten liefert Update nach Schreiben (Stream)

COVERAGE: 0/26 (Greenfield, alles geplant) | Unit: 19 | Widget-Tests: 7
```

- Unit-Tests: `test/dates_test.dart`, `test/attacks_test.dart`, `test/repository_test.dart` (mit `NativeDatabase.memory()`)
- Widget-Tests: `test/day_editor_test.dart`, `test/month_grid_test.dart` mit In-Memory-Repository
- Die Papierdaten Aug/Sep 2026 werden als Test-Fixture abgelegt und im Test gegen die Summen vom Foto geprüft
- Erinnerung und PDF: manuell auf dem Emulator prüfen (Notification kommt, PDF öffnet Teilen-Dialog), plus ein Unit-Test, dass der PDF-Builder für einen leeren und einen vollen Monat ohne Fehler ein Dokument erzeugt

## Eng Review (2026-10-25)

Alle Entscheidungen hat der Reviewer getroffen (Vorgabe Patrick: „du triffst alle Entscheidungen, es soll simpel sein“).
Die angenommenen Änderungen sind oben im Plan bereits eingearbeitet.

### Entscheidungen

| ID | Befund | Entscheidung |
|---|---|---|
| S1 | [P1] (9/10) Phase 4 Widget mit Direkt-Speichern braucht Hintergrund-Isolate, der parallel zur App in dieselbe SQLite-DB schreibt, plus Sync zurück ins Widget. Komplexester Teil, wenig Nutzen (App öffnen = 1 Tap mehr). | Widget komplett nach v1 verschoben |
| S2 | [P2] (8/10) `triggers`/`day_triggers` duplizieren `symptoms`/`day_values` (gleiche Struktur: Liste, archivieren, ja/nein je Tag). | Auslöser = Symptome mit `grp=trigger`; 2 Tabellen weniger, ein Einstellungsbildschirm |
| S3 | [P3] (7/10) Einfärben und Sortieren eigener Symptome kosten UI ohne Kernnutzen. | Gestrichen, als TODO notiert |
| A1 | [P1] (8/10) Attackenzählung und Farben müssen „Migräne“ finden; über Namen bricht das beim Umbenennen, `is_system` sagt nicht *welches*. | Spalte `key` (migraine/pain/period/aura), Farben fest am Key, `color`/`is_system` entfallen |
| A2 | [P2] (8/10) Kein State-Management festgelegt; Gefahr, Riverpod/Bloc einzuführen. | Drift `watch()` + `StreamBuilder`, Repository per Konstruktor |
| A3 | [P2] (8/10) Attacken über Monatsgrenze und `/` am ersten Tag einer Folge nicht definiert. | Regel festgelegt (siehe „Attacken zählen“), zählt im Startmonat |
| A4 | [P2] (7/10) Release-APK mit Template-Debug-Key; geht der Key verloren, ist kein Update mehr möglich (nur Neuinstallation). | Debug-Key behalten, aber sichern (simpelste Lösung für eine Person) |
| C1 | [P2] (8/10) „Tage ohne Eintrag werden nicht gespeichert“, aber unklar, was beim Zurücksetzen passiert. | 0/false löscht die Zeile; leeres `day_meta` wird gelöscht |
| C2 | [P2] (8/10) „Neue Attacke“ ist nur bei Migräne sichtbar, bleibt aber gespeichert, wenn Migräne danach ausgeschaltet wird → falsche Zählung, unsichtbar. | Migräne aus setzt `new_attack` zurück |
| C3 | [P3] (7/10) App bleibt über Mitternacht offen → „Heute“ zeigt den Vortag und speichert dorthin. | Datum beim Zurückkehren in den Vordergrund neu berechnen |
| T1 | [P1] (9/10) Plan nennt nur „Unit-Tests“. | Testplan oben ergänzt (26 Fälle) |

Performance: keine Befunde. Ein Monat sind ~31 × 20 Zellen aus einer Abfrage, Streams nur für den sichtbaren Monat.

### Nicht im Umfang
- Home-Screen-Widget: nach v1 (S1)
- Farben/Sortierung eigener Symptome: nach v1 (S3)
- Exakte Erinnerungszeit (Exact-Alarm-Berechtigung): inexakt reicht für eine Tageserinnerung
- Schema-Migrationen: v1 bleibt `schemaVersion 1`; erst bei der ersten Änderung `drift_dev schema dump` einführen
- Statistik, CSV, Backup-Datei, Medikamente: wie bisher in TODO

### Was es schon gibt
- Flutter-Projekt-Gerüst (`lib/main.dart` ist noch die Demo-App), Debug-Signing im Template (`android/app/build.gradle.kts:36`)
- `printing` bringt Teilen/Drucken mit, kein `share_plus` nötig
- `drift_flutter` öffnet die DB inkl. Pfad, kein eigener Pfad-Code nötig
- Android Auto-Backup ist ohne Konfiguration aktiv (`allowBackup` Standard true)

### Fehlerfälle
| Pfad | Realistischer Fehler | Abgedeckt |
|---|---|---|
| Tap speichern | Schreibfehler (Speicher voll) | Drift wirft; global abfangen und SnackBar „Nicht gespeichert“. Kein Test, aber sichtbar |
| Attacken zählen | `/` bleibt nach Migräne-aus stehen | C2 + Repository-Test |
| Tageswechsel | Eintrag landet auf Vortag | C3, manuell prüfen |
| Erinnerung | Berechtigung abgelehnt / nach Neustart weg | Schalter zurück + Hinweis; Boot-Receiver; manuell prüfen |
| Update der App | anderer Signierschlüssel | A4 Key sichern |

Kritische Lücken (kein Test, keine Behandlung, still): keine.

### Parallelisierung
Sequenzielle Umsetzung, keine sinnvolle Parallelisierung (ein Modul, eine Person, Phase 2 hängt an Phase 1).

## Implementation Tasks
Aus den Befunden oben abgeleitet. Abhaken beim Umsetzen.

- [x] **T1 (P1, human: ~1 Tag / CC: ~20min)** — data — Drift-Schema mit `key`, Auslöser als Symptome, Vorbelegung
  - Befund: S2, A1
  - Dateien: `lib/data/database.dart`, `lib/data/repository.dart`
  - Prüfen: `flutter test test/repository_test.dart`
- [x] **T2 (P1, human: ~2h / CC: ~10min)** — data — Attackenzählung als reine Funktion mit Monatsregel
  - Befund: A3
  - Dateien: `lib/data/attacks.dart`, `test/attacks_test.dart`
  - Prüfen: `flutter test test/attacks_test.dart`
- [x] **T3 (P1, human: ~2h / CC: ~10min)** — data — Speicherregeln 0/false löschen, `/` mit Migräne zurücksetzen
  - Befund: C1, C2
  - Dateien: `lib/data/repository.dart`, `test/repository_test.dart`
  - Prüfen: `flutter test`
- [x] **T4 (P1, human: ~1 Tag / CC: ~30min)** — tests — Testplan umsetzen inkl. Papier-Fixture Aug/Sep 2026
  - Befund: T1
  - Dateien: `test/`
  - Prüfen: `flutter test`
- [x] **T5 (P2, human: ~1h / CC: ~5min)** — ui — „Heute“ rechnet Datum bei App-Resume neu
  - Befund: C3
  - Dateien: `lib/ui/today_screen.dart`
  - Prüfen: Emulator-Uhr über Mitternacht stellen
- [ ] **T6 (P2, human: ~15min / CC: ~2min)** — release — `~/.android/debug.keystore` sichern
  - Befund: A4
  - Prüfen: Kopie liegt außerhalb des Rechners

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Outside Review | codex via `/plan-eng-review` | Independent 2nd opinion | 1 | unavailable | Codex-Token abgelaufen (`codex login`), Subagent-Fallback nicht verfügbar |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | ISSUES OPEN (PLAN) | 11 issues, 0 critical gaps; alle entschieden und eingearbeitet |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **OUTSIDE COVERAGE:** codex, plan-review, unavailable (Auth-Fehler), keine Befunde, keine Zweitmeinung.
- **VERDICT:** Keine Review CLEAR; alle 11 Befunde sind entschieden und als Tasks T1–T6 im Plan. Bereit zur Umsetzung ab Phase 1. eng review required

NO UNRESOLVED DECISIONS
