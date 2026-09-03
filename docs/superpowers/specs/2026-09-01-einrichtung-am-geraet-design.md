# Einrichtung am Gerät — Tags als Lieferung, der Gang durch die Halle

**Stand:** 1. September 2026, zweite Runde
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-08-31-trainerportal-struktur-design.md` (Struktur), `2026-09-01-scan-beitritt-design.md` (Tokenraum, Aushang), `2026-08-30-designsystem.md` (Tokens)
**Nachgezogen am 1. September 2026** durch `2026-09-01-tag-lieferung-design.md` — betroffen sind §1, §4, §5, §6 und §7; die Stellen sind unten einzeln markiert.
**Ändert:** `2026-09-01-scan-beitritt-design.md` §3 und §6 — der Druckbogen entfällt, der Aushang wird ein geliefertes Schild. Und `2026-08-31-trainerportal-struktur-design.md` §5 bekommt eine benannte Ausnahme.
**Canvas:** Trainerportal `fa12ef14-ca77-4fcc-a034-886a38914984`, Seite *Einrichten am Gerät*
**Zweite Runde:** Der Gang wird sechsschrittig. Das Foto ist im Gang Pflicht statt Beiwerk, und die Einstellparameter wandern aus der Schreibtischspalte in einen eigenen Schritt 2. Betroffen sind §2, §3, §5, §7 und die Entscheidungen (Nachtrag 9–13).

---

## Warum dieses Dokument existiert

Für den gesamten Weg „Gerät anlegen, Übungen zuordnen, Tag ankleben" stand auf der Canvas **ein einziger Bildschirm**: die Übungsliste eines Modells mit einem laufenden Videoupload. Aus dem geht nicht hervor, wo der Ablauf anfängt, was passiert, wenn das Modell noch gar nicht existiert, und wie mehrere Übungen an ein Gerät kommen.

Vor allem fehlte der Moment, um den sich der ganze Gang dreht: **der Tag, den man in genau diesem Augenblick auf das Gerät klebt und danach scannt.**

Dabei kam eine falsche Annahme ans Licht, die heute in der Oberfläche *und* im Code steckt. Das Portal **erzeugt** einen Token, zeigt ihn genau einmal an, und der Trainer druckt daraus einen QR-Code (`Tags.dc.html`, `TagAnlegen.tsx`, `createTag` in `packages/domain/src/catalog.ts`). Das ist ein Umweg um ein physisches Erzeugnis herum. Ein Tag ist ein Aufkleber mit NFC-Chip und aufgedrucktem QR — beide auf derselben `/t/<token>`-Adresse, wie `2026-09-01-scan-beitritt-design.md` §1 es ohnehin schon festlegt. Solche Aufkleber werden chargenweise hergestellt, nicht im Studio gedruckt.

**Wofür es der Eingang ist.** Aus diesem Dokument entsteht ein Umsetzungsplan. Er ist kleiner als der, den die Vorgängerspec erwarten ließ: der Druckbogen als PDF entfällt, und mit ihm der Erzeugen-Pfad im Portal. Übrig bleibt genau ein echter Neubau.

---

## Entscheidungen

Acht, alle in dieser Runde getroffen:

1. **Tags kommen als Lieferung, das Studio erzeugt keine.** Chargenweise hergestellt, chargenweise beim Versand einem Studio zugeordnet — eine Handlung, hundert Tags.
2. **Im Portal entsteht kein Token mehr — auch nicht für den Aushang.** Der Erzeugen-und-Drucken-Pfad verschwindet aus der Oberfläche und aus dem Code.
3. **Der Vorrat ist eine Zahl, keine Liste.** Achtzig identische Zeilen „vorrätig · ohne Gerät" lassen sich keinem Aufkleber in der Packung zuordnen. Benennbar wird ein Tag erst durch den Scan.
4. **Der Sucher lebt im Portal.** Ein durchgehender Fünfschritt, kein Sprung aus dem Portal heraus.
5. **Der NFC-Chip bleibt auf dem Tag, spielt im Trainerweg aber keine Rolle.** Ein Browser liest kein NFC. Der Chip trägt den Weg des Mitglieds; der Trainer nutzt allein den aufgedruckten QR.
6. **Ein neues Gerätemodell darf am Telefon entstehen — knapp.** Foto, Name, Hersteller, Gewichtsschritt, Spanne. Alles Weitere bleibt Schreibtisch.
7. **„Offline" gilt im Portal nicht — außer hier.** Ausdrückliche Ausnahme zu §5 der Strukturspec, nur für diese Seite.
8. **Ein vergebener Tag wird nicht mit einem Tap umgehängt.** Der Scan gibt Auskunft, zu welchem Gerät er gehört — und zwei Nebenaktionen, keine Hauptaktion.

### Nachtrag der zweiten Runde

Fünf weitere, alle aus derselben Frage: was kennt nur, wer vor dem Gerät steht?

9. **Foto und Einstellparameter hängen am Modell, nicht am Gerät.** `equipment_models.photo_path` und `equipment_setting_definitions` stehen seit M0 so. Zwei baugleiche Kabelzüge teilen sich beides — der zweite läuft durch Schritt 1 und 2 mit einem Tap durch.
10. **Das Foto bleibt im Bildschirm „Modell anlegen", wird dort aber Pflicht.** Kein eigener Schritt und keine zweite Aufnahme. Es ist der Grund, warum ein Mitglied nach dem Scan merkt, dass es vor dem falschen Gerät steht — das ist keine Nacharbeit.
11. **Die Einstellparameter werden Schritt 2, überspringbar.** Ohne sie ist das Gerät vollständig nutzbar; das Mitglied hat nur nichts zu kalibrieren. Die Rasten zählt aber nur ab, wer davorsteht: am Schreibtisch werden sie geraten oder gar nicht erfasst, und dann ist `GeraetKalibrierung` in der Member-App leer.
12. **Ein bestehendes Modell ohne Foto wird in Schritt 2 nachgefragt.** Dort steht die Zeile dann als *„Foto fehlt"*. Das ist der einzige Weg, ein Altmodell im Gang zu vervollständigen.
13. **Der Gang wird sechsschrittig:** Modell · Einstellungen · Gerät · Tag · Übungen · Video.

---

## 1. Der Tag als Erzeugnis

### Das Schema trägt es ohne Änderung

`0002_machine_tags.sql` und `0008_machine_tags_fk.sql` stehen seit M0 so, wie dieses Modell sie braucht:

```
machine_tags   studio_id not null, machine_id nullable, token_hash unique,
               status ∈ unassigned | active | revoked | replaced
