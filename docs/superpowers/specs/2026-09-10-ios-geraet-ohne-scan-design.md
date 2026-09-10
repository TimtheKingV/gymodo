# iOS Member-App — Gerät ohne Scan wählen

**Stand:** 10. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Sub-Projekte 1–4 sind gebaut. `APIClient`, `CatalogStore`, `GeraetModel`, `ScanWege`, `GeraetRoute` und die Tab-Hülle stehen. Der aktive NFC-Scan (Commit `497ceb6`) ist drin.
**Zitierweise:** `§n` ohne Dokumentangabe verweist auf `2026-08-30-designsystem.md`. „Blatt n" verweist auf den Entwurf `docs/superpowers/design/geraet-ohne-scan/`.
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `2026-08-30-designsystem.md` (Aussehen, Bewegung).

---

## 1. Warum

Der Weg zum Gerät führt heute ausschließlich über den Aufkleber: NFC antippen oder QR scannen. Beide Wege setzen voraus, dass am Gerät ein **aktiver** Tag klebt. Das ist nicht immer so — ein Aufkleber fehlt, löst sich ab, oder ein Studio hat noch nicht jedes Gerät beklebt. Dann steht das Mitglied vor einem Gerät und die App bietet keinen Weg an.

Ein Mitglied, das einem Studio bereits zugeordnet ist, kennt die App ohnehin: `BootstrapResponse.machines` trägt jedes Gerät jedes Studios, dem das Mitglied angehört, mit Name, Nummer, Platz, Status, Übungen und Besuchszähler. Der dritte Weg ist deshalb kein neuer Datenweg, sondern ein Bildschirm auf Daten, die längst im Gerät liegen — er funktioniert offline genauso wie der Scan-Weg.

## 2. Scope

**Enthalten:**

- Dritter Weg auf `TrainingRootView`: „Aus der Liste wählen", gleichrangig neben QR und NFC (Blatt 01, Variante A)
- Neuer Screen `GeraeteAuswahlView` mit Suchfeld und zwei Gruppen (Blatt 02–04)
- Reines Modul `GeraeteAuswahl` mit Such-, Sortier- und Entdopplungsregeln, ohne UI prüfbar
- Serveranteil: `getMachineContext`, Route `GET /api/v1/machines/{machineId}/context`
- `GeraetModel.kontextLaden()` lädt künftig über Token **oder** machineId — damit hat der Listenweg Gerätefoto, Einweisungsvideo und Gewichtsvorschlag
- `GeraetErkanntView` unterscheidet „ERKANNT" von „AUSGEWÄHLT" (Blatt 05)

**Nicht enthalten:**

- Ein Bild eines echten Aufklebers auf Blatt 01. Dort steht vorerst eine gezeichnete Marke aus QR-Quadraten und NFC-Wellen; das Foto wird nachgeliefert und tauscht die Fläche, nicht das Layout.
- Gruppierung der Liste nach Bereich statt A–Z (Abschnitt 9, Punkt 1)
- Ein Melden-Weg für fehlende Geräte. Blatt 04 verweist auf das Studio, die App schickt nichts.
- Eine Prüfung von `machines.status` im Kontext-Endpoint (Abschnitt 9, Punkt 2)
- Selbsttätiges Zusammenfalten des dritten Knopfs (Abschnitt 9, Punkt 3)

## 3. Server-Anteil

### 3.1 Warum überhaupt Serverarbeit

`GeraetRoute.erkannt(machineId:token:)` nimmt den Token schon heute als optional, und `TrainingRootView.oeffne(_:)` pusht beim Zirkel-Tap bereits mit `token: nil`. Die Navigation trägt eine Auswahl aus der Liste also ohne Umbau.

Was nicht trägt, ist der Kontext. `GeraetModel.kontextLaden()` beginnt mit `guard let token else { return }`, und `getTagContext` ist der einzige Weg zu drei Dingen:

