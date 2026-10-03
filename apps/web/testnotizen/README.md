# Testnotizen — Eingang für Claude Code (Trainerportal)

Hier werden die **Zips** entpackt, die das Testnotiz-Modul im Portal ausgibt.
Jede Sitzung ist ein Ordner `yyyy-MM-dd-HHmm` mit `sitzung.md`, `sitzung.json`
und den Bildern. Das Format beschreibt
`docs/superpowers/specs/2026-09-14-testnotiz-format.md` — dasselbe, das die
iOS-App schreibt.

**Am Rechner:** `pnpm --filter @fitretro/web dev`, im Portal den Testnotiz-Knopf
am rechten Rand klicken, beim ersten Mal den Tab freigeben („Diesen Tab
teilen“), dann Ausschnitt ziehen oder Element anklicken, Notiz tippen, sichern.
Am Ende **Sitzung → Sitzung teilen**: die Zip landet im Download-Ordner.

**Am Handy** (und für einen Kollegen) geht dasselbe auf einer
Vercel-Vorschau: Screenshot mit der Tastenkombination des Geräts machen,
Testnotiz-Knopf tippen, **Notiz** wählen, **Bild anhängen**, Notiz tippen,
sichern. Am Ende **Sitzung teilen** — das Share-Sheet schickt die Zip per
AirDrop, Mail oder Messenger.

**Hier ankommen lassen:** die Zip in dieses Verzeichnis entpacken, dann in
Claude Code (den Satz zeigt das Sitzungsblatt zum Kopieren):

```
Lies apps/web/testnotizen/2026-09-21-1412/sitzung.md und arbeite die Einträge ab.
```

Alles in diesem Ordner außer dieser Datei ist gitignoriert: Die Screenshots
zeigen Daten echter Studios und Mitglieder und gehören nicht ins Repository.
