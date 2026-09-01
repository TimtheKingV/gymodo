# Beitritt durch Scannen — Aushang, Geräte-Tags und mehrere Studios

**Stand:** 1. September 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-08-31-trainerportal-struktur-design.md` (Struktur und Beitritt), `2026-08-30-designsystem.md` (Tokens)
**Ändert:** Abschnitt 2 der Vorgängerspec — der Studio-Code bleibt, verliert aber den Rang des einzigen Weges
**Teilweise abgelöst von:** `2026-09-01-einrichtung-am-geraet-design.md` — §3 (Portal-Abschnitt *Aushang*) und §6 (Druckbogen) sind hinfällig; Tags kommen als Lieferung, das Portal erzeugt keine Tokens mehr. **§1, §2, §4 und §5 gelten unverändert**, einschließlich `tag_kind`, `join_studio_by_tag` und dem Selbstaustritt.
**Canvases:** Member-App `4f6035c6-7612-42ed-9791-cf0794713bdd` · Trainerportal `fa12ef14-ca77-4fcc-a034-886a38914984`

---

## Warum dieses Dokument existiert

Die Vorgängerspec lässt ein Mitglied über einen getippten Studio-Code beitreten. Das ist ein Zettel am Tresen, eine Handlung an der Theke und ein Bildschirm, auf dem jemand zwölf Zeichen abtippt, während er eigentlich trainieren wollte.

Im Studio hängen ohnehin Codes: an jedem Gerät klebt ein Tag, damit die App weiß, wovor man steht. **Diese Tags wissen bereits, zu welchem Studio sie gehören** — `machine_tags.studio_id` steht seit `0002` in der Tabelle. Der Beitritt ist damit kein Lookup mehr, den jemand von Hand auslöst, sondern ein Insert, den ein Scan auslöst, den es sowieso gibt.

Dieses Dokument legt fest, was ein Scan auslöst, wie ein Konto zu mehreren Studios gehört, und wie jemand ohne installierte App auf iOS trotzdem ankommt.

**Wofür es der Eingang ist.** Als Nächstes entsteht daraus ein Umsetzungsplan. Er zerfällt in drei sehr ungleiche Teile: Datenbank und Portal liegen in diesem Repo, die Artboards ebenfalls — **die native App nicht.** Sie entsteht auf dem Mac (M0-Plan) und bekommt aus diesem Dokument eine Anforderungsliste, keinen Code.

---

## Entscheidungen

Fünf, alle in dieser Runde getroffen:

1. **Ein Scan macht sofort zum Mitglied.** Keine Bestätigung durch das Studio, keine Rückfrage in der App. Der Token ist dafür sperrbar und neu erzeugbar.
2. **Der Bildschirm „Noch kein Studio" bleibt und dreht sich um.** Scannen wird die Hauptaktion, der getippte Studio-Code der zweite Weg.
3. **Ein Konto gehört zu mehreren Studios, die App zeigt genau eines.** Der Scan schaltet stillschweigend um; im Profil steht der Wechsler für Hände.
4. **Der Kaltstart auf iOS wird durch einen zweiten Scan gelöst**, nicht durch verzögerte Deep Links und nicht durch einen App Clip. Begründung in Abschnitt 5.
5. **Wer mit einem Tap beitritt, geht mit einem Tap.** Die Mitgliedschaft ist vom Mitglied selbst löschbar.

---

## 1. Datenmodell

### Eine Tag-Sorte mehr, keine zweite Tabelle

```sql
create type public.tag_kind as enum ('machine', 'studio');

alter table public.machine_tags
  add column kind public.tag_kind not null default 'machine';
```

`0008` legt heute fest: `check (status <> 'active' or machine_id is not null)` — **ein aktiver Tag muss an einem Gerät hängen.** Ein Aushang hat kein Gerät und muss aktiv sein. Die Regel fällt nicht ersatzlos, sonst verliert der Gerätefall seinen Schutz; sie differenziert nach Sorte:

```sql
alter table public.machine_tags drop constraint machine_tags_active_needs_machine;

alter table public.machine_tags
  add constraint machine_tags_machine_kind
    check (case kind
             when 'machine' then status <> 'active' or machine_id is not null
             when 'studio'  then machine_id is null
           end);