- **Gerätefoto** — `tag-context` liefert eine kurzlebige signierte `photoUrl`; der Bootstrap trägt nur den nackten `photoPath` in einen privaten Bucket.
- **Einweisungsvideo** — `exercises[].instructionVideoUrl`, ebenfalls signiert.
- **Gewichtsvorschlag** — `suggestion`, in derselben Anfrage berechnet und nach `progression_suggestions` geschrieben.

Übungen (`maschine.exercises`), Rastwerte und Einstellhinweise (`maschine.equipmentModel`) fallen schon heute auf den Prefetch zurück und sind unbetroffen.

Ohne Serverarbeit wäre der Listenweg dauerhaft zweiter Klasse — insbesondere fehlte das Foto, das die Auswahl ohne ein einziges Wort bestätigt. Deshalb wird die Lücke ganz geschlossen, nicht halb.

### 3.2 `getMachineContext` in `packages/domain/src/machine-context.ts`

Der Rumpf von `getTagContext` hängt nach dem Tag-Lookup an genau einer Größe: `machine.id`. Er zieht deshalb unverändert um.

```ts
export type MachineContext = { /* heutiger TagContext, Feld für Feld */ };

export async function getMachineContext(
  client: SupabaseClient,
  machineId: string,
): Promise<MachineContext>;
```

Enthält: `requireUserId`, die `machines`-Abfrage samt `equipment_models`, Einstellparameter, verknüpfte Übungen mit signierten Videos, das signierte Foto, die Vorauswahl aus `workout_sets`, Kalibrierung, Historie, Vorschlag und die `progression_suggestions`-Zeile.

`tag-context.ts` bleibt als Auflöser stehen und schrumpft auf rund vierzig Zeilen:

```ts
export async function getTagContext(client, token) {
  if (!isValidTagToken(token)) {
    throw new DomainError("validation_failed", "Ungueltiges Tokenformat.");
  }
  const { data: tag } = await client
    .from("machine_tags")
    .select("machine_id")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle();
  if (!tag?.machine_id) {
    throw new DomainError("not_found", "Dieser Code ist nicht aktiv.");
  }
  return getMachineContext(client, tag.machine_id);
}
```

`TagContext` bleibt als Typalias auf `MachineContext` exportiert. Kein vorhandener Import in `index.ts` oder in den Integrationstests bricht.

### 3.3 Autorisierung

`getBootstrap` hält im Kommentar fest: *„RLS beschränkt jede dieser Abfragen auf die Studios des Mitglieds."* Dieselbe Regel greift in `getMachineContext`: `.eq("id", machineId).maybeSingle()` liefert für ein Gerät aus einem fremden Studio bereits `null`.

Die Antwort darauf ist `not_found` — dieselbe neutrale Antwort wie bei einem unbekannten Token, ohne zwischen „gibt es nicht" und „gehört dir nicht" zu unterscheiden. Der Text lautet **„Dieses Gerät ist nicht verfügbar."**, nicht „Dieser Code ist nicht aktiv." — es gibt hier keinen Code.

Ein Integrationstest über ein Gerät aus einem fremden Studio hält diese Grenze fest. Er ist der eigentliche Sicherheitsbeweis dieses Sub-Projekts: der Token war ein öffentlicher Locator, den jeder scannen kann, der davorsteht; eine `machineId` ist erratbar.

### 3.4 Route

`apps/web/app/api/v1/machines/[machineId]/context/route.ts`, gebaut wie `tags/[token]/context/route.ts`: `bearerClientFrom`, `unauthorized` ohne Client, `fromDomainError` im Catch, `cache-control: private, no-store`.

Der Pfadschnitt spiegelt den bestehenden bewusst — `machines/{id}/context` neben `tags/{token}/context` — statt einen zweiten Parameter an die Tag-Route zu hängen. Eine Route namens „tag-context", deren halber Verkehr keinen Tag sieht, wäre ein Name, der lügt.