```

Eine Lieferung ist damit schlicht: N Zeilen mit `status = 'unassigned'`. Der Scan setzt `machine_id` und `status = 'active'`. Die Check-Constraint `machine_tags_active_needs_machine` bewacht genau diesen Übergang. **Kein Umbau, keine neue Tabelle.**

### Ein Aushangschild ist ab Lieferung gültig

Für Gerätetags gilt der Satz oben. Für Aushangschilder gilt er nicht, und das ist kein Sonderfall, sondern die Folge davon, dass sie an keinem Gerät hängen: **Aushangschilder entstehen bei der Chargenzuordnung schon `active`**, Gerätetags weiter als `unassigned`.

Der Ersatz-Constraint aus `2026-09-01-scan-beitritt-design.md` §1 lässt genau das zu — für `kind = 'studio'` verlangt er allein `machine_id is null`, nicht den Umweg über ein Gerät:

```sql
check (case kind
         when 'machine' then status <> 'active' or machine_id is not null
         when 'studio'  then machine_id is null
       end)
```

Damit braucht die Aktivierung **keinen zweiten Weg**: keine Portal-Aktion, kein Formular, keinen Fachschicht-Aufruf. Der Satz im nächsten Abschnitt — *„Im Portal gibt es dafür keinen Bildschirm"* — bleibt dadurch wahr, statt eine Lücke zu beschreiben. Ohne diese Festlegung wäre er eine: `createTag` fällt in §6 weg, und ein geliefertes Schild könnte nie aktiv werden, während `join_studio_by_tag` und `resolve_tag_fallback` beide auf `status = 'active'` filtern.

**Alle Schilder einer Lieferung sind gleichwertig.** Welches am Eingang hängt und welche vier in der Schublade liegen, weiß das Portal nicht und muss es nicht wissen — jedes von ihnen macht den Scannenden zum Mitglied. Was das Portal können muss, ist ein einzelnes Schild sperren, wenn es verloren geht.

### Die fehlenden Spalten

Die **Charge** — ohne sie kann das Portal „Lieferung vom 12. August · 100 Tags · 97 vorrätig" nicht zeigen, und ohne diese Zeile weiß ein Trainer nicht, ob die Packung neben ihm zum Studio gehört.

Dazu die **laufende Nummer innerhalb der Charge**, die auf dem Schild aufgedruckt ist. Sie ist der einzige Weg, auf der Tags-Seite ein bestimmtes Aushangschild zu benennen: ein Schild hat kein Gerät, über das es sich identifizieren ließe, und einen Ort kennt niemand — den hat nie jemand eingegeben. Ohne die Nummer hat *Sperren* kein Ziel.

~~**Eine Migration, zwei nullable Spalten** (`0026`).~~ **Nachgezogen:** daraus sind **drei Migrationen** geworden — `0026` Tokenraum, `0027` Chargen und Halde, `0028` die zwei Tag-Funktionen. Die Halde liegt in `machine_tags` selbst, mit nullbarem `studio_id` und `batch_id`/`batch_index` als `not null`. Vollständig in `2026-09-01-tag-lieferung-design.md` §1 und §2.

### Der Hash bleibt, und er war nie das Umständliche

`packages/domain/src/tags.ts` sagt es selbst: *„Der Token ist ein oeffentlicher Locator, keine Authentisierung."* Der Token steht im Klartext auf einem Aufkleber in einer Turnhalle; er ist kein Geheimnis. Nur den SHA-256 zu speichern kostet trotzdem nichts und verhindert, dass ein Datenbankabzug eine fertige Liste funktionierender Adressen **aller** Studios ist. Das bleibt.

Der Druckbogen kam nicht vom Hash. Er kam allein daher, dass das Portal die Tokens selbst erzeugte und sie danach nie wieder zeigen konnte.

### Wer welchen Tag bekommt, entscheidet die Charge

Tags entstehen in Chargen: der Betreiber erzeugt N Tokens mit `createTagToken`, gibt die Liste an den Tag-Lieferanten und spielt die Hashes ein. Beim Versand wird eine **ganze Charge** einem Studio zugeordnet. Der Betreiber muss beim Kommissionieren nichts scannen — die Nummer steht auf der Packung.

Die Sorte kommt ebenfalls aus der Charge: Geräte-Tags sind On-Metal-Aufkleber, Aushänge sind Schilder. Zwei Erzeugnisse, zwei Chargen, `kind ∈ machine | studio` aus `2026-09-01-scan-beitritt-design.md` §1. **Im Portal gibt es dafür keinen Bildschirm.**

> **Nachgezogen — der Satz „beim Versand wird eine ganze Charge einem Studio zugeordnet" gilt nur noch für Schilder.**
>
> Er setzt voraus, dass der Betreiber beim Kommissionieren weiß, *welche* Aufkleber in welche Kiste gehen. Aus einem Tausenderpack greift er sie aber unbenannt heraus, und Entscheidung 3 sagt ohnehin: benennbar wird ein Tag erst durch den Scan.
>
> **Gerätetags kommen deshalb studiolos** und lernen ihr Studio erst beim Scan vor dem Gerät, über `bind_tag_to_machine`. Die Lieferung ist für sie eine reine Zahl (`tag_shipments`), aus der die Vorratszeile entsteht — kein Token wird dabei angefasst. **Aushangschilder** dagegen werden namentlich zugeordnet, über ihre aufgedruckte Nummer; sie haben keinen Bindeschritt, an dem sie ihr Studio lernen könnten, und ein Schild ohne Studio ist sinnlos.
>
> **Der Preis, benannt:** Es gibt keinen Fehllieferungsschutz mehr. Kommt die Gerätepackung für Studio B bei Studio A an, bindet A sie klaglos ein. Für Schilder gilt das nicht.
>
> `2026-09-01-tag-lieferung-design.md` §2.

---

## 2. Der Ablauf

Sechs Schritte, je Gerät, vor dem Gerät:

| | Schritt | Was entsteht | Überspringbar |
| --- | --- | --- | --- |
| 1 | **Modell** | Wählen, oder knapp neu: **Foto (Pflicht)**, Name, Hersteller, Gewichtsschritt, Spanne | nein |
| 2 | **Einstellungen** | Einstellparameter des Modells — Sitzhöhe 1–8, Rollenhöhe 1–12, Griff A \| B \| C. Trägt das gewählte Modell kein Foto, steht es hier als Zeile | **ja** |
| 3 | **Gerät** | `machines`-Zeile mit Nummer und Standort | nein |
| 4 | **Tag** | Ankleben, scannen, verbinden — ab hier ist das Gerät auffindbar | nein |
| 5 | **Übungen** | Aus dem Studio wählen oder neu anlegen, Reihenfolge zählt | ja, aber dann zeigt das Gerät nichts |
| 6 | **Video** | Je Übung höchstens 45 s, am Paar Modell × Übung — reine Erklärung | **ja** |

Davor steht die Lieferung, dahinter die Nacharbeit am Schreibtisch: Beschreibungen und fehlende Videos.

**Die Grenze lag in der ersten Runde bei „was macht das Gerät auffindbar".** Sie liegt jetzt eine Stelle weiter: **was ist nur vor dem Gerät überhaupt zu erfahren.** Auffindbarkeit ist davon ein Teil, aber nicht alles. Die Nummer steht am Gerät, der Standort auch — und ebenso, wie das Gerät aussieht und wie viele Rasten die Sitzhöhe hat. Nichts davon steht in einem Katalog, aus dem man es am Schreibtisch abschreiben könnte.

Zwei Posten sind damit aus der Schreibtischspalte hierher gewandert:

- **Das Foto** war ein Feld, das nur beim Anlegen eines neuen Modells auftauchte, und die Oberfläche nannte es vorläufig („ein besseres Foto trägst du am Schreibtisch nach"). Wählte der Trainer ein bestehendes Modell ohne Foto, fragte nichts nach. Dabei ist das Foto der einzige Grund, warum jemand nach dem Scan merkt, dass er vor dem falschen von zwei baugleichen Geräten steht.
- **Die Einstellparameter** kamen im Telefonweg gar nicht vor. Ohne sie zeigt `GeraetKalibrierung` in der Member-App — der Bildschirm, der Sitzposition 1–8 und Startwinkel 0–45° trägt — nichts an.

Schritt 2 bleibt trotzdem überspringbar, das Foto nicht. Der Unterschied: ein Gerät ohne Einstellparameter ist vollständig nutzbar, eines ohne Foto ist verwechselbar.

### Mehrere Übungen

`exercises` ist studioweit; `equipment_model_exercises` hängt eine Übung mit `sort_order` an ein Modell. Also:

- Schritt 4 zeigt eine **Auswahl über die vorhandenen Übungen des Studios**, kein leeres Namensfeld. Sonst steht „Rudern sitzend" fünfmal im Katalog, jedes Mal anders geschrieben.
- Die **Reihenfolge ist keine Kosmetik**: Übung 1 ist am Gerät die Vorauswahl des Mitglieds (Designsystem §8).
- Das **Einweisungsvideo hängt am Paar** aus Modell und Übung (`instruction_assets.equipment_model_exercise_id`), nicht an der Übung. Dieselbe Übung an zwei **Modellen** hat zwei Videos; zwei baugleiche Geräte teilen sich eines. Ein Kabelzug hat ein Foto und zwanzig Videos.

---

## 3. Die Oberfläche

### Die Seite dreht sich um

Die Canvas-Notiz `note-telefon` sagte bisher: die Aufnahme entsteht auf dem Trainerhandy, *alles andere bleibt Schreibtischarbeit*. Der zweite Teil war falsch — nicht für den Katalogeditor, aber für die Einrichtung. Ein Studio wird nicht am Schreibtisch bestückt. Der Trainer steht vor dem Gerät, hat den Tag in der Hand und weiß erst dort, welche Nummer draufsteht und wo es steht.

Die zweite Runde dreht denselben Satz noch einmal ein Stück weiter. Die Notiz behielt zwei Posten am Schreibtisch, die dort ebenso wenig zu holen sind: das Foto und die Einstellparameter. Der Einwand gegen die Parameter am Telefon war, man müsste dafür den Katalogeditor auf 390 px quetschen — er trifft nicht. Gebraucht wird kein Editor, sondern eine Liste mit drei Zeilen und ein Anlegeformular mit vier Feldern.

### Bildschirmverzeichnis

`+` neu, `~` zu ändern. Die Telefonbildschirme tragen keine eigene Nummer — die Zählung steht auf der Schrittleiste („Schritt 4 von 6 · Tag"), und zwei Zählungen nebeneinander wären eine zu viel. Der Bildschirm *Foto aufnehmen* trägt als einziger gar keine Wegmarke: er ist aus Schritt 1 und aus Schritt 2 erreichbar, und eine feste Nummer wäre auf einem der beiden Wege falsch.

| | Bildschirm | Breite |
| --- | --- | --- |
| + | Ablauf — der ganze Gang als Karte | 1440 |
| + | Einstieg — Bestand, Vorrat, „Gerät einrichten" | 390 |
| + | Modell wählen | 390 |
| + | Modell anlegen — knapp, Foto ist Pflicht | 390 |
| + | Foto aufnehmen — randlos, ohne Wegmarke | 390 |
| + | Einstellungen — Foto und Einstellparameter des Modells | 390 |
| + | Parameter anlegen — Zahl oder Auswahl | 390 |
| + | Gerät — Nummer, Standort | 390 |
| + | Tag ankleben — mit Platzierungsskizze | 390 |
| + | Sucher | 390 |
| + | Tag erkannt — verbinden | 390 |
| + | Übung wählen — Sheet über den Studio-Übungen | 390 |
| + | Übung anlegen | 390 |
| ~ | Übungen am Gerät — Nachfolger des alten Telefon-Artboards | 390 |
| + | Aufnahme — 45-Sekunden-Grenze | 390 |
| + | Warteschlange — Uploads über mehrere Geräte | 390 |
| + | Fertig — Probe-Scan, nächstes Gerät | 390 |
| + | Zustände am Telefon — elf Antwortkarten | 390 |
| ~ | Tags — Lieferungen statt Anlegen | 1440 |
| ~ | Modell — „Tag scannen" je Geräteinstanz | 1440 |
| ~ | Überblick — „Am Gerät scannen" statt „Tags anlegen" | 1440 |

**Achtzehn Artboards auf der Seite: siebzehn neu, eines ersetzt** (Übungen am Gerät), **dazu drei geänderte Schreibtischbildschirme.**

Die erste Runde schrieb hier „Fünfzehn neu", markierte in der Tabelle aber vierzehn mit `+` — die fünfzehnte war das ersetzte Artboard. Die Zählung oben ist die berichtigte.

### Die Tags-Seite verliert ihre Akzentfläche

Sie legt nichts mehr an. Sie zeigt Lieferungen, geklebte Tags und den Aushang — eine Auskunft, kein Formular. Das Designsystem lässt **höchstens** eine Akzentfläche je Bildschirm zu; null ist so richtig wie eins, und alles andere wäre eine erfundene Hauptaktion.

### Eine Konvention für die Prüfbarkeit

Der Akzent hat zwei Rollen: die eine Hauptaktion, und der aktive Wert. Im Generator werden sie in der Schreibweise getrennt — `background: #d4ff3f` für die Aktionsfläche, `background-color: #d4ff3f` für Balken und Marken. Dieselbe Farbe, zwei Rollen, und „genau eine Akzentfläche je Bildschirm" wird damit überhaupt erst maschinell prüfbar statt nur behauptet.

