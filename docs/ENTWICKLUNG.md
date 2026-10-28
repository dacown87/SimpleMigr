# Entwicklung und Release

Kurzer Überblick für alle, die am Code arbeiten. Fachliche Regeln und Entwurf stehen in [PLAN.md](../PLAN.md).

## Aufbau

| Ordner | Inhalt |
|---|---|
| `lib/data/` | Drift-Datenbank (`database.dart`), Zugriff und Monatsdaten (`repository.dart`), Attackenzählung (`attacks.dart`), Auswertung für die Arzt-Zusammenfassung (`report.dart`) |
| `lib/ui/` | Tages-Editor (`day_editor.dart`), Monatsraster (`month_screen.dart`), Einstellungen, Theme |
| `lib/weather/` | Wetterabruf (Open-Meteo, Orte auch per PLZ über zippopotam.us) |
| `lib/update/` | Update-Prüfung beim Start (`updater.dart`) |
| `lib/pdf/` | PDF-Export im Look der Papiertabelle, Arzt-Zusammenfassung (`report_pdf.dart`) |
| `test/` | Unit- und Widget-Tests, dazu ein Test mit den echten Daten Aug/Sep 2026 |

Der Tages-Editor und das Monatsraster haben denselben Aufbau: Migräne, Schmerzen und Periode sind immer sichtbar, Symptome, Aura, Medikamente, Auslöser (und im Raster das Wetter) sind aufklappbar.

## Datenbank

Systemsymptome haben einen festen Schlüssel (`SymptomKey`), Logik und Farben hängen daran, nie am Namen. `SymptomGroup` wird als Index gespeichert: neue Gruppen nur hinten anhängen. Änderungen am Schema brauchen eine neue `schemaVersion` und einen Schritt in `onUpgrade`.

| Version | Änderung |
|---|---|
| 1 | Symptome, Tageswerte, Tagesnotiz |
| 2 | Tageswetter |
| 3 | „Medikamente genommen“ und „Hat geholfen“ |

Nach Änderungen an Tabellen den generierten Code neu erzeugen:

```
dart run build_runner build --delete-conflicting-outputs
```

## Prüfen

```
flutter analyze
flutter test
```

## Release

1. Version in `pubspec.yaml` erhöhen (`version: 1.0.4+5`, Build-Nummer immer hochzählen).
2. Committen und pushen.
3. Tag setzen und pushen:
   ```
   git tag -a v1.0.4 -m "SimpleMigr 1.0.4"
   git push origin main v1.0.4
   ```
4. Der Workflow [release.yml](../.github/workflows/release.yml) baut die signierte APK und veröffentlicht das GitHub-Release.
   Dabei setzt er `--dart-define=BUILD_DATE` auf das Datum des Release-Commits; die App zeigt es unter Einstellungen → Allgemein neben der Version. Lokale Builds zeigen dort „Testversion“.

### Signierung

Lokal liest Gradle `android/key.properties` (nicht im Repo, steht in `.gitignore`). Fehlt die Datei, wird mit dem Debug-Schlüssel signiert.

```
storePassword=…
keyPassword=…
keyAlias=simplemigr
storeFile=/Pfad/zur/release.jks
```

In GitHub braucht der Workflow zwei Secrets:

- `KEYSTORE_BASE64`: der Keystore, kodiert mit `base64 -w0 release.jks`
- `KEY_PASSWORD`: Passwort für Keystore und Schlüssel (beide gleich)

Bricht der Build mit „Failed to read key … Tag number over 30 is not supported“ ab, ist `KEYSTORE_BASE64` unvollständig oder falsch kodiert. Secret neu setzen:

```
base64 -w0 release.jks | gh secret set KEYSTORE_BASE64
```

Updates lassen sich nur mit einer APK einspielen, die denselben Schlüssel nutzt. Den Keystore deshalb sichern.

## Update aus GitHub

`GithubUpdater` fragt beim Start `releases/latest` ab und vergleicht den Tag (`v1.0.5`) mit der installierten Version. Ist er höher und hängt eine `.apk` am Release, zeigt `HomeShell` ein Banner. „Installieren“ lädt die APK in den temporären Ordner und öffnet sie über `open_filex` im Android-Installer. Dafür steht `REQUEST_INSTALL_PACKAGES` im Manifest.

- Die Version kommt aus `pubspec.yaml`, der Tag muss also dazu passen und höher sein als die installierte Version.
- Das Release muss eine APK als Datei enthalten (macht der Workflow).
- Die neue APK muss mit demselben Schlüssel signiert sein, sonst lehnt Android das Update ab.
- Fehler (offline, Rate-Limit) bleiben still, es erscheint dann kein Banner.
- In Tests ist der Updater austauschbar (`SimpleMigrApp(updater: …)`), ohne Updater passiert nichts.
