# Geräteeinrichtung aus dem Gymtavo-Katalog — Typwerte übernehmen, Herstellermodelle wählen

**Stand:** 10. Oktober 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Etappe 2 (Import, 0048) und Etappe 5 (Typwahl im Portal) aus `2026-10-06-gymtavo-katalog-offener-zugang-design.md` sind in `master`.
**Verhältnis zu anderen Dokumenten:** Baut auf Abschnitt 5 (Datenmodell), 9.1 (Importformat) und 10 (Portal) der Katalog-Spec auf. Ändert dort nichts, ergänzt das Importformat um `products[]` und den Anlegeablauf im Portal.

---

## 1. Ausgangslage

- Die Typwahl im Portal ist Pflicht (Etappe 5), setzt aber nur `equipment_models.catalog_model_id`. Name, Hersteller, Belastung, Einstellungen und Foto des neuen Modells starten leer.
- Übungen und Videos des Typs kommen schon per Verweis zur Lesezeit dazu (`bootstrap.ts`, `machine-context.ts`, Portal-Reiter Übungen). Einstellungen nicht: `machine-context.ts` liest nur die des Studio-Modells.
- Der Hersteller ist freier Text (`equipment_models.manufacturer`, 0004).
- In Produktion liegt der Katalog: 55 Gerätetypen, 89 Einstellungen, 162 Übungen, 162 Videos. Typfotos sind gezeichnete Startposen. Die Belastungswerte der Typen sind Platzhalter aus dem GYMTAVO-Paket (8–12 Wdh., 1 kg Stufe, keine Grenzen).
- Das GYMTAVO-Paket enthält unter `manufacturers/` 119 Herstellermodelle von 9 Herstellern (Precor 35, gym80 26, Life Fitness 20, Technogym 14, Hammer Strength 11, SCHNELL 9, Concept2 2, Assault 1, Matrix 1):
  - Zuordnung zu Typen über `equipment_type_candidates` mit denselben Schlüsseln wie `catalog/gymtavo.json`. 102 Modelle haben einen Typ, 17 mehrere. 114 lösen vollständig auf; 5 zeigen auf Bank-Typen, die der Katalog nicht hat (`flat_bench`, `adjustable_bench`, `decline_bench`, `preacher_bench`, `upright_bench`).
  - Keine Belastungsdaten. Hinweise wie „scheibenbeladen, nicht die Stapel-Skala übernehmen“ stehen nur in `review_note_de`.
  - Alle 119 haben `rights_status = permission_pending`. 74 Fotos liegen als Download vor, 9 davon visuell geprüft.

## 2. Ziel

Ein Studio richtet einen großen Teil seiner Geräte ein, ohne abzutippen und ohne Fotos zu machen:

1. Gymtavo-Gerätetyp wählen. Kategorie, Belastung, Nebenbelastung, Einstellungen und Foto kommen vom Typ, die Übungen samt Videos wie bisher per Verweis.
2. Hersteller wählen.
3. Gibt es zu Typ und Hersteller konkrete Modelle, das Modell wählen. Name, Hersteller, wo bekannt die Belastung und, wo die Rechte geklärt sind, das Foto kommen von dort. Sonst ein eigenes Modell, ohne abzutippen, was der Typ weiß.

Erfolg: Ein Trainer legt eine gym80-Brustpresse an und tippt höchstens Ausnahmen ein, etwa das echte Gewichtsraster.

## 3. Entscheidungen