---

## 4. Was der Sucher antwortet

| Fall | Antwort | Nächster Schritt |
| --- | --- | --- |
| **vorrätig** | „Tag erkannt · Charge 7" | Verbinden |
| **schon vergeben** | „Dieser Tag gehört zu Beinpresse 7." | Gerät ansehen, oder anderen Tag nehmen — **keine Hauptaktion** |
| **gesperrt** | „Gesperrt bleibt gesperrt." | Anderen Tag aus der Packung |
| **falsche Sorte: ein Aushangschild** | „Das ist ein Aushangschild." | Anderen Tag aus der Gerätepackung — **kein Verbinden** |
| **unbekannt / fremdes Studio** ~~/ Charge nicht zugeordnet~~ | eine einzige Antwort für beide | „Neue Lieferung? Melde dich beim Betreiber." |
| **Kamera nicht freigegeben** | wo man es erlaubt, konkret | kein Rückfallweg |
| **kein Netz** | „gespeichert, wird gesendet" | weitergehen |

Die vierte Zeile ist neu und schließt eine Lücke, die dieser Weg selbst aufreißt. **Der Trainer kann ein Aushangschild vor dem Scan nicht von einem Geräteaufkleber unterscheiden — das ist Absicht**, §3 sagt: „Benennbar wird ein Tag erst durch den Scan." Der Fehlgriff ist damit kein Versehen am Rand, sondern eingeplant. Vor dem `kind`-Constraint wäre er still durchgelaufen und hätte ein Aushangschild in einen Gerätetag verwandelt; danach wirft er eine Check-Verletzung. Beides ist falsch — richtig ist eine Antwort, die sagt, was in der Hand liegt.

