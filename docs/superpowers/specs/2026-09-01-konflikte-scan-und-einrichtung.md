# Konflikte zwischen „Beitritt durch Scannen" und „Einrichtung am Gerät"

**Stand:** 1. September 2026
**Status:** **Entschieden und abgearbeitet.** Alle Befunde sind in Specs, Plan und Entwürfen nachgezogen.
**Betrifft:** `2026-09-01-scan-beitritt-design.md` (Runde A) und `2026-09-01-einrichtung-am-geraet-design.md` (Runde B)

---

## Warum dieses Dokument existiert

Beide Runden entstanden am selben Tag, teils parallel. Runde B erklärt im Kopf, sie ändere Runde A in §3 und §6, und Runde A ist darauf nachgezogen. **Dieses Dokument hielt fest, was dabei durchgerutscht ist** — und hält jetzt fest, wie es entschieden wurde.

**Nichts davon hat etwas gebrochen, das bereits gebaut war.** Alle Befunde lagen in Specs und im noch nicht ausgeführten Datenbankplan. Die 34 Member-Artboards und die 36 Portal-Artboards waren in sich stimmig, beide `canvas.json` vollständig, kein Artboard doppelt oder verwaist.

---

## Die vier Entscheidungen

1. **Ein Aushangschild ist ab Lieferung gültig.** Der Betreiber legt beim Zuordnen einer Charge die Zeilen an — Gerätetags als `unassigned`, Aushangschilder als `active`. Das Portal aktiviert nie.
2. **Die Tags-Seite listet aktive Aushangschilder einzeln, benannt über die aufgedruckte Nummer**, je mit *Sperren*.
3. **`KeinStudio` im Portal gehört dem Trainer.** Das Studio-Code-Feld ist entfallen; Personal kommt über *Leute → Mitarbeiter* herein.
4. **Der Member-Beispielbestand zieht auf den Portal-Bestand nach.**

---

## Die drei Befunde und was aus ihnen wurde

### 1. Ein geliefertes Aushangschild konnte nie aktiv werden

Runde A kannte genau einen Weg, einen Aushang zu aktivieren: `createTag(kind: 'studio')`, das die Zeile sofort `active` anlegt. **Runde B streicht `createTag` ersatzlos** (§6) und sagt: „Im Portal gibt es dafür keinen Bildschirm" (§1). Damit blieb kein Weg übrig, während `join_studio_by_tag` und `resolve_tag_fallback` beide auf `status = 'active'` filtern.

**Entschieden:** Es braucht gar keinen. Der Ersatz-Constraint aus Runde A §1 verlangt für `kind = 'studio'` allein `machine_id is null` — ein aktives Schild ohne Gerät ist speicherbar. Die Aktivierung wandert dorthin, wo das Schild entsteht: in die Lieferung.

**Nachgezogen:** Runde B §1 (neuer Abschnitt *„Ein Aushangschild ist ab Lieferung gültig"*), Datenbankplan Task 4 (Kasten *„Woher die Zeilen dann kommen"*, Step 3 gestrichen), `gen_katalog.py`.

### 2. Der Sucher hatte keine Antwort auf die falsche Tag-Sorte

Runde A verbietet einem `studio`-Tag jede `machine_id`. Runde B entscheidet zugleich, dass ein Tag erst durch den Scan benennbar wird — **der Trainer kann ein Aushangschild vor dem Scan nicht von einem Geräteaufkleber unterscheiden, und das ist Absicht.** Scannte er das falsche, war der einzige angebotene Ausgang *Verbinden*, also `machine_id` setzen: vor `0022` ein stiller Schaden, danach eine Check-Verletzung ohne Bildschirm dahinter.

**Entschieden:** Eine siebte Antwort, als Sackgasse mit einem Ausgang. Nichts zu verbinden, nichts freizuschalten — das Schild ist bereits gültig und gehört an die Wand.

**Nachgezogen:** Runde B §4 (siebte Zeile), `TelefonZustaende` (neunte Karte), und `TelefonKleben` sagt jetzt *„aus der Gerätepackung"* statt *„aus der Packung"* — der Fehlgriff soll nicht eingeladen werden, auch wenn er weiter möglich bleibt.

### 3. Der Datenbankplan hätte den Geräte-Fallback zerstört

`2026-09-01-scan-beitritt-datenbank.md` Task 6 Step 1 behauptete, `resolve_tag_fallback` gebe „heute nur `machine_tag_id`" zurück. **Das stimmte nicht.** `0021_fallback_inhalte.sql` liefert fünf Spalten. Das vorgeschlagene `0025` hätte vier davon weggeworfen, die `apps/web/app/t/[token]/page.tsx` und `tests/integration/fallback-inhalt.test.ts` benutzen. Step 2s Beruhigung („nur die Spaltenzahl ändert sich") war doppelt falsch.

**Nachgezogen:** Step 1 trägt jetzt die vollständige Funktion — sieben Spalten, `kind` und `studio_name` **ergänzt**, `left join machines`, und `m.status = 'active'` in der `where`-Klausel, wo es nur für Gerätetags greift. Letzteres ist der Punkt, an dem die Migration am leichtesten falsch geschrieben wird: stünde der Filter in der Join-Bedingung, käme für ein stillgelegtes Gerät eine Zeile aus lauter Nullen zurück statt der leeren Antwort, die der Test verlangt.

**Nebengewinn:** `studio_name` schließt eine Lücke im Gerätezweig. `FallbackGeraet.dc.html` zeichnet den Studionamen seit jeher in der Kopfleiste, ohne dass die Seite eine Quelle dafür hatte.

---

## Die kleineren Widersprüche