### 3.5 Was sich dadurch am Verhalten ändert

Jede Auswahl aus der Liste schreibt eine Zeile nach `progression_suggestions`, nicht mehr nur jeder Scan. Das ist gewollt — der Vorschlag wird berechnet, also gehört er protokolliert (M1 §8.4) — aber es verändert die Zusammensetzung dieser Tabelle und ist beim Lesen von Auswertungen zu wissen.

## 4. Der iOS-Datenweg

`APIClient` bekommt eine siebte Methode neben den sechs M1-Endpoints:

```swift
func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
    try await get("machines/\(machineId)/context")
}
```

Dasselbe DTO, weil der Server dieselbe Form liefert. Ein zweiter Typ mit identischen Feldern wäre eine Wahrheit an zwei Orten.

`GeraetLoading` wächst um dieselbe Methode — nicht `BootstrapLoading`. `GeraetModel` lädt über die schmale Fassade `GeraetLoading` (`Workout/GeraetLoading.swift`), und die ist zugleich der Ort, über den Tests einen Fake einsetzen.

`GeraetModel.kontextLaden()` verliert seinen Wächter:

```swift
func kontextLaden() async {
    let geladen: TagContextResponse? =
        if let token { try? await loader.tagContext(token: token) }
        else { try? await loader.machineContext(machineId: maschine.id) }
    guard let geladen else { return }
    kontextUebernehmen(geladen)
}
```

Ein Fehlschlag bleibt wie bisher kein Fehlerzustand: der Screen steht bereits aus dem Prefetch, es fehlen nur Foto, Video und Vorschlag. Offline ändert sich damit nichts gegenüber heute.

## 5. Das reine Modul

`apps/ios-member/FitnessMember/Workout/GeraeteAuswahl.swift`, neben `MachineResolver` — die beiden bilden ein Paar: der eine löst ein Gerät über den Token auf, der andere über die Suche.

```swift
enum GeraeteAuswahl {
    struct Zuletzt: Equatable {
        let performedAt: Date
        let gewichtKg: Double
    }

    struct Eintrag: Equatable, Identifiable {
        var id: String { machineId }
        let machineId: String
        /// equipmentModel.name — das Wort, das am Gerät steht.
        let name: String
        /// label · locationNote, dieselbe Fügung wie die Kopfzeile
        /// auf dem Geräte-Screen.
        let ortsangabe: String
        let zuletzt: Zuletzt?
        /// Gesetzt, wenn der Treffer NUR über eine Übung kam.
        let trefferUebung: String?
        /// status != "active"
        let gesperrt: Bool
        /// tokenHashes.isEmpty
        let nichtScannbar: Bool
    }

    struct Gruppen: Equatable {
        let zuletzt: [Eintrag]
        let alle: [Eintrag]
    }

    static func gruppen(
        bootstrap: BootstrapResponse,
        studioId: String?,
        suchtext: String
    ) -> Gruppen
}
```

### 5.1 Ohne Suchtext

Zwei Gruppen, beide nur aus Geräten des übergebenen Studios.

- **`zuletzt`** — Geräte mit `visitCount > 0`, absteigend nach dem jüngsten `lastSets.performedAt`, **höchstens drei**. Mehr, und die Gruppe verdrängt die Liste, die sie abkürzen soll.
- **`alle`** — alle übrigen, alphabetisch nach `name`, gesperrte ans Ende.

**Die Entdopplung sitzt hier, nicht im View:** was oben steht, steht unten nicht noch einmal. Auf Blatt 02 fehlt die Beinpresse deshalb sichtbar zwischen Beinbeuger und Beinstrecker. Ohne diese Regel an einem Ort baut sie jemand später andersherum.

### 5.2 Mit Suchtext

Eine einzige Liste (`zuletzt` leer). Gesucht wird per Teilstring über vier Felder: `name`, `label`, `locationNote` und die Namen der Übungen am Gerät. Verglichen wird über `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)`; ein nur aus Leerraum bestehender Suchtext gilt als leer.