Sie ist eine **Sackgasse mit genau einem Ausgang**. Das Schild ist bereits gültig (§1) und gehört an die Wand; es gibt hier nichts zu verbinden, nichts zu aktivieren, nichts zu reparieren.

Die fünfte Zeile ist Absicht und nicht Faulheit: dieselbe Regel, die `join_studio_by_tag` im Rumpf trägt (Vorgängerspec §1). **Anders als beim Mitgliedsweg darf hier der nächste Schritt danebenstehen** — der Trainer ist angemeldet, es gibt keinen Ratepfad zu schützen.

> **Nachgezogen:** *„Charge nicht zugeordnet"* ist als Fall entfallen. Seit Gerätetags studiolos geliefert werden, **ist** die nicht zugeordnete Charge der Normalzustand, aus dem gebunden wird — sie ist Zeile 1, nicht Zeile 5. Die beiden übrigen Fälle bleiben, und die Studiozugehörigkeit wird vor Sorte und Status geprüft: ein gesperrter Tag eines fremden Studios antwortet `unbekannt`, nicht *„gesperrt bleibt gesperrt"*, sonst verrät die Antwort seine Existenz. Die vollständige Zuordnung von Zeile zu Antwort steht als `inspect_tag` in `2026-09-01-tag-lieferung-design.md` §3.