| # | Frage | Entscheidung |
|---|---|---|
| G1 | Typwerte ins Studio-Modell: Kopie oder Verweis? | **Kopie beim Anlegen.** Belastung und Einstellungen werden ins Studio-Modell geschrieben, Katalogänderungen wirken danach nicht nach. Ein Studio-Gerät hat eigene Stufen und eigene Historie (Katalog-Spec 8.1); ein Verweis würde Platzhalter live in echte Geräte reichen. Übungen bleiben Verweise (Katalog-Spec E2). |
| G2 | Wo leben Herstellermodelle? | **Eigene Tabelle `catalog_products`** mit Verknüpfung zu mehreren Typen. Im Katalogstudio wären sie in `equipment_models` für jeden heutigen Leser ein Gerätetyp (Bootstrap, Freies Training, Typsuche) und bräuchten überall einen Filter. |
| G3 | Herstellerfotos | **Rechtestatus je Produkt, gezeigt wird nur Geklärtes.** Ein ungeklärtes Foto kommt weder ins Repo noch in den Bucket. Sonst zeigt das Portal die Typillustration als Symbolbild. |
| G4 | Belastung am Herstellermodell | **Optionale Felder, alles oder nichts.** Heute leer, später per Datei. Beim Vorbefüllen gilt Produkt vor Typ. Die Notiz aus dem Paket kommt als Hinweistext mit. |
| G5 | Foto eines neuen Studio-Modells | Eigener Upload, sonst Produktfoto, sonst Typillustration. **Immer als Kopie im Ordner des Studios**, nie als Pfad in den Gymtavo-Ordner: `uploadEquipmentPhoto` löscht beim Ersetzen das bisherige Objekt, und `is_media_published` (0021) gibt über `photo_path` anonym frei. |
| G6 | Zuschnitt | **Zwei Etappen.** A: Vorbefüllen aus dem Typ, ohne Migration. B: Herstellermodelle (Migration, Import, Portal). Jede ist für sich lauffähig. Inhaltsarbeit und Pflege im Portal kommen später (Abschnitt 8). |

## 4. Begriffe

- **Gymtavo-Gerätetyp** (kurz Typ): wie in der Katalog-Spec, ein `equipment_models`-Datensatz im Gymtavo-Studio.
- **Herstellermodell** (im Code `catalog_product`, kurz Produkt): ein konkretes Gerät eines Herstellers, z. B. gym80 Pure Kraft 4345, einem oder mehreren Typen zugeordnet.
- **Studio-Modell:** `equipment_models` eines Studios. Es verweist auf genau einen Typ (`catalog_model_id`) und merkt sich optional, aus welchem Produkt es entstand (`catalog_product_id`).
- **Vorbefüllen:** Werte des Typs bzw. Produkts stehen im Formular, bevor der Trainer etwas eingibt.

## 5. Etappe A: Vorbefüllen aus dem Typ

Keine Migration. iOS, Bootstrap und Satzlogik bleiben unverändert.

### 5.1 Domain

- `listCatalogTypes` liefert je Typ zusätzlich `category`, `loadUnit`, `loadStep`, `loadMin`, `loadMax`, die Nebenbelastung (`secondaryUnit`, `secondaryStep`, `secondaryMin`, `secondaryMax`) und `photoPath`. Bei 55 Typen reicht das, um im Browser vorzubefüllen, ohne nach der Typwahl den Server zu fragen.
- Neu: `copyTypeDefaults(client, { equipmentModelId })`. Sie liest den Typ des Modells (`catalog_model_id`) und
  1. kopiert dessen Einstellungen als eigene Zeilen des Studio-Modells: `key`, `label`, `kind`, `min_value`, `max_value`, `step_value`, `unit`, `allowed_values`, `sort_order`. Ein Schlüssel, den das Modell schon hat, wird übersprungen.
  2. kopiert, wenn das Modell kein Foto hat und der Typ eins, die Typillustration nach `<studioId>/models/<modelId>/<uuid>.<ext>` im Bucket `equipment-photos` und trägt den Pfad ein. Die Bytes werden geladen und über denselben Weg wie `uploadEquipmentPhoto` geschrieben (Prüfung am Inhalt, Metadaten entfernt).
  - Rechte: Aufrufer muss Staff im Studio des Modells sein. Das Modell darf nicht im Gymtavo-Studio liegen. Ohne Typ tut die Funktion nichts.
  - Schlägt ein Teil fehl, bleibt das Modell bestehen; die Funktion meldet einen `DomainError`. Eine Transaktion über Datenbank und Storage gibt es nicht.

### 5.2 Portal

