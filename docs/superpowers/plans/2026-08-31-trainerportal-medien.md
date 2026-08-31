# Trainerportal und Medien-Upload — Implementierungsplan

**Stand:** 31. August 2026
**Status:** **umgesetzt.** Migrationen 0016–0021, Domain-Schicht, Trainerportal
und Web-Fallback. 342 Integrationstests, 39 Unit-Tests, 8 E2E-Tests, Typecheck
und Build grün — nachgeprüft gegen eine frisch zurückgesetzte Datenbank.
**Spec:** `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md`, Abschnitte 6.8 und 8.2
**Design:** `docs/superpowers/specs/2026-08-30-designsystem.md` (Tokens; das Trainerportal hat noch keine eigene Gestaltung)

---

## Warum dieser Plan jetzt kommt

Die Member-App ist fachlich vollständig vorbereitet: Datenmodell, RLS und alle sechs Endpoints aus Spec 6.3 stehen und sind getestet. Was fehlt, ist **Inhalt**. Ein Studio kann seinen Gerätekatalog derzeit nur direkt in der Datenbank pflegen, und es gibt kein einziges Foto und kein einziges Einweisungsvideo.

Konkret heißt das: Der Geräte-Screen aus der Design-Canvas (Artboard 03) zeigt ohne `equipment_models.photo_path` einen leeren Platzhalter, und `GET /api/v1/tags/{token}/context` liefert statt signierter Medien-URLs bislang nur Storage-Pfade.

Das ist zugleich das Exit-Kriterium von M2: *„Ein Studio kann ohne Entwicklerhilfe eingerichtet werden."*

---

## Was bereits steht

| Baustein | Zustand |
| --- | --- |
| Mandantenschema, Gerätekatalog, RLS | 15 Migrationen, vollständig getestet |
| Trainingsdaten (Sessions, Sätze, Kalibrierungen, Vorschläge) | 0012–0015, Positiv-/Negativ-/Cross-Tenant-Test je Policy |
| Progressionsregel | `packages/domain/src/progression.ts`, deterministisch, 18 Tests |
| Alle sechs Endpoints unter `/api/v1` | Domain-Schicht plus dünne Route-Adapter |
| Web-Fallback `/t/<token>` | funktioniert, zeigt aber noch keine Einweisungsinhalte |
| Design-Canvas | 27 Artboards für die Member-App; **Trainerportal nicht gestaltet** |

Testlage zum Planbeginn: 237 Integrationstests, 38 Unit-Tests, Typecheck grün.

---

## Umfang

### 1. Gerätekatalog pflegen (Web, Server Actions)

Nach Spec 8.2, in dieser Reihenfolge:

1. Gerätemodell anlegen: Name, Hersteller, Foto, Gewichtsschritte, Min/Max
2. Einstellparameter definieren (Sitz, Lehne, Startwinkel …)
3. Übungen anlegen, dem Modell zuordnen, Reihenfolge festlegen
4. Je Übung optional ein Einweisungsvideo hochladen
5. Geräteinstanzen anlegen und Tags zuweisen

**Kein HTTP, keine Endpoints.** Das Web ruft die Domain-Schicht direkt über Server Actions auf (Spec 6.1) — Trainerfunktionen brauchen keine REST-Vertragsfläche, solange sie nur im Web laufen.

**Der nutzergebundene Client ist Pflicht, nie der Service-Role-Schlüssel.** Die Studio-Konsistenzgarantie lebt in den Policies, nicht im Schema; mit Service-Role fiele sie ersatzlos weg.

### 2. Tag-Zuweisung — schließt offenen Punkt 2

`machine_tags` hat bis heute **nur eine Select-Policy**. Tags lassen sich weder anlegen noch zuweisen noch sperren, ohne direkt in die Datenbank zu greifen.

Zu ergänzen: Insert- und Update-Policies für `trainer`/`owner`, mit derselben `exists (… studio check …)`-Konstruktion wie in `0007_machines.sql` — **äußere Spaltenreferenzen qualifiziert**, sonst löst PostgreSQL sie gegen die innere Tabelle auf und die Prüfung läuft leer.

