 IT49 Auto-Update System fuer GitHub

Dieses Paket ist ein Grundgeruest fuer ein Windows-Tool mit Auto-Update ueber GitHub.

## Lokale Struktur

```text
IT49_helfer/
├── IT49.exe
├── app.bat
├── updater.ps1
```

## GitHub-Repo-Struktur

```text
it49_helfer/
├── version.json
└── README.md
```

Die EXE selbst laedst du als **GitHub Release Asset** hoch:
- Release Tag z. B. `v1.0`
- Asset Name genau: `IT49+ Helfer.exe`

Dann lautet der Download-Link stabil:

```text
https://github.com/Septiuss/it49_helfer/releases/latest/download/IT49.exe
```

## Was jetzt passiert

1. Beim Start wird `version.json` von GitHub geladen.
2. Wenn online eine neuere Version existiert, sieht der Nutzer vor dem Update:
   - neue Versionsnummer
   - Titel
   - Datum
   - Changelog
3. Danach wird gefragt:
   - `Update jetzt herunterladen und installieren? (J/N)`
4. Nur bei Zustimmung wird die neue EXE geladen und ersetzt.

## Aufbau von version.json

```json
{
  "app_name": "IT49+ Helfer",
  "channel": "stable",
  "version": "1.0",
  "asset_name": "IT49+ Helfer.exe",
  "download_url": "https://github.com/DEIN_GITHUB_NAME/it49/releases/latest/download/IT49.exe",
  "release_title": "IT49+ Helfer 1.0",
  "published_at": "2026-04-21",
  "changelog": [
    "Neuer Punkt 1",
    "Neuer Punkt 2",
    "Neuer Punkt 3"
  ]
}
```

## Bei jedem neuen Release

1. Neue `IT49+ Helfer.exe` bauen
2. Neues GitHub Release erstellen
3. `IT49+ Helfer.exe` als Asset hochladen
4. `version.json` anpassen:
   - `version`
   - `release_title`
   - `published_at`
   - `changelog`
5. `version.json` committen und pushen

## Wichtige Anpassungen

In `app.bat`:
- `REPO_OWNER=Septiuss`
- `REPO_NAME=it49`
- `CURRENT_VERSION=1.0`

In `version.json`:
- `version`
- `download_url`
- `release_title`
- `published_at`
- `changelog`