- Formulare: Schreibtisch-Assistent `geraete/neu` (`ModellAnlegenFormular`) und Hallen-Assistent `einrichten/modell/neu` (`ModellNeuFormular`).
- Wird ein Typ gewählt, setzt das Formular `ModellBelastungRad` auf die Werte des Typs (Einheit, Stufe, Min, Max, Nebenbelastung). Darunter steht: „Werte vom Typ {Name} übernommen – bitte ans Gerät anpassen.“ Ein Typwechsel überschreibt die Werte erneut.
- Das Feld Name bekommt den Typnamen, solange es leer ist.
- Der Kategorie-Schritt im Schreibtisch-Assistenten bleibt und filtert die Typliste auf die Kategorie. Die Kategorie des Modells ist damit immer die des Typs.
- Hallen-Assistent: Das Foto ist heute Pflicht (Knopf gesperrt, Server-Action lehnt ab). Die Pflicht entfällt, wenn der gewählte Typ eine Illustration hat. Der Hinweis am Fotofeld sagt dann: „Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen.“ Ohne Typ oder bei einem Typ ohne Illustration bleibt das Foto Pflicht.
- Server-Action `modellAnlegen` (beide Assistenten): Modell wie heute mit den Formularwerten anlegen (der Trainer hat sie gesehen, also gelten sie), im Hallen-Assistenten ein eigenes Foto wie heute hochladen, danach `copyTypeDefaults`. Ein Fehler dort leitet trotzdem weiter und zeigt auf der Folgeseite, was fehlt.
- Der nächste Assistentenschritt ist „Einstellungen“; dort stehen die kopierten Einstellungen und lassen sich anpassen oder löschen.
- `StammdatenFormular`: Ein Typwechsel an einem bestehenden Modell ändert nur die Zuordnung, wie heute. Werte, Einstellungen und Foto bleiben. Altbestände bekommen nichts kopiert.

### 5.3 Tests

- Unit: Abbildung Typ → Formularwerte (mit und ohne Nebenbelastung, Cardio-Typ).
- Integration gegen das geteilte lokale Supabase, nie zurückgesetzt, mit eigenem Testtyp (Zufallsschlüssel) samt Einstellungen und Foto:
  - Einstellungen werden kopiert, inklusive `allowed_values` und Reihenfolge; ein vorhandener Schlüssel bleibt unberührt.
  - Foto landet im Studioordner, nicht im Gymtavo-Ordner; ein vorhandenes eigenes Foto bleibt.
  - Ein Nicht-Staff-Nutzer bekommt einen Fehler; ein Modell ohne Typ bleibt unverändert.
- Playwright: Brustpresse wählen → Belastung und Name stehen im Formular → nach dem Speichern sind Einstellungen und Foto da.

## 6. Etappe B: Herstellermodelle

### 6.1 Datenmodell (Migration `0049_catalog_products.sql`)

**`catalog_products`**

| Spalte | Regel |
|---|---|
| `id uuid` | Primärschlüssel |
| `catalog_key text not null` | eindeutig, Muster `^[a-z0-9_]+$` |
| `manufacturer text not null` | nicht leer |
| `series text` | `null` oder nicht leer |
| `name text not null` | Modellname, nicht leer |
| `model_code text` | `null` oder nicht leer |
| `product_url text` | `null` oder beginnt mit `https://` |
| `note text` | Hinweistext, `null` oder nicht leer |
| `photo_path text` | |
| `photo_rights text not null default 'pending'` | `pending` oder `cleared` |
| `load_unit`, `load_step`, `load_min`, `load_max` | alle vier gesetzt oder keins; Einheiten und Grenzen wie `equipment_models` (0046) |
| `secondary_unit`, `secondary_step`, `secondary_min`, `secondary_max` | alle vier oder keins, Regeln wie 0046 |
| `created_at`, `updated_at` | |

- Check `photo_path is null or photo_rights = 'cleared'`. Ein ungeklärtes Foto kann so nie angezeigt werden, auch nicht durch einen Fehler im Code.

**`catalog_product_types`**

- `(product_id references catalog_products on delete cascade, equipment_model_id references equipment_models on delete restrict)`, Primärschlüssel über beide.
- Trigger: `equipment_model_id` liegt im Gymtavo-Studio (`is_catalog_studio`).

**RLS:** beide Tabellen `select` für `authenticated`, keine Schreib-Policies. Geschrieben wird nur mit der Service-Rolle, also vom Import. Pflege im Portal kommt mit Etappe 6 der Katalog-Spec.

**`equipment_models.catalog_product_id uuid null references catalog_products on delete restrict`**

- Bedeutet nur Herkunft; die Werte sind kopiert (G1).
- Trigger: verboten im Gymtavo-Studio. Ob das Produkt zum zugeordneten Typ passt, prüft er nicht. Sonst scheiterte ein späterer Typwechsel im `StammdatenFormular`, und die Spalte wirkt nicht aufs Training.