Zu beachten: Ein Tag kann nur in derselben Anweisung `active` werden, in der er ein Gerät bekommt (Check-Constraint aus `0008`). Ein zweistufiges „erst anlegen, dann zuweisen" scheitert, wenn Schritt 1 nicht `unassigned` verwendet.

### 3. Medien-Upload

Formatgrenzen aus Spec 6.8, serverseitig geprüft:

- maximal 45 Sekunden, 720p, harte Größenobergrenze
- **kein Transcoding** — iPhone nimmt HEVC auf, AVPlayer spielt das direkt ab
- private Buckets, kurzlebige signierte URLs
- MIME- und Größenprüfung serverseitig anhand des Inhalts, EXIF-Entfernung bei Bildern
- Upload braucht Fortschrittsanzeige und Wiederaufnahme nach Abbruch (Studio-WLAN)

Storage-Buckets existieren noch nicht und sind in `supabase/config.toml` anzulegen.

Danach `getTagContext` umstellen: statt `instructionVideoPath` und `photoPath` signierte URLs liefern. **Die Feldnamen ändern sich damit** — die Stelle ist in `packages/domain/src/tag-context.ts` markiert.

### 4. Web-Fallback ausbauen

`resolve_tag_fallback` und `/t/<token>` um Gerätename, Foto und Einweisungsvideo erweitern (Spec 6.4). Erst jetzt sinnvoll, weil es vorher keine Inhalte gab. Weiterhin **ohne persönliche Daten** und mit identischer Antwort für unbekannt, ungültig und gesperrt.

---

## Mitgeschleppte Schulden, hier zu erledigen

Aus dem Gerätekatalog-Plan übernommen:

- **`equipment_setting_definitions.kind = 'enum'` ist unbenutzbar** — es gibt keine Spalte für die erlaubten Werte. Muss vor dem Einstellparameter-Editor ergänzt werden.
- **`instruction_assets` braucht `unique (equipment_model_exercise_id, storage_path)`** vor dem Upload-Ablauf.
- **Löschen einer Übung kaskadiert die Einweisungsvideos weg.** Vor dem Editor entscheiden, ob das so bleiben soll.
- **Es gibt keinen Löschpfad für ein Gerät, das je einen Tag getragen hat.** Die Oberfläche muss „stilllegen" anbieten, nicht „löschen" — `machines.status = 'inactive'`.

---

## Offener Punkt 3: OTP-Mailversand — **blockiert, nicht Teil dieses Plans**

Der Login erwartet einen sechsstelligen Code; Supabase verschickt auf dem Free Tier den Standard-Magic-Link, weil Custom-Templates dort nicht erlaubt sind. **Auf der echten Domain kann sich damit kein echter Nutzer anmelden.**

Unkritisch, solange nur synthetische Daten und Entwicklerkonten existieren (Spec Abschnitt 9) — **und ein harter Blocker vor dem ersten Betreibertermin.**

Lösung: Custom-SMTP (Resend, Postmark) oder Supabase Pro. Das ist eine Konto- und Kostenentscheidung, keine Codeaufgabe, und liegt beim Nutzer.

---

## Weitere offene Punkte

- **Apple Team ID und Bundle ID** stehen in Vercel auf Platzhaltern (`ABCDE12345` / `de.fitretro.member`). Vor jedem produktiven TestFlight-Build durch echte Werte zu ersetzen.
- **Eigene Domain** ist bewusst nicht gekauft; `gymodo-web.vercel.app` dient als Universal-Link-Host.
- **M0 Task 8** — der physische Trefferquoten-Test der NFC-Tags — ist nicht gelaufen. Er entscheidet NFC-first gegen QR-first und braucht den Mac.
- **Das Trainerportal hat keine Gestaltung.** Es ist Desktop/Tablet, hat Formulare, Upload-Fortschritt und Tabellen und teilt mit der Member-App nur die Tokens aus dem Designsystem. Eigene Designrunde nötig, bevor Oberfläche entsteht.

---

## Was bei der Umsetzung entschieden wurde

Vier Punkte, die der Plan offen ließ und die im Code jetzt festgelegt sind:

- **Löschkette (`instruction_assets`).** Vom Nutzer entschieden: `on delete
  restrict` statt Kaskade (0019). Wer eine Übung entfernen will, löscht zuerst
  das Video — dieselbe Haltung wie bei `machines`/`machine_tags` in 0008. Die
  Garantie liegt im Schema, nicht im Editor.
- **Gestaltung des Portals.** Vom Nutzer entschieden: dunkel wie die Member-App,
  aber mit zwei zusätzlichen Flächenstufen und dichter Typoskala; zweispaltig
  statt geführter Abfolge; Desktop zuerst mit genau einem Pfad, der auf dem
  Telefon trägt (dem Videoupload). Tragendes Element ist **Erreichbarkeit**, kein
  Vollständigkeitsgrad — ein Balken auf dem Weg zu 100 % wäre eine Aufforderung,
  die Spec 6.8 ausdrücklich nicht stellt.
- **Ein gesperrter Tag wird nicht wieder vergeben.** Er gilt als kompromittiert
  oder klebt physisch nicht mehr am Gerät.
- **Anonymer Medienzugriff im Fallback.** Die Buckets bleiben privat, die URLs
  kurzlebig. Freigegeben ist genau das, worauf gerade ein aktiver Tag an einem
  Gerät in Betrieb zeigt (`is_media_published`, 0021). Sperrt man den Tag oder
  legt das Gerät still, ist das Video im selben Moment anonym nicht mehr lesbar.
  Ein öffentlicher Bucket könnte das nicht zurücknehmen.

Zwei Abweichungen vom Planwortlaut, beide bewusst:

- **`bootstrap` liefert weiterhin Pfade, keine signierten URLs.** Der Plan nennt
  nur `getTagContext`, und das ist auch richtig: `bootstrap` ist ein Prefetch beim
  App-Start, und eine 15 Minuten gültige URL gehört nicht in einen Vorrat, der
  Stunden hält. Die App signiert beim Öffnen des Geräte-Screens.
- **`tus-js-client` ist als Abhängigkeit dazugekommen.** Fortschritt *und*
  Wiederaufnahme verlangen das TUS-Protokoll. Es selbst nachzubauen, ohne es in
  derselben Sitzung im Browser prüfen zu können, wäre das größere Risiko gewesen.

## Verifikation

1. `pnpm typecheck`, `pnpm test`, `pnpm test:integration` grün.
2. Je neuer Policy ein Positiv-, Negativ- und Cross-Tenant-Test — nicht verhandelbar (Spec Abschnitt 10).
3. Nebenläufigkeit beim Tag: derselbe Token zweimal vergeben schlägt fehl (`token_hash` ist eindeutig).
4. Ein Upload über der Formatgrenze wird serverseitig abgewiesen, nicht nur im Browser.
5. **Ende-zu-Ende von Hand:** ein Studio komplett über die Oberfläche einrichten — Modell, Parameter, Übungen, Video, Geräteinstanz, Tag — und danach `GET /api/v1/tags/{token}/context` aufrufen. Der Kontext muss Foto und Video als signierte URLs liefern.
6. Ein Gerät ohne Video bleibt vollständig nutzbar. Vollständigkeit wird nie erzwungen (Spec 6.8) — ein Alles-oder-nichts-Setup stellt kein Studio fertig.

**Stand der Verifikation:** 1 bis 4 und 6 sind grün. Punkt 5 ist als E2E-Test
automatisiert (`e2e/trainerportal.spec.ts`): Anmelden, Modell, Foto, Parameter,
Übung, Gerät, Tag — und danach `GET /api/v1/tags/{token}/context`, der das Foto
als signierte URL liefert. **Was dieser Test nicht abdeckt, ist der
Videoupload selbst:** er läuft per TUS aus dem Browser und ist nur in der
Domain-Schicht geprüft (`tests/integration/domain-media.test.ts` deckt
Vorbereiten, Inhaltsprüfung, Abweisung und Wegräumen ab). **Der Weg vom
Trainerhandy durch mobiles Safari bis in den Bucket ist noch nie an einem echten
Gerät gelaufen** — das gehört vor den ersten Betreibertermin, zusammen mit
M0 Task 8.