| | Befund | Stand |
| --- | --- | --- |
| **Heimatlos** | Der Satz in *Einstellungen → Studio*, der den Studio-Code zum zweiten Weg erklärt, wurde von Runde A an „den Plan aus Runde B" übergeben; Runde Bs Spec erwähnt ihn nirgends. | **Erledigt.** Runde A §3 hat ihn zurückgenommen und festgelegt: der Code wird **in der App** eingegeben, das Portal zeigt ihn nur an. |
| **Alter Stand** | `EinstellungenStudio.dc.html` sagte noch *„Mit diesem Code treten Mitglieder eurem Studio bei"* — die abgelöste Regel. | **Erledigt** in `gen_verwaltung.py`. |
| **Ein Wort, zwei Produkte** | Dieselbe Datei nannte Papiere mit aufgedrucktem Code „Aushänge", während zwei Bildschirme weiter ein *Aushang* ein geliefertes Schild mit Token ist. | **Erledigt:** jetzt „Ausdrucke und Verträge", plus der Satz, dass Aushangschilder keinen Code tragen und gültig bleiben. |
| **Notiz gegen Bildschirm** | Runde B schrieb `note-einstieg` auf *„das kommt über den Scan eines Aushangs, ersatzweise über den Studio-Code"* — `KeinStudio.dc.html` darunter sagte weiter *„Gib den Code ein"*. | **Anders gelöst als vermutet.** Nicht die Notiz hatte recht, sondern ihr eigener erster Satz: *„für Mitglieder gibt es hier nichts."* Beide beschrieben den Weg eines Mitglieds auf einer Seite, die keinem Mitglied gehört. Der Bildschirm hat das Code-Feld verloren, die Notiz den Satz. |
| **Migrationsnummer** | Der Datenbankplan reserviert `0022`–`0025`, Runde B braucht „eine Migration" ohne Nummer. Auf Platte endet es bei `0021`. | **Erledigt:** `0026`, in beiden Dokumenten benannt. Aus einer Spalte sind dabei zwei geworden — die Charge und die aufgedruckte Nummer, ohne die *Sperren* auf der Tags-Seite kein Ziel hat. |
| **Beispielbestand** | Member und Portal beschrieben zwei verschiedene Studios. | **Erledigt.** Der Konflikt war größer als die eine Zeile: neben Modell (*Technogym Selection* gegen *Gym80*) und Bereich (*Kraftbereich* gegen *Fensterseite*) lief auch die Gerätenummer auseinander — `Gerät 12` war in der App ein Kabelzug, im Portal ist 12 ein Latzug und der Kabelzug die 14. Die Member-Artboards ziehen jetzt auf den Portal-Bestand nach, einschließlich der vierten Übung am Kabelzug. |
| **Rail-Zahl** | Vier Portal-Artboards zeigten noch *„Tags · 1 vorrätig"* statt *97*. | **Erledigt.** Kein Textfehler: `build.py` stand längst auf 97, aber `gen_verwaltung.py` — der Generator genau dieser vier Seiten — lief beim Stimmigkeits-Durchgang `b66febe` nicht mit. |

**Kleinkram, ebenfalls erledigt:** Runde A nummerierte Home als 22/23, die Canvas führt 20/21 (und Home-leer **vor** Home). Runde A nannte in *einem* Absatz zweimal ein Studio *„Nordstraße"*, das nirgends sonst existiert — jetzt „Kraftwerk Nord". Der Datenbankplan verwies auf ein „Task 7", das es nicht gibt. Runde Bs Bildschirmtabelle zählte 15 neu, markierte aber 14 mit `+`.

---

## Der Datenbankplan, Aufgabe für Aufgabe

Er ist weiterhin **nicht ausgeführt** — auf Platte endet es bei `0021`. Nach dieser Runde gilt:

| Aufgabe | Stand |
| --- | --- |
| **1 · `tag_kind` und Constraint-Umbau** | **Gültig, und wichtiger als gedacht.** Der Constraint ist nicht nur Schutz, er ist die Grundlage von Entscheidung 1: nur weil er für `kind='studio'` allein `machine_id is null` verlangt, kann ein Schild ohne Gerät aktiv sein. |
| **2 · `join_studio_by_tag`** | **Gültig.** `on conflict do nothing` deckt genau den Fall ab, den *„Probe scannen"* erzeugt. |
| **3 · Selbstaustritt-Policy** | **Gültig.** Von beiden Runden unberührt. |
| **4 · Fachschicht** | **Auf den Lesepfad zurückgeschnitten.** Step 3 ist gestrichen und trägt jetzt die Begründung; die beiden Tests, die „ein Aushang entsteht durch `createTag`" kodierten, sind mit ihm weg. Steps 4–6 (`CatalogTag.kind`) bleiben nötig. |
| **5 · Portal-Aushang** | **Tot, richtig gestrichen.** |
| **6 · Web-Fallback** | **Steps 1 und 2 sind neu geschrieben** (Befund 3). Steps 3–6 bleiben gültig, die Artboards dafür stehen. |

**Nicht in diesem Plan enthalten:** das Anlegen der Lieferzeilen. Das ist Betreiberarbeit und gehört in einen eigenen Plan.

---

## Was stimmig war und geblieben ist

Der Tokenraum, `join_studio_by_tag`, die Selbstaustritt-Policy, `kind` selbst, beide Canvases mit ihren Zählungen und Dateilisten, und die Übernahme von Runde As §1 durch Runde B. **Der Bruch lag nicht zwischen den Runden, sondern in der Lücke, die beide für die jeweils andere offen gelassen haben** — und Lücken schließt man nicht, indem man beide Seiten noch einmal liest, sondern indem jemand entscheidet, wem sie gehört.