Kein Fuzzy-Match. Bei der Größenordnung eines Studios trägt Teilstring, und Fuzzy liefert Treffer, die niemand erklären kann.

**Reihenfolge der Treffer** — diese Regel stand bisher nur im Bild und wird hier zum ersten Mal ausgesprochen. Blatt 03 zeigt bei „bein" die Beinpresse vor dem Beinbeuger, obwohl B vor P kommt. Die Ordnung ist:

1. Treffer in einem Feld des Geräts vor Treffern nur über eine Übung
2. innerhalb dessen: Geräte mit Historie vor Geräten ohne
3. innerhalb dessen: alphabetisch nach `name`

Gesperrte Geräte stehen auch hier am Ende.

`trefferUebung` wird **nur** gesetzt, wenn kein Feld des Geräts selbst trifft. Sonst bekäme bei „bein" auch die Beinpresse eine Übungszeile, und die Zeile verlöre ihren Zweck: zu erklären, warum ein Gerät in der Trefferliste steht, dessen Name nichts mit der Eingabe zu tun hat.

### 5.3 Warum ein `enum` und kein `@Observable`

Dasselbe Muster wie `KurseWochenInhalt`, `GeraetEinstiegRechner` und `MachineResolver`: reine Ableitung, ohne UI prüfbar. `GeraetModel` ist `@Observable`, weil es Kontext lädt, das Rad hält und Schreibvorgänge einreiht. Nichts davon trifft hier zu — es gibt kein Netz, keinen Lebenszyklus, und die Zahl der Geräte eines Studios filtert sich in Mikrosekunden. Eine Beobachtungsschicht wäre eine Schicht, die nichts kauft.

## 6. UI und Navigation

### 6.1 `ScanWege` wird dreiteilig

Das Bauteil heißt heute im Kommentar „Die zwei Wege zum Geraet, gleichwertig uebereinander (§11)". Es wird zu dreien, mit derselben Form: 60 pt hoch, `Radius.haupt`, Kontur in `Color.line`, keine Akzentfläche. Signatur: `ScanWege(beiQR:beiNFC:beiListe:)`.

Zwei Folgen, beide gewollt:

- `ScanWege` steht in **beiden** Zuständen von `TrainingRootView`. Der dritte Knopf erscheint damit auch im laufenden Training unter „NÄCHSTES GERÄT" — richtig, denn auch am zweiten Gerät kann der Aufkleber fehlen. Der laufende Screen wird dadurch 72 pt höher, und „Training beenden" rutscht weiter unter die Falz. Der Screen scrollt, es bricht nichts.
- Auf iPad, älteren iPhones und im Simulator bleibt NFC ausgeblendet (`NFCTagLeser.verfuegbar`). Dort stehen zwei Knöpfe: QR und Liste.

### 6.2 Route und Screen

`GeraetRoute` bekommt `case auswahl` — ein Push innerhalb des Training-Stacks, der die Tab-Leiste behält, wie `.erkannt` (§11).

`Screens/Geraet/GeraeteAuswahlView.swift`: Titel „GERÄT WÄHLEN", eine Zeile mit Geräteanzahl und Studioname, das Suchfeld, darunter die Gruppen.

Das Suchfeld ist ein eigenes `TextField` in der Kontur aus Blatt 02, **nicht** `.searchable`. Die Systemsuchleiste setzt sich unter den Navigationstitel und bricht damit den Entwurf; außerdem gehört das Feld hier in den Inhalt, weil es die Hauptaktion des Screens ist.

Ein Tap auf eine Zeile hängt `.erkannt(machineId:, token: nil)` an den Pfad. Gesperrte Zeilen sind nicht antippbar.

### 6.3 „Ausgewählt" statt „Erkannt"