**Fotos:** im Bucket `equipment-photos` unter `<Gymtavo-ID>/catalog/products/<key>-<sha256, 8 Zeichen>.<ext>`. Die Lese-Policy aus 0047 (`media_select` mit `is_catalog_studio`) deckt den Pfad ab.

### 6.2 Importformat (Ergänzung zu Katalog-Spec 9.1)

Neue Liste `products[]` in `catalog/gymtavo.json`:

```json
{
  "key": "gym80_pure_kraft_4345", "manufacturer": "gym80", "series": "Pure Kraft",
  "name": "Brustpresse", "model_code": "4345", "product_url": "https://…",
  "types": ["chest_press"], "note": "Scheibenbeladen, eigenes Lastprofil.",
  "photo": null, "photo_rights": "pending",
  "load_unit": null, "load_step": null, "load_min": null, "load_max": null,
  "secondary": null
}
```

**Prüfregeln** (zusätzlich zu 9.1, gesammelt mit Ort wie dort):

- `key` folgt dem Muster und ist in `products[]` eindeutig.
- `manufacturer` und `name` sind nicht leer; `series`, `model_code`, `note` sind `null` oder nicht leer; `product_url` ist `null` oder beginnt mit `https://`.
- `types` hat mindestens einen Eintrag, ohne Doppelte, jeder ein Schlüssel aus `equipment[]`.
- Belastung: alle vier `load_*` `null` oder alle gesetzt; gesetzt gelten die Regeln des Gerätetyps. `secondary` ist `null` oder vollständig wie am Typ.
- `photo_rights` ist `pending` oder `cleared`. `photo` ist `null` oder ein vorhandenes PNG bzw. JPEG.

**Import** (`pnpm catalog:import`, Ablauf wie 9.1, Produkte nach den Typen):

- Upsert der Produkte über `catalog_key`, Verknüpfungen über `(product_id, equipment_model_id)`. Produkte und Verknüpfungen, die die Datei nicht mehr nennt, werden nur gemeldet.
- Foto: bei `cleared` hochladen wie Typfotos (vorhandener Pfad wird übersprungen, geänderte Datei bekommt neuen Pfad, altes Objekt bleibt und wird gemeldet). Bei `pending` wird ein gesetztes `photo` geprüft, aber nicht hochgeladen, und gemeldet.
- **Ausnahme von „nie löschen, nur melden“:** Steht ein Produkt in der Datenbank mit Foto, in der Datei aber auf `pending`, setzt der Import `photo_path` auf `null`. Das Objekt bleibt liegen und wird gemeldet. Ein Rechteentzug muss sofort wirken.
- `--dry-run` zeigt Produkte und Verknüpfungen im Plan wie die übrigen Tabellen.

### 6.3 Erstbestand

- Ein einmaliger Konverter außerhalb des Repos (wie in 9.1) übernimmt aus `manufacturers/herstellerbilder-kandidaten.json` die **114 Modelle, deren Typen alle im Katalog stehen**:
  - `key` = Paket-`id`, `manufacturer`, `series`, `name` = `model`, `model_code`, `product_url`, `types` = `equipment_type_candidates`, `note` = `review_note_de`.
  - `photo: null`, `photo_rights: "pending"`, keine Belastung.
- Die Paket-UUIDs (`candidate-id-map.json`, `equipment_models.candidates.json`) werden nicht verwendet.
- **Die Herstellerfotos kommen nicht ins Repo**, solange ihre Rechte offen sind. Ins Repo kommt nur, was gezeigt werden darf.

### 6.4 Domain

- `listCatalogTypes` liefert je Typ zusätzlich `products`: `id`, `key`, `manufacturer`, `series`, `name`, `modelCode`, `note`, Belastung und Nebenbelastung (oder `null`), `photoPath` (nur bei geklärtem Foto gesetzt). Ein Produkt mit mehreren Typen erscheint bei jedem. Geladen über den gecachten `ladeTypen()`.
- `createEquipmentModel` nimmt `catalogProductId` (nullish). Ein unbekanntes Produkt wird `validation_failed`.
- `copyTypeDefaults` wird zu `copyCatalogDefaults`: Einstellungen immer vom Typ. Foto, wenn das Modell keins hat: Produktfoto, sonst Typillustration, immer als Kopie im Studioordner (G5).

### 6.5 Portal

Beide Assistenten, aufbauend auf Etappe A:

1. **Gymtavo-Gerätetyp** wie heute, Vorbefüllen wie 5.2.
2. **Hersteller:** Auswahl mit Suche über die Hersteller mit Produkten zu diesem Typ, je mit Anzahl („gym80 (5)“), dazu **„Anderer Hersteller“**, das das freie Textfeld öffnet. Hat der Typ keine Produkte, steht gleich das Textfeld da.
3. **Modell:** nur bei einem Hersteller mit Produkten. Karten mit Bild (Produktfoto oder Typillustration mit Vermerk „Symbolbild“), Serie, Name, Code; am Ende **„Mein Modell ist nicht dabei“**.
   - Modell gewählt: Name = „{Serie} {Name} {Code}“ ohne leere Teile (z. B. „Pure Kraft Brustpresse 4345“), editierbar. Hersteller gesetzt. Belastung vom Produkt, wenn bekannt, sonst bleiben die Typwerte. Die Notiz steht als Hinweis über dem Belastungsrad. `catalogProductId` geht als verstecktes Feld mit.
   - Nicht dabei: Name und Belastung bleiben auf den Typwerten, der Hersteller ist gesetzt, kein `catalogProductId`.
   - Ein Typwechsel setzt Hersteller- und Modellwahl zurück.
- `StammdatenFormular`: Bei gesetzter Herkunft eine schreibgeschützte Zeile „Vorlage: {Hersteller} {Serie} {Name} {Code}“. Ein Produkt nachträglich zuweisen gehört nicht zu dieser Etappe; die Werte würden ohnehin nicht neu kopiert.
- Im Gymtavo-Studio selbst zeigt das Portal keine Produkte (kommt mit Etappe 6).

### 6.6 Tests

- Unit: Prüfregeln für `products[]`, Planbildung, Herstellerliste je Typ, Namensbildung.
- Integration gegen das geteilte lokale Supabase, nie zurückgesetzt, Zufallsschlüssel `t_<zufall>_…`, nur eigene Zeilen und Objekte werden abgeräumt:
  - Erstimport von Produkten mit Verknüpfungen, zweiter Lauf meldet nur „unverändert“.
  - Foto bei `cleared` wird hochgeladen; Wechsel auf `pending` setzt `photo_path` auf `null`.
  - Check verbietet `photo_path` bei `pending`.
  - Ein Angemeldeter liest Produkte und Verknüpfungen, kann aber nicht schreiben.
  - Verknüpfung mit einem Typ außerhalb des Gymtavo-Studios scheitert; `catalog_product_id` im Gymtavo-Studio scheitert.
  - Anlegen mit Produkt setzt Herkunft und Foto in der Reihenfolge eigener Upload → Produktfoto → Typillustration; ein Produkt mit `pending` liefert die Typillustration.
- Playwright:
  1. Brustpresse → gym80 → Modell: Name, Hersteller und Hinweis stehen; nach dem Speichern auch Einstellungen und Foto.
  2. „Mein Modell ist nicht dabei“ behält die Typwerte.
  3. „Anderer Hersteller“ ergibt freien Text.

## 7. Produktion

- Etappe A braucht keine Migration und keinen Import; sie geht mit dem Merge live.
- Etappe B: Migration 0049, dann `pnpm catalog:import --dry-run` (erwartet 114 neue Produkte, sonst unverändert), dann `--ja`. Beides erst nach dem Merge und auf ausdrückliche Freigabe.

## 8. Offen, bewusst später

- **Bank-Typen:** `flat_bench`, `adjustable_bench`, `decline_bench`, `preacher_bench`, `upright_bench` im Katalog anlegen, dann die fünf übrigen Modelle aus dem Paket übernehmen.
- **Startwerte je Typ:** realistische Stufe und Grenzen statt der Platzhalter. Fachliche Entscheidung, Daten aus der Datei.
- **Raster je Produkt:** Belastungswerte aus Herstellerdatenblättern in `products[]` nachtragen.
- **Fotorechte:** je Hersteller klären; geklärte Fotos mit `photo_rights: "cleared"` in Datei und `catalog/media/` aufnehmen.
- **Pflege im Portal** (Etappe 6 der Katalog-Spec), einschließlich Produkte.
- Produkt nachträglich einem bestehenden Studio-Modell zuweisen, ggf. mit „Werte übernehmen“.
- Einstellungen des Typs zur Lesezeit erben statt kopieren – nur, falls Studios das verlangen.