```

Der Tabellenname lügt danach ein wenig. Eine Umbenennung zöge sechs Migrationen, zwei Policies, zwei Indizes und `resolve_tag_fallback` hinter sich her; das ist der Genauigkeit des Namens nicht angemessen. Ein Kommentar über der Spalte trägt es.

### Ein Tokenraum, eine URL, ein Scanner

Aushang und Gerät liegen beide unter `/t/<token>`, im selben Format, unter demselben `unique (token_hash)`. Die App muss vor dem Auflösen nicht wissen, was sie gescannt hat.

Der Aufkleber am Gerät trägt beides: **QR gedruckt, NFC als NDEF-Datensatz mit derselben `https`-Adresse.** iOS liest das Tag im Hintergrund und öffnet denselben Universal Link. Es gibt keinen zweiten Codepfad für NFC.

### Der Beitritt ist eine Funktion, keine Policy

Ein Nicht-Mitglied darf `machine_tags` nicht lesen — `machine_tags_select` verlangt `is_studio_member`. Deshalb `SECURITY DEFINER`, nach dem Muster von `resolve_tag_fallback`:

```sql
create function public.join_studio_by_tag(p_token_hash text)
returns table (studio_id uuid, machine_id uuid, joined boolean)
```

Ausführungsrecht für `authenticated`, **nicht für `anon`**. Drei Regeln stehen im Funktionsrumpf, nicht im Aufruf:

- **Die Rolle ist fest verdrahtet auf `member`.** Damit gilt für den Scan wörtlich, was die Vorgängerspec über den Studio-Code sagt: er macht niemanden zum Trainer.
- **`on conflict (studio_id, user_id) do nothing`.** Ein Trainer, der ein Gerät im eigenen Studio scannt, darf dabei nicht auf `member` zurückfallen. Ein `upsert` wäre hier eine stille Rechteentwertung.
- **Unbekannt, gesperrt und nicht zugewiesen antworten gleich** — leeres Ergebnis. Die Canvas-Notiz `note-neutral` nennt das eine Sicherheitsanforderung; sie gilt für den Beitrittsweg genauso, sonst wird die Funktion zum Orakel, mit dem sich gültige Tokens finden lassen.

Der Beitritt bekommt damit **keine** `insert`-Policy auf `studio_memberships`. Die Vorgängerspec rechnet mit vier neuen Policies — Select für Staff, Insert für den Beitritt, Update fürs Hochstufen, Delete fürs Entfernen. **Die Insert-Policy entfällt ersatzlos**, weil der einzige Beitrittsweg durch die Funktion läuft; dafür kommt der Selbstaustritt unten hinzu. Die Zahl bleibt bei vier, aber es ist eine andere vierte, und die neue ist die harmlosere: sie erlaubt jemandem, sich selbst zu entfernen, statt sich selbst einzutragen.

### Austritt

```sql
create policy memberships_delete_own_membership on public.studio_memberships
  for delete to authenticated
  using (user_id = auth.uid() and role = 'member');