`GeraetErkanntView` zeigt heute fest `Label("ERKANNT", systemImage: "wave.3.right")`. Künftig aus `modell.token == nil` abgeleitet, als Ableitung im Modell (`var einstiegsart`), nicht als zweite View: Listensymbol und das Wort „AUSGEWÄHLT".

Der Grund steht auf Blatt 05 und ist keine Kosmetik: nach einem Scan war das Telefon nachweislich am Gerät, nach einer Auswahl hat jemand etwas angetippt. Ein Wort, das eine Messung behauptet, wo keine stattfand, verstößt gegen die Produktgrenze aus §10. Das Gerätefoto — das mit Abschnitt 3 nun auch auf diesem Weg da ist — übernimmt die Bestätigung ohne Worte.

### 6.4 Mehrere Studios

Die Liste zeigt die Geräte eines Studios, vorbelegt mit `katalog.activeStudioId`. Nur wenn `bootstrap.studios.count > 1` **und** die Suche nichts gefunden hat, erscheint im leeren Zustand die Zeile „Auch in *anderes Studio* suchen" (Blatt 04).

Sie setzt `activeStudioId` **nicht** um, sondern nur einen `@State` dieses Screens. Sonst wechselte eine Suche stillschweigend das aktive Studio, und das Mitglied fände danach auf Home ein anderes Studio vor, als es verlassen hat.

### 6.5 Die Marke an der Zeile

Ein Gerät mit leeren `tokenHashes` trägt die Marke **„NICHT SCANNBAR"**, nicht „ohne Aufkleber". `getBootstrap` liest `machine_tags` mit `.eq("status", "active")` — leere `tokenHashes` heißen also „kein *aktiver* Tag". Ein abgeschalteter Aufkleber klebt physisch weiter am Gerät. Die Marke sagt deshalb, was die App weiß (Scannen führt hier zu nichts), und nicht, was am Gerät klebt.

Gesperrte Geräte (`status != "active"`) tragen die Marke „GESPERRT" in `Color.warn`, sind gedimmt und nicht antippbar. Sie auszublenden hieße, das Mitglied sucht am Gerät weiter, statt zu wissen, dass es gesperrt ist.

## 7. Fehler und Ränder

Es gibt fast keine Fehler: Liste und Suche rechnen auf dem Prefetch, ohne Netz, ohne Ladezustand.

- **Bootstrap noch nicht geladen** (erster Start ohne Empfang): der dritte Knopf erscheint nicht. Ein Knopf, der auf einen leeren Screen führt, ist schlechter als einer, der fehlt. Bedingung: `katalog.bootstrap != nil`.
- **Studio ohne Geräte:** leerer Zustand mit einem Satz, kein Fehlerbanner — es ist nichts kaputt.
- **Keine Treffer:** Blatt 04. Der Satz nennt den Grund, den Studios tatsächlich verursachen (Geräte heißen anderswo anders), schlägt Platz und Übung als Suchwege vor, und bietet „Stattdessen scannen" an.
- **Gerät verschwindet zwischen Auswahl und Push** (Bootstrap-Reload dazwischen): `modell(machineId:exerciseId:token:)` liefert bereits heute `nil`, das `navigationDestination` rendert nichts. Bestehendes Verhalten, unangetastet.
- **`machineContext` schlägt fehl:** kein Fehlerzustand, siehe Abschnitt 4.

## 8. Tests

**TypeScript**

- `tests/integration/domain-tag-context.test.ts` bleibt **unverändert** grün. Das ist der Beweis, dass die Extraktion nichts am Verhalten des Scan-Wegs geändert hat — die Datei wird nicht angefasst.
- `tests/integration/domain-machine-context.test.ts` (neu): dieselbe Antwort wie `getTagContext` für dasselbe Gerät; ein Gerät aus einem fremden Studio liefert `not_found`; eine `progression_suggestions`-Zeile entsteht.

**Swift**