Der Zustand **Offline** gilt hier, obwohl §5 der Strukturspec ihn fürs Portal ausschließt („ein Konzept der Halle, nicht des Schreibtischs"). Dieser Weg *ist* die Halle. Die Formulierung bleibt die des Designsystems: „gespeichert, wird gesendet" — nie „fehlgeschlagen".

---

## 5. Was kein Backend hat

| Posten | Stand |
| --- | --- |
| **Chargen herstellen und ausliefern** | Neu, aber **ausserhalb des Portals**. **Nachgezogen und ausentworfen:** `pnpm tags` mit sechs Befehlen über `packages/domain/src/chargen.ts`, `2026-09-01-tag-lieferung-design.md` §4. Die CSV an den Lieferanten trägt Nummer, Sorte, Token und URL und ist **jederzeit wiederholbar** — der Satz „die Hashes einspielen" ist damit hinfällig, gespeichert wird der Klartext. |
| **Chargenspalte und Schildnummer** | ~~Eine Migration, zwei nullable Spalten.~~ **Nachgezogen:** drei Migrationen `0026`–`0028` plus ein Betreiberskript, vollständig in `2026-09-01-tag-lieferung-design.md`. `2026-09-01-scan-beitritt-datenbank.md` belegt weiterhin `0022`–`0025`. |
| **Sucher im Portal** | **Der einzige echte Neubau, der bleibt.** Safari kennt `BarcodeDetector` nicht, also `getUserMedia` plus ein Decoder im Browser. Sein Backend — `inspect_tag` und `bind_tag_to_machine` — steht danach vollständig; er baut nur noch die Kamera davor. |
| **Tag binden per Scan** | ~~Erweiterung, es fehlt der Weg über den Token-Hash.~~ **Nachgezogen: entschieden und eingeplant** als `bind_tag_to_machine(p_token, p_machine_id)` in `0028`. Sie vergibt zugleich das Studio, weil ein gelieferter Gerätetag keines hat — die Update-Policy aus `0016` greift für studiolose Zeilen nicht. |
| **Modell am Telefon anlegen** | Erweiterung. `equipment_models` und die Server Action bestehen; es fehlt die knappe mobile Form. |
| **Foto am Telefon** | **Vollständig vorhanden.** `uploadEquipmentPhoto` in `packages/domain/src/media-store.ts` schreibt `equipment_models.photo_path`; der Bucket `equipment-photos` steht in `0020_media_buckets.sql` mit 10 MiB und JPEG/PNG. Dass das Foto Pflicht ist, bleibt eine Regel der Oberfläche — die Spalte ist nullable, und das soll sie bleiben: Altmodelle tragen keines. |
| **Einstellparameter am Telefon** | Erweiterung. `createSettingDefinition`, `deleteSettingDefinition` und `settingDefinitionInputSchema` in `packages/domain/src/catalog.ts` bestehen samt Validierung für `number` und `enum` (dieselben Regeln wie die Constraints aus `0017`), `getStudioCatalog` liest sie mit. Es fehlt allein die mobile Form. |
| **Geräte, Übungen, Videos, Tags** | Vollständig vorhanden. |

**Die zweite Runde kostet keine Migration.** Beide neuen Posten hängen an Tabellen und Fachfunktionen, die seit M0 stehen.

---

## 6. Was entfällt

Das ist die eigentliche Nachricht dieses Dokuments — der Neubau schrumpft netto:

| Entfällt | War |
| --- | --- |
| **Druckbogen als PDF** | In `2026-09-01-scan-beitritt-design.md` §6 noch „der einzige echte Neubau im Portal" |
| `TagAnlegen.tsx` samt drei Aufrufstellen | Tag anlegen am Gerät, an der Modellseite, auf der Tags-Seite |
| ~~`TagZuweisen.tsx`~~ | **Nachgezogen: bleibt, umgebaut.** Das Dropdown entfällt — es hätte nichts mehr zu listen, weil Haldenzeilen per RLS unsichtbar sind. An seine Stelle tritt ein Feld „Token eintippen" auf `bind_tag_to_machine`: der Sucher ohne Kamera, und damit zugleich dessen Rückfallweg (§7) |
| `createTag` in `packages/domain/src/catalog.ts` | Erzeugt Token und Zeile in einem Schritt; die Zeile entsteht jetzt bei der Lieferung |
| Der Bildschirm „Gerade angelegt — nur jetzt sichtbar" | Die einmalige Anzeige des Klartext-Tokens |

`createTagToken`, `hashTagToken` und `isValidTagToken` bleiben unverändert — sie wandern auf die Betreiberseite.

~~**Der Rückbau gehört nicht in dieselbe Runde wie die Artboards.** Er folgt aus dieser Spec, ist aber ein eigener Plan mit eigener Testmatrix.~~

> **Nachgezogen: er ist kein eigener Plan mehr, sondern erzwungen.** Nach `0026` ist `token_hash` eine generierte Spalte und `token` für `authenticated` nicht schreibbar — `createTag` kann danach nicht mehr laufen, egal ob jemand es zurückbaut. Der Rückbau steht deshalb als Aufgabe 3 in `2026-09-01-tag-lieferung-design.md` §5 und §7, unmittelbar hinter der Migration; dazwischen ist das Repo nicht übersetzbar. Die Testmatrix stimmte: zehn Aufrufe in `domain-catalog.test.ts` und der E2E-Pfad in `e2e/trainerportal.spec.ts:119`, der den Token aus der Oberfläche abliest.

---

## 7. Offene Punkte

- ~~**Druckmaße des QR.** Modulgröße und Fehlerkorrekturstufe für den Scanabstand am Gerät sind weiter nicht festgelegt — aus der Vorgängerspec übernommen und **hochgestuft**: der QR ist jetzt der einzige Erfassungsweg des Trainers, nicht einer von zweien.~~ **Nachgezogen am 3. September: durch Handprüfung beantwortet.** Gedrucktes Prüfblatt, vier Größen von 15 bis 30 mm, Fehlerkorrektur M, Ruhezone 4 Module — schon die kleinste Probe mit 15 mm trifft. Die Modulgröße bindet die Beschaffung damit nicht mehr: der Aufkleber darf nach Haltbarkeit, Platz am Gerät und Preis gewählt werden, nicht nach dem Decoder. **Trotzdem nicht das Minimum bestellen.** Gemessen wurde an einem sauberen Ausdruck bei gutem Licht; in der Halle kommen Schweiß, Kratzer, Schräglage, schwaches Licht und ältere Telefone dazu. Reserve kostet nichts, solange Platz ist — was 15 mm beweist, ist die Freiheit der Wahl, nicht die Empfehlung.
- ~~**Kamerafreigabe in mobilem Safari** ist der einzige Ausfallpunkt ohne Rückfallweg.~~ **Nachgezogen: entschärft, bevor er entsteht.** Der umgebaute `TagZuweisen` (§6) ist ein Feld zum Eintippen des Tokens auf derselben Funktion — der Rückfallweg wird gebaut, bevor die Kamera überhaupt davorsteht. Offen bleibt nur, ob das Abtippen von 22 Zeichen vor einem Gerät zumutbar ist; das zeigt der erste echte Einrichtungsgang.
- **Lesbare Chargennummer neben dem QR?** Fürs Inventar praktisch, für den Ablauf unnötig. Kostet Druckfläche auf einem kleinen Aufkleber.
- **Leerer Vorrat mitten in der Halle.** Der Zustand ist gezeichnet, die Nachbestellung nicht — es gibt keinen Bestellweg im Portal, und ob es einen geben soll, ist eine Betreiberfrage.
- **Nummernvergabe.** `machines.label` ist heute frei. Der Entwurf schlägt die nächste freie Zahl vor; ob das Portal sie erzwingen soll, wenn am Gerät schon eine andere klebt, ist offen — der Entwurf sagt nein.
- **Trefferquote NFC gegen QR** (M0 Task 8) bleibt offen und ist für diesen Weg gegenstandslos: der Trainer nutzt ohnehin nur den QR. Für den Mitgliedsweg gilt die Vorgängerspec unverändert.
- **Wie viele Einstellparameter sind am Telefon zumutbar?** Der Entwurf zeigt drei. Bei acht wird Schritt 2 zur Fleißarbeit vor dem Gerät, und der Trainer überspringt ihn — womit die Sache schlechter dastünde als vorher. Ob es eine Obergrenze braucht oder die Praxis das regelt, zeigt der erste echte Gang.
- **Verdient ein übersprungener Schritt 2 eine eigene Zeile im Überblick?** Der Entwurf sagt ja und führt „1 Modell unvollständig · Brustpresse" — dieselbe Zeile, die schon das fehlende Foto trug. Ob Foto und Parameter dort zusammen oder getrennt stehen sollen, ist offen.
- **Ein Foto je Modell reicht nicht immer.** Zwei baugleiche Geräte an verschiedenen Wänden zeigen dasselbe Bild, und der Standort steht nur als Text daneben. Ob das reicht, um sie auseinanderzuhalten, weiß erst, wer davorsteht. Ein Foto je Gerät wurde erwogen und verworfen: es kostet eine Spalte auf `machines`, einen Umbau von `getTagContext` und `resolve_tag_fallback` — und hundert Aufnahmen statt zwanzig.
