# Einrichtung am Gerät — Tags als Lieferung, der Gang durch die Halle

**Stand:** 1. September 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-08-31-trainerportal-struktur-design.md` (Struktur), `2026-09-01-scan-beitritt-design.md` (Tokenraum, Aushang), `2026-08-30-designsystem.md` (Tokens)
**Ändert:** `2026-09-01-scan-beitritt-design.md` §3 und §6 — der Druckbogen entfällt, der Aushang wird ein geliefertes Schild. Und `2026-08-31-trainerportal-struktur-design.md` §5 bekommt eine benannte Ausnahme.
**Canvas:** Trainerportal `fa12ef14-ca77-4fcc-a034-886a38914984`, Seite *Einrichten am Gerät*

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

---

## 1. Der Tag als Erzeugnis

### Das Schema trägt es ohne Änderung

`0002_machine_tags.sql` und `0008_machine_tags_fk.sql` stehen seit M0 so, wie dieses Modell sie braucht:

```
machine_tags   studio_id not null, machine_id nullable, token_hash unique,
               status ∈ unassigned | active | revoked | replaced
```

Eine Lieferung ist damit schlicht: N Zeilen mit `status = 'unassigned'`. Der Scan setzt `machine_id` und `status = 'active'`. Die Check-Constraint `machine_tags_active_needs_machine` bewacht genau diesen Übergang. **Kein Umbau, keine neue Tabelle.**

Die einzige fehlende Spalte ist die **Charge**. Ohne sie kann das Portal „Lieferung vom 12. August · 100 Tags · 97 vorrätig" nicht zeigen, und ohne diese Zeile weiß ein Trainer nicht, ob die Packung neben ihm zum Studio gehört. Eine Migration, eine nullable Spalte.

### Der Hash bleibt, und er war nie das Umständliche

`packages/domain/src/tags.ts` sagt es selbst: *„Der Token ist ein oeffentlicher Locator, keine Authentisierung."* Der Token steht im Klartext auf einem Aufkleber in einer Turnhalle; er ist kein Geheimnis. Nur den SHA-256 zu speichern kostet trotzdem nichts und verhindert, dass ein Datenbankabzug eine fertige Liste funktionierender Adressen **aller** Studios ist. Das bleibt.

Der Druckbogen kam nicht vom Hash. Er kam allein daher, dass das Portal die Tokens selbst erzeugte und sie danach nie wieder zeigen konnte.

### Wer welchen Tag bekommt, entscheidet die Charge

Tags entstehen in Chargen: der Betreiber erzeugt N Tokens mit `createTagToken`, gibt die Liste an den Tag-Lieferanten und spielt die Hashes ein. Beim Versand wird eine **ganze Charge** einem Studio zugeordnet. Der Betreiber muss beim Kommissionieren nichts scannen — die Nummer steht auf der Packung.

Die Sorte kommt ebenfalls aus der Charge: Geräte-Tags sind On-Metal-Aufkleber, Aushänge sind Schilder. Zwei Erzeugnisse, zwei Chargen, `kind ∈ machine | studio` aus `2026-09-01-scan-beitritt-design.md` §1. **Im Portal gibt es dafür keinen Bildschirm.**

---

## 2. Der Ablauf

Fünf Schritte, je Gerät, vor dem Gerät:

| | Schritt | Was entsteht | Überspringbar |
| --- | --- | --- | --- |
| 1 | **Modell** | Wählen, oder knapp neu: Foto, Name, Hersteller, Gewichtsschritt, Spanne | nein |
| 2 | **Gerät** | `machines`-Zeile mit Nummer und Standort | nein |
| 3 | **Tag** | Ankleben, scannen, verbinden — ab hier ist das Gerät auffindbar | nein |
| 4 | **Übungen** | Aus dem Studio wählen oder neu anlegen, Reihenfolge zählt | ja, aber dann zeigt das Gerät nichts |
| 5 | **Video** | Je Übung höchstens 45 s, am Paar Modell × Übung | **ja** |

Davor steht die Lieferung, dahinter die Nacharbeit am Schreibtisch: Einstellparameter, Beschreibungen, fehlende Videos. **Die Grenze liegt bei „was macht das Gerät auffindbar".** Alles, was das tut, passiert vor dem Gerät; alles andere hat Zeit.

### Mehrere Übungen

`exercises` ist studioweit; `equipment_model_exercises` hängt eine Übung mit `sort_order` an ein Modell. Also:

- Schritt 4 zeigt eine **Auswahl über die vorhandenen Übungen des Studios**, kein leeres Namensfeld. Sonst steht „Rudern sitzend" fünfmal im Katalog, jedes Mal anders geschrieben.
- Die **Reihenfolge ist keine Kosmetik**: Übung 1 ist am Gerät die Vorauswahl des Mitglieds (Designsystem §8).
- Das **Einweisungsvideo hängt am Paar** aus Modell und Übung (`instruction_assets.equipment_model_exercise_id`), nicht an der Übung. Dieselbe Übung an zwei **Modellen** hat zwei Videos; zwei baugleiche Geräte teilen sich eines. Ein Kabelzug hat ein Foto und zwanzig Videos.

---

## 3. Die Oberfläche

### Die Seite dreht sich um

Die Canvas-Notiz `note-telefon` sagte bisher: die Aufnahme entsteht auf dem Trainerhandy, *alles andere bleibt Schreibtischarbeit*. Der zweite Teil war falsch — nicht für den Katalogeditor, aber für die Einrichtung. Ein Studio wird nicht am Schreibtisch bestückt. Der Trainer steht vor dem Gerät, hat den Tag in der Hand und weiß erst dort, welche Nummer draufsteht und wo es steht.

### Bildschirmverzeichnis

`+` neu, `~` zu ändern. Die Telefonbildschirme tragen keine eigene Nummer — die Zählung steht auf der Schrittleiste („Schritt 3 von 5 · Tag"), und zwei Zählungen nebeneinander wären eine zu viel.

| | Bildschirm | Breite |
| --- | --- | --- |
| + | Ablauf — der ganze Gang als Karte | 1440 |
| + | Einstieg — Bestand, Vorrat, „Gerät einrichten" | 390 |
| + | Modell wählen | 390 |
| + | Modell anlegen — knapp | 390 |
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
| + | Zustände am Telefon — acht Antwortkarten | 390 |
| ~ | Tags — Lieferungen statt Anlegen | 1440 |
| ~ | Modell — „Tag scannen" je Geräteinstanz | 1440 |
| ~ | Überblick — „Am Gerät scannen" statt „Tags anlegen" | 1440 |

**Fünfzehn neu, drei geändert, eines ersetzt.**

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
| **unbekannt / fremdes Studio / Charge nicht zugeordnet** | eine einzige Antwort für alle drei | „Neue Lieferung? Melde dich beim Betreiber." |
| **Kamera nicht freigegeben** | wo man es erlaubt, konkret | kein Rückfallweg |
| **kein Netz** | „gespeichert, wird gesendet" | weitergehen |

Die dritte Zeile ist Absicht und nicht Faulheit: dieselbe Regel, die `join_studio_by_tag` im Rumpf trägt (Vorgängerspec §1). **Anders als beim Mitgliedsweg darf hier der nächste Schritt danebenstehen** — der Trainer ist angemeldet, es gibt keinen Ratepfad zu schützen.

Der Zustand **Offline** gilt hier, obwohl §5 der Strukturspec ihn fürs Portal ausschließt („ein Konzept der Halle, nicht des Schreibtischs"). Dieser Weg *ist* die Halle. Die Formulierung bleibt die des Designsystems: „gespeichert, wird gesendet" — nie „fehlgeschlagen".

---

## 5. Was kein Backend hat

| Posten | Stand |
| --- | --- |
| **Chargen herstellen und ausliefern** | Neu, aber **ausserhalb des Portals**: Tokens mit `createTagToken` erzeugen, die Liste an den Tag-Lieferanten geben, die Hashes chargenweise einspielen, beim Versand die Charge einem Studio zuordnen. Ein Betreiberskript wie beim Studio-Onboarding, kein Bildschirm. |
| **Chargenspalte** | Eine Migration, eine nullable Spalte auf `machine_tags`. |
| **Sucher im Portal** | **Der einzige echte Neubau, der bleibt.** Safari kennt `BarcodeDetector` nicht, also `getUserMedia` plus ein Decoder im Browser. |
| **Tag binden per Scan** | Erweiterung. Die Update-Policy auf `machine_tags` besteht (Plan `2026-08-31-trainerportal-medien`); es fehlt der Weg über den Token-Hash statt über die Tag-ID. |
| **Modell am Telefon anlegen** | Erweiterung. `equipment_models` und die Server Action bestehen; es fehlt die knappe mobile Form. |
| **Geräte, Übungen, Videos, Tags** | Vollständig vorhanden. |

---

## 6. Was entfällt

Das ist die eigentliche Nachricht dieses Dokuments — der Neubau schrumpft netto:

| Entfällt | War |
| --- | --- |
| **Druckbogen als PDF** | In `2026-09-01-scan-beitritt-design.md` §6 noch „der einzige echte Neubau im Portal" |
| `TagAnlegen.tsx` samt drei Aufrufstellen | Tag anlegen am Gerät, an der Modellseite, auf der Tags-Seite |
| `TagZuweisen.tsx` | Das Dropdown „Gerät wählen …" — ersetzt durch den Scan vor dem Gerät |
| `createTag` in `packages/domain/src/catalog.ts` | Erzeugt Token und Zeile in einem Schritt; die Zeile entsteht jetzt bei der Lieferung |
| Der Bildschirm „Gerade angelegt — nur jetzt sichtbar" | Die einmalige Anzeige des Klartext-Tokens |

`createTagToken`, `hashTagToken` und `isValidTagToken` bleiben unverändert — sie wandern auf die Betreiberseite.

**Der Rückbau gehört nicht in dieselbe Runde wie die Artboards.** Er folgt aus dieser Spec, ist aber ein eigener Plan mit eigener Testmatrix: `createTag` hat Tests, und die Tags-Seite hat einen E2E-Pfad.

---

## 7. Offene Punkte

- **Druckmaße des QR.** Modulgröße und Fehlerkorrekturstufe für den Scanabstand am Gerät sind weiter nicht festgelegt — aus der Vorgängerspec übernommen und **hochgestuft**: der QR ist jetzt der einzige Erfassungsweg des Trainers, nicht einer von zweien.
- **Kamerafreigabe in mobilem Safari** ist der einzige Ausfallpunkt ohne Rückfallweg. Ob das reicht, zeigt der erste echte Einrichtungsgang.
- **Lesbare Chargennummer neben dem QR?** Fürs Inventar praktisch, für den Ablauf unnötig. Kostet Druckfläche auf einem kleinen Aufkleber.
- **Leerer Vorrat mitten in der Halle.** Der Zustand ist gezeichnet, die Nachbestellung nicht — es gibt keinen Bestellweg im Portal, und ob es einen geben soll, ist eine Betreiberfrage.
- **Nummernvergabe.** `machines.label` ist heute frei. Der Entwurf schlägt die nächste freie Zahl vor; ob das Portal sie erzwingen soll, wenn am Gerät schon eine andere klebt, ist offen — der Entwurf sagt nein.
- **Trefferquote NFC gegen QR** (M0 Task 8) bleibt offen und ist für diesen Weg gegenstandslos: der Trainer nutzt ohnehin nur den QR. Für den Mitgliedsweg gilt die Vorgängerspec unverändert.