- `GeraeteAuswahlTests.swift` (neu) hält die Regeln fest, die sonst niemand nachlesen kann: Entdopplung zwischen den Gruppen, Deckel bei drei, Sortierung nach jüngstem Satz, Gesperrte ans Ende, Suchreihenfolge aus 5.2, `trefferUebung` nur bei reinem Übungstreffer, Diakritika und Großschreibung, Geräte fremder Studios fehlen, leerer Suchtext ergibt zwei Gruppen und ein gesetzter eine.
- `GeraetModelTests`: der neue Zweig von `kontextLaden()` über einen Fake auf `GeraetLoading` — mit Token wird `tagContext` gerufen, ohne Token `machineContext`.

## 9. Offene Punkte

1. **Nach Bereich gruppieren statt A–Z.** In der Halle steht man irgendwo, nicht im Alphabet. Das setzt voraus, dass Studios `locationNote` pflegen; heute ist das Feld optional und Freitext. A–Z trägt immer und wird deshalb gebaut. Bereichsgruppen sind der bessere Zustand, sobald das Portal die Angabe verlangt.
2. **`machines.status` im Kontext-Endpoint.** `getTagContext` prüft heute nur `machine_tags.status`, nie `machines.status` — ein Aufkleber auf einem gesperrten Gerät führt also durch. `getMachineContext` bekommt diese Prüfung bewusst auch nicht, sonst wäre dasselbe Gerät über den einen Weg erreichbar und über den anderen nicht. Ob ein gesperrtes Gerät überhaupt Sätze annehmen soll, ist eine eigene Frage für **beide** Wege und gehört nicht in diesen Umbau.
3. **Bleibt der dritte Knopf immer stehen?** In einem Studio, in dem jedes Gerät einen aktiven Tag hat, steht er dauerhaft für einen Fall, der nie eintritt. Die App könnte die Geräte mit leeren `tokenHashes` zählen und ihn zur leisen Zeile aus Variante B (Blatt 07) zusammenfalten. Ab welchem Anteil, ist unbeantwortet — deshalb vorerst nicht gebaut.
4. **Zählt eine Auswahl als Besuch?** Sie zählt nicht, und das ist bereits so: `visitCount` kommt aus Sessions mit mindestens einem gesicherten Satz, nicht aus Taps. Der Direkteinstieg (`GeraetEinstiegRechner.einstieg`) springt also nicht wegen eines ungeprüften Taps an der Übungsauswahl vorbei. Hier ist nichts zu tun — festgehalten, damit es niemand „repariert".

## 10. Reihenfolge

Vier Schritte, so geschnitten, dass jeder für sich grün ist:

1. **Domain-Umbau** — `getMachineContext` extrahieren, `getTagContext` delegieren lassen, `index.ts` erweitern. Die App merkt nichts.
2. **Route, `APIClient`, `kontextLaden`** — der Listenweg bekommt Foto, Video und Vorschlag, bevor es einen Listenweg gibt.
3. **Reines Modul mit Tests** — ohne UI.
4. **View, Route, `ScanWege`, „AUSGEWÄHLT"** — der sichtbare Teil zuletzt.

## 11. Selbstprüfung

- **Platzhalter:** keine. Der einzige offene Inhalt ist das Aufkleberfoto auf Blatt 01, und der ist in Abschnitt 2 als nicht enthalten benannt.
- **Widersprüche:** Abschnitt 6.5 („NICHT SCANNBAR") und Abschnitt 9.2 (`machines.status`) betreffen zwei verschiedene Status-Felder — `machine_tags.status` und `machines.status`. Beide Stellen benennen, welches gemeint ist.
- **Zuschnitt:** ein Umsetzungsplan, vier Schritte, zwei Schichten. Keine Zerlegung nötig.
- **Mehrdeutigkeit:** Die Trefferreihenfolge (5.2) war die einzige Regel, die nur im Bild stand; sie ist jetzt ausgeschrieben. Die Entdopplung (5.1) desgleichen.