```

Die Einschränkung auf die Rolle `member` ist kein Schnörkel: sie hält die Regel, dass sich niemand selbst die letzte Inhaberrolle entzieht, ohne dafür zählen zu müssen. Trainer und Inhaber gehen weiter über *Leute → Mitarbeiter*.

### Das aktive Studio steht auf dem Gerät

Kein `profiles.active_studio_id`. Es ist eine Ansichtseinstellung eines Telefons, keine Tatsache über einen Menschen. Beim ersten Start nach dem Login gilt: genau eine Mitgliedschaft → die; mehrere → die zuletzt gescannte; keine → Zugang 03.

---

## 2. Der Ablauf

Vier Eingänge, ein Weg: Kamera-App auf den gedruckten QR, NFC im Vorbeigehen, der Scanner in Zugang 03, der Scanner in *Training → Gerät finden*. Alle vier enden bei `/t/<token>` und lösen denselben Aufruf aus.

| | Aushang-Tag | Geräte-Tag |
| --- | --- | --- |
| **nicht angemeldet** | Pending-Route halten → Registrieren oder Login → fortsetzen | dito |
| **kein Mitglied** | Beitritt, Home des Studios, Beitrittszeile | Beitritt, dann *Gerät erkannt* (App 03) |
| **Mitglied, aktives Studio** | Home | *Gerät erkannt* — läuft heute schon |
| **Mitglied, anderes Studio** | Studio wird aktiv, Wechselzeile | Studio wird aktiv, dann *Gerät erkannt* |
| **unbekannt, gesperrt, ohne Gerät** | „Dieser Code ist nicht aktiv." | dieselbe Antwort |
| **kein Netz** | Scan wird gehalten, nicht verworfen | dito |

**Die Pending-Route ist nicht neu.** Die Canvas-Notiz `hdr-einstieg` hält sie schon fest. Sie muss eines mehr können als heute: **die Registrierung überleben, nicht bloß den Login.** Damit trägt sie den Kaltstart aus Abschnitt 5 vollständig.

**Zwei Zeilen, keine Dialoge.** Beitritt und Studiowechsel passieren ohne Rückfrage — Rückfragen wären genau die Reibung, die dieses Dokument beseitigt. Sichtbar müssen sie trotzdem sein. Nach einem Beitritt einmalig auf Home: *„Du gehörst jetzt zu Nordstraße."* Nach einem Wechsel: *„Nordstraße ist jetzt aktiv."* Ohne die zweite Zeile ist eine plötzlich andere Kursliste ein Fehler und keine Folge.

---

## 3. Die Oberfläche

### Zugang 03 dreht sich um

Überschrift und Erklärung bleiben. Darunter zuerst die Kamera-Aktion, dann das Feld:

- Hauptaktion `Code im Studio scannen`, Akzentfläche, 64 px — die Stelle, an der heute *Studio beitreten* steht.
- Getrennt durch `sep`: die Zeile *„Kein Code zur Hand?"*, das Monospace-Feld `Studio-Code` und eine **Nebenaktion** `Beitreten`, Rahmen statt Fläche.

Das ist kein Geschmacksurteil. Das Designsystem lässt **genau eine Akzentfläche je Bildschirm** zu. Wenn der Scan der Hauptweg wird, muss der Tippweg sie abgeben — sonst behaupten zwei Flächen gleichzeitig, der Weg zu sein.

### Zugang 05 · Scanner (neu)

Der Sucher, den 03 öffnet: der vorhandene aus *Training → Gerät finden* (App 15) ohne Tab-Leiste, denn Zugang kennt keine. Er wird eigenständig gezeichnet, weil „das gleiche wie 15, nur anders" in einer Spec verlässlich falsch umgesetzt wird.

### Profil (App 24) verweist, Studios wird ein eigener Bildschirm

Profil bekommt **eine Zeile** in der Konto-Karte: *Studios · Kraftwerk Nord* mit Chevron. Der Bildschirm dahinter (Zugang 06) trägt die Liste: das aktive Studio oben mit Punkt in Akzentfarbe, die übrigen darunter, ein Tap schaltet um. Je Zeile eine destruktive Nebenaktion *Verlassen*.

**Ursprünglich sollte das ein Abschnitt auf Profil werden. Es passt dort nicht.** Profil trägt Konto-Karte, *Beim Training*, *Deine Daten*, Abmelden und Tab-Leiste; es bleiben rund 88 px, der Abschnitt kostet rund 184. Und selbst bei knappem Passen wäre ein Bildschirm auf 100 % Füllstand die falsche Antwort — Studionamen sind variabel lang. Eine Liste mit einer destruktiven Aktion je Zeile bekommt den Platz, den dieses Repo seinem eigenen Grundsatz nach vergibt: ein Formular je Bildschirm.

**Der Mehrstudio-Fall kostet damit genau eine Zeile auf Profil.** Bei genau einer Mitgliedschaft — dem Normalfall — steht dort der Studioname und dahinter eine Liste mit einem Eintrag.

### Home (22) und Home-leer (23)

Die Beitritts- und Wechselzeile: volle Breite unter dem Kopf, Akzentfarbe auf `well`, verschwindet beim nächsten Start.

### Web-Fallback 25 wird zum Studio-Trichter

`FallbackGeraet` trägt heute Gerät, Foto, Videos und die Installationsaufforderung. Es fehlt, was den Beitritt trägt: **der Studioname ganz oben** und der Satz *„gymodo laden, dann diesen Code hier noch einmal scannen."* Ohne diesen Satz ist der Kaltstart eine Sackgasse, in der die zweite Handlung erraten werden muss.

### Web-Fallback 27 · Aushang (neu)

Ein Aushang-Token zeigt kein Gerät, die Seite muss also etwas anderes zeigen: Studioname, was gymodo im Training tut, Installationsaufforderung. Ohne dieses Artboard fällt der Aushang-Scan ohne App auf eine Seite, die für ein Gerät gebaut ist und keines hat.

`FallbackInaktiv` (26) bleibt unverändert und deckt weiter unbekannt, gesperrt und nicht zugewiesen mit derselben Antwort ab.

### ~~Portal: `Tags` bekommt einen Abschnitt `Aushang`~~ — überholt

**Dieser Abschnitt ist von `2026-09-01-einrichtung-am-geraet-design.md` abgelöst.** Er stand hier als Aushang, den das Studio selbst anlegt und ausdruckt. Die neuere Spec entscheidet anders, und besser:

> **Tags kommen als Lieferung, das Studio erzeugt keine.** Im Portal entsteht kein Token mehr — auch nicht für den Aushang. Der Erzeugen-und-Drucken-Pfad verschwindet aus der Oberfläche und aus dem Code.

Der Aushang wird damit ein **geliefertes Schild**, wie der Gerätetag ein gelieferter Aufkleber ist. Die Tags-Seite zeigt Lieferungen und geklebte Tags — eine Auskunft, kein Formular.

**Was aus diesem Abschnitt überlebt, ist die Sortenunterscheidung selbst:** `kind ∈ machine | studio` aus §1 bleibt gültig und wird von der neueren Spec ausdrücklich übernommen. Nur der Weg, auf dem so eine Zeile entsteht, ist ein anderer geworden — Charge statt Knopfdruck.

Der Satz in *Einstellungen → Studio*, der den Studio-Code zum zweiten Weg erklärt, ist von der Ablösung **nicht** berührt und weiterhin offen.

Der Studio-Code in *Einstellungen* bleibt, wo er ist. Er ist jetzt der zweite Weg statt des einzigen.

**Mehrere Aushänge je Studio sind erlaubt** — Eingang, Umkleide, Kursraum. Das Schema kann es ohne Zusatz, und ein einzelner erzwungener Aushang wäre eine Regel ohne Grund.

### Bildschirmverzeichnis

| | Bildschirm | Canvas |
| --- | --- | --- |
| ~ | Zugang 03 — Noch kein Studio, Scan als Hauptweg | Member |
| + | Zugang 05 — Scanner | Member |
| + | Zugang 06 — Profil, Studios | Member |
| ~ | App 22 / 23 — Home, Beitritts- und Wechselzeile | Member |
| ~ | App 24 — Profil, Zeile *Studios* mit Chevron | Member |
| ~ | App 25 — Web-Fallback Gerät, Studioname und zweiter Scan | Member |
| + | App 27 — Web-Fallback Aushang | Member |
| — | ~~Tags — Abschnitt Aushang~~ | Portal, abgelöst |
| ~ | Einstellungen Studio — Studio-Code als zweiter Weg | Portal, offen |

**Drei neu, fünf geändert, keines gelöscht** — dazu ein Portal-Bildschirm, der zur neueren Spec gewandert ist, und ein Satz im Portal, der noch aussteht.

---

## 4. Sicherheit und Datenschutz

**Ein Aushang ist öffentlich, sobald ihn jemand fotografiert.** Das ist eine bewusst getragene Folge von Entscheidung 1, keine Lücke. Was ein Fremder damit erreicht, ist genau zu benennen:

| Was eine Mitgliedschaft öffnet | Bewertung |
| --- | --- |
| Studioname, Gerätekatalog, Modelle, Einweisungsvideos | Studioinhalt. Steht im Web-Fallback ohnehin öffentlich. |
| Kursplan und **Kursbuchung mit begrenzten Plätzen** | **Das ist der eigentliche Schaden.** Ein Fremder belegt einen Platz. |
| Trainingsdaten anderer Mitglieder | Nichts. Die Grenze zieht die Datenbank (Entscheidung 7 der Vorgängerspec). |

Der Hebel dagegen ist nicht Vorbeugung, sondern Sichtbarkeit und Rücknahme: ein beigetretenes Konto steht unter *Leute → Mitglieder*, ist dort entfernbar, und der Aushang-Token ist sperrbar. **Die Kursbuchung ist der Punkt, an dem die Entscheidung teuer werden kann** — wenn Kurse gebaut sind, gehört hierher eine erneute Prüfung.

**Der Ratepfad bleibt geschlossen.** `join_studio_by_tag` antwortet auf unbekannt, gesperrt und nicht zugewiesen identisch. Sie ist nur für `authenticated` freigegeben; wer raten will, braucht ein Konto.

**Der Beitritt ohne Einwilligungsklick ist vertretbar**, weil ihn eine Handlung des Mitglieds auslöst, das Ergebnis auf Home sichtbar wird und die Mitgliedschaft mit einem Tap wieder verschwindet. Die drei zusammen — Handlung, Sichtbarkeit, Rücknahme — tragen; jedes einzeln nicht.

---

## 5. Der Kaltstart auf iOS

Drei der vier Fälle sind unproblematisch: App da und Mitglied, App da und kein Mitglied, Android. Der vierte bricht die Kette — **App fehlt, iPhone.** Der Universal Link landet in Safari, weil keine App ihn beansprucht, und nach der Installation startet die App bei null. **Apple leitet nichts nach.**

| Weg | Entscheidung |
| --- | --- |
| **Zweiter Scan.** `/t/<token>` nennt Studio und Anleitung; nach Installation und Registrierung scannt das Mitglied denselben Aufkleber erneut. | **Gewählt.** Keine neue Infrastruktur, kein Drittanbieter, funktioniert ausnahmslos. Kostet drei Sekunden, während man ohnehin vor dem Gerät steht. |
| **Beitritt im Web vor der Installation.** `/t/<token>` bekommt Registrierung; die Mitgliedschaft hängt am Konto, die App findet sie vor. | **Benannter Nachfolger.** Löst zusätzlich den Fall „Link von zuhause". Braucht eine zweite Anmeldeoberfläche mit Passwort, Verifikationsmail und Zurücksetzen — und damit den ausstehenden SMTP-Versand. Eigener Bauabschnitt. Der zweite Scan wirft nichts davon weg. |
| **App Clip.** | **Verworfen.** Zweites Xcode-Target, eigene Provisionierung, eigenes Review, eigene Codes — für eine gesparte Sekunde. |

---

## 6. Was kein Backend hat

| Bereich | Stand |
| --- | --- |
| `tag_kind`, Constraint-Umbau | Neu. Eine Migration. |
| `join_studio_by_tag` | Neu. `SECURITY DEFINER`, plus Testmatrix: Trainer-Downgrade, Doppelscan, gesperrter Token, fremdes Studio. |
| `memberships_delete_own_membership` | Neu. Eine Policy. |
| ~~Aushang-Tag erzeugen und sperren im Portal~~ | **Entfällt.** Abgelöst von `2026-09-01-einrichtung-am-geraet-design.md`: Tags kommen als Lieferung, das Portal erzeugt keine Tokens mehr. |
| ~~Druckbogen beim Anlegen, mit QR~~ | **Entfällt mit demselben Beschluss.** Er stand hier als „der einzige echte Neubau im Portal" — der Aushang ist jetzt ein geliefertes Schild, es gibt nichts zu drucken. |
| `/t/<token>` mit Aushang-Zweig und Studioname | Erweiterung der bestehenden Seite. |
| Scanner in Zugang, Pending-Route über die Registrierung, aktives Studio lokal | **Nicht in diesem Repo.** Native App, eigener Plan auf dem Mac. |

---

## 7. Offene Punkte

- **NFC-Tags programmieren.** Das Portal kann keine NFC-Tags beschreiben, ein Browser auch nicht zuverlässig. Offen, ob vorprogrammierte Tags bestellt werden oder ein kleines Werkzeug entsteht. **Blockiert den NFC-Teil, nicht den QR-Teil** — QR trägt den Ablauf allein.
- **Druckmaße des QR.** Modulgröße und Fehlerkorrekturstufe für den Scanabstand am Gerät und am Aushang sind nicht festgelegt.
- **Trefferquote NFC gegen QR** bleibt offen (M0 Task 8, Canvas-Notiz `note-qr-pivot`). Diese Spec setzt beide gleichrangig; ein Ergebnis kostet Text, kein Redesign.
- **Ratenbegrenzung** auf `join_studio_by_tag` ist nicht festgelegt. Sie schützt nicht vor dem fotografierten Aushang, sondern vor massenhaftem Beitritt über viele Konten.
- **Weg B hängt am SMTP-Versand**, unverändert der Blocker aus der Vorgängerspec.
- **Kursbuchung durch Fremdbeitritt** — erneut prüfen, sobald Kurse gebaut sind (Abschnitt 4).
