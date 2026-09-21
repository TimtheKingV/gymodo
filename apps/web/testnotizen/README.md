# Testnotizen — Eingang für Claude Code (Trainerportal)

Hier landen Testsitzungen aus dem **Dev-Server** des Portals. Jede Sitzung ist
ein Ordner `yyyy-MM-dd-HHmm` mit `sitzung.md`, `sitzung.json` und Screenshots.
Das Format beschreibt `docs/superpowers/specs/2026-09-14-testnotiz-format.md`
— dasselbe, das die iOS-App schreibt.

**Vom Browser hierher:** `pnpm --filter @fitretro/web dev`, im Portal den
Testnotiz-Knopf am rechten Rand klicken, beim ersten Mal den Tab freigeben
(„Diesen Tab teilen“), dann Ausschnitt ziehen oder Element anklicken, Notiz
tippen, sichern. Der Dev-Server schreibt den Ordner direkt hierher — es gibt
nichts zu übertragen.

**Der Auftrag an Claude Code**, mit dem Ordnernamen der Sitzung (im Blatt
„Sitzung“ steht er zum Kopieren):

```
Lies apps/web/testnotizen/2026-09-21-1412/sitzung.md und arbeite die Einträge ab.
```

Alles in diesem Ordner außer dieser Datei ist gitignoriert: Die Screenshots
zeigen Daten echter Studios und Mitglieder und gehören nicht ins Repository.
