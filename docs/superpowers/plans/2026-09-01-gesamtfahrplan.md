# Gesamtfahrplan — Stand, Lücken und Reihenfolge

**Stand:** 2. September 2026 *(fortgeschrieben; Erstfassung 1. September)*
**Status:** Bestandsaufnahme. **Kein ausführbarer Task-Plan** — dieses Dokument ordnet die vorhandenen Pläne, es ersetzt keinen.
**Bezugsstand:**

| | Commit | Inhalt |
| --- | --- | --- |
| `master` | `1ac4c4d` | alles zusammengeführt: beide Entwurfsstränge und der gesamte Code der Sessions vom 1./2. September |
| `designplan` | `7c1f18c` | in `master` aufgegangen |
| `design-geräteeinrichtung` | `13d065b` | in `master` aufgegangen |
| `worktree/brave-forest-c9d8` | `2b2be9c` | Tag-Lieferung, in `master` aufgegangen |
| `worktree/calm-forest-3c59` | `3452a84` | Studio-Einstellungen, Datenschutzgrenze, Überblick: `0032`–`0034`, Fachschicht, Reiter Studio/Konto, E2E-Gang — **noch nicht gemerged** |

> **Was sich gegenüber der Erstfassung geändert hat, in einem Satz:** Sie beschrieb einen Stand, an dem die entworfenen Baustellen *zu null* gebaut waren — inzwischen stehen Phase 1 und Phase 2 ganz. Die Abschnitte 1 bis 5 sind entsprechend fortgeschrieben; die Betriebsbefunde aus 4a–4c bleiben als Lehre stehen, auch wo ihr Anlass erledigt ist.

---

## 0. Wie dieses Dokument zu lesen ist

Es beantwortet drei Fragen, die sich nach fünf Entwurfsrunden nicht mehr aus einem einzelnen Dokument beantworten ließen: *Was steht? Was fehlt? In welcher Reihenfolge?*

Es ist bewusst kurz und verweist. Die Wahrheit über einen Bauabschnitt steht immer in seinem eigenen Plan, nie hier.

---

## 1. Der Stand in einem Satz

**Der Abstand zwischen Entwurf und Code, den die Erstfassung als Quelle aller Lücken benannte, ist für die Tag-Kette und ganz Phase 2 geschlossen.**

Die Erstfassung hielt fest: `git diff master designplan -- . ':(exclude)docs'` war **leer** — 29 Commits, keine Zeile Code, auf Platte endete es bei `0021_fallback_inhalte.sql`. Zwei Sessions später liegen **zehn weitere Migrationen** (`0022`–`0031`), die Fachschicht dazu, fünf neue Portalseiten und zehn neue Testdateien. Was in Abschnitt 3 als *„entworfen, aber nicht gebaut"* stand, ist zur Hälfte abgeräumt.

Das Ungleichgewicht aus der Erstfassung bleibt trotzdem bestehen, nur verschoben: **das Portal hat jetzt sein Backend fast beisammen und keine Gestaltung; die Member-App hat ihr Backend und keine Zeile Code.**

---

## 2. Was gebaut ist und läuft

| Bereich | Stand |
| --- | --- |
| Monorepo, CI, Vercel (`gymodo-web.vercel.app`), AASA-Route | ✅ |
| Migrationen `0001`–`0031`, RLS mit Positiv-, Negativ- und Cross-Tenant-Test je Policy | ✅ |
| Gerätekatalog — `equipment_models`, `equipment_setting_definitions`, `exercises`, `instruction_assets`, `machines`, `machine_tags` | ✅ |
| Trainingsdaten — `workout_sessions`, `workout_sets`, `member_machine_calibrations`, `progression_suggestions` | ✅ |
| Fachschicht `@fitretro/domain`, inkl. deterministischer Progressionsregel | ✅ |
| Sechs Endpoints unter `/api/v1` (Spec 6.3) + Web-Fallback `/t/<token>` | ✅ |
| **Tag-Kette** — zweite Tag-Sorte, Beitritt durch Scannen, Selbstaustritt, Klartext-Tokenraum, Chargen/Lieferungen/Halde, `inspect_tag`/`bind_tag_to_machine`, Betreiberwerkzeug `pnpm tags` | ✅ neu |
| **Auth** — Passwort statt OTP, Registrierung mit Bestätigungsmail, Passwort vergessen und zurücksetzen, eigene Mail-Templates | ✅ neu |
| **Leute** — Beitrittscode, Mitgliederliste mit E-Mail, Rollen hoch- und herabstufen, Entfernen, Kein-Studio-Zustand | ✅ neu |
| Trainerportal: Geräte, Modelle, Tags, Medien-Upload, Leute | ✅ funktional, **ungestaltet** |
| Betriebswerkzeug: `pnpm smoke:web`, `pnpm smoke:migrations` | ✅ neu, siehe 4a/4c |
| **Studio-Einstellungen und Datenschutzgrenze** — Stornofrist, Speicherrecht mit Spaltengrenze, vier Policies ohne Staff-Klausel, `studio_overview` | ✅ neu |
| Testlage: **40** Integrationsdateien, **6** E2E-Dateien (vor diesem Zweig 36 / 5) | ✅ grün |

**Der Kassensturz aus `2026-08-31-trainerportal-struktur-design.md` §7 ist überholt.** Er nannte den Gerätekatalog als einzigen vollständig tragenden Bereich; das gilt nicht mehr. Die Tag-Kette trägt vom Herstellungslos bis zum Scan vor dem Gerät, und von den vier dort als „am weitesten offen" bezeichneten Punkten sind jetzt alle vier zu (Leute, Auth, Studio-Einstellungen, Datenschutzgrenze).

---

## 3. Was entworfen, aber nicht gebaut ist

73 Artboards (34 Member, 39 Portal) und fünf Specs stehen. Dahinter:

| Baustelle | Migrationen | Umsetzungsplan | Gebaut |
| --- | --- | --- | --- |
| ~~**Beitritt durch Scannen**~~ — `tag_kind`, `join_studio_by_tag`, Selbstaustritt, Fallback-Erweiterung | `0022`–`0025` | ✅ `2026-09-01-scan-beitritt-datenbank.md`, 5 Aufgaben | ✅ **2. September** |
| ~~**Tags als Lieferung**~~ — Klartext-Tokenraum, Chargen/Lieferungen/Halde, `inspect_tag`/`bind_tag_to_machine`, Betreiberwerkzeug | `0026`–**`0029`** | ✅ `2026-09-01-tag-lieferung.md`, 8 Aufgaben | ✅ **2. September** |
| ~~**Auth-Umstellung**~~ — OTP → Passwort, Registrierung, Studio-Beitritt | — | ❌ ohne Plan gebaut | ✅ **2. September** |
| ~~**Leute**~~ — Mitglieder und Mitarbeiter | `0030`–`0031` | ❌ ohne Plan gebaut | ✅ **2. September** |
| **Sucher im Portal** — `getUserMedia` + Decoder | — | ❌ | ❌ |
| **Einrichtung am Gerät** — 16 `Telefon*`-Artboards, der Gang durch die Halle | — | ❌ Spec steht, Plan fehlt | ❌ |
| ~~**Studio-Einstellungen, Datenschutzgrenze, Überblick**~~ — Stornofrist, Speicherrecht mit Spaltengrenze, vier Policies ohne Staff-Klausel, `studio_overview` | `0032`–`0034` | ✅ `2026-09-02-studio-einstellungen-datenschutzgrenze.md`, 9 Aufgaben | ✅ **2. September** |
| **Kurse** — drei Tabellen, Platzvergabe unter Nebenläufigkeit | — | ❌ nur Vorabnotiz (84 Zeilen) | ❌ |
| **Portal-Frontend nach den 39 Artboards** | — | ❌ | ❌ |
| **iOS Member-App** | — | ❌ | ❌ `apps/` enthält nur `web` |

### Was von den vier „am weitesten offenen" übrig ist

Die Erstfassung nannte vier. Alle vier sind zu:

- ~~**Leute:**~~ `memberships_select_own` erlaubte genau die *eigene* Zeile — ein Trainer konnte seine Mitgliederliste nicht einmal lesen. `0031` legt die vier Policies nach (`memberships_select_staff`, `_update_staff`, `_delete_staff`, dazu `list_studio_members` für die E-Mail-Adresse, die außerhalb der `public`-Policies liegt). Die Inhaberzeile ist über alle drei Pfade unerreichbar — die Regel *„niemand entzieht sich die letzte Inhaberrolle"* ist damit von der Policy erzwungen, nicht von einer Zählfunktion.
- ~~**Auth:**~~ `signInWithPassword` steht, dazu Registrierung, Bestätigung, Passwort vergessen und zurücksetzen. **Neuer Befund dazu:** `auth_leaked_password_protection` ist im Projekt **aus**. Solange nur OTP lief, war die Einstellung gegenstandslos; mit Passwörtern ist sie es nicht mehr. Ein Haken im Dashboard (Authentication → Policies), kein Code — aber er gehört gesetzt, bevor der erste Betreiber sich anmeldet.
- ~~**Studio-Einstellungen:**~~ `studios` hatte `studios_select` und keine Spalte für die Stornofrist — Speichern war nicht möglich. `0032` legt `cancellation_deadline_hours` an (Vorgabe 2 Stunden, Bereich 0–168) und zieht das Spaltenrecht auf `join_code` aus `authenticated` ab; der Reiter *Studio* unter `/einstellungen` speichert Name, Zeitzone und Frist.
- ~~**Datenschutzgrenze:**~~ `0033` nimmt vier Policies (`workout_sessions`, `workout_sets`, `member_machine_calibrations`, `progression_suggestions`) die Staff-Klausel — Personal kommt an kein einzelnes Trainingsdatum eines Mitglieds mehr heran. `0034` liefert mit `studio_overview` die einzige verbliebene Stelle, ausschließlich als Summen, ohne Aufschlüsselung je Gerät unterhalb von fünf aktiven Mitgliedern.

`0032`–`0034` sind auf Platte und lokal angewendet; der Cloud-Abgleich (Fahrplan Abschnitt 4d) steht für diese drei noch aus, die Cloud bleibt bis dahin auf `0031`.

---

## 4. Die drei Blocker

Keiner davon ist Code.

1. **SMTP-Versand.** ✅ **Erledigt am 1. September.** Eine echte Mail mit sechsstelligem Code ist angekommen. Der Weg dorthin ging über drei Stationen, von denen nur die erste vorhergesehen war:
   - **Pro-Upgrade.** Supabase rechnet **pro Organisation** ab; dieses Konto hat vier. Ein Upgrade in der falschen hätte nichts bewirkt, und die API hätte weiter mit *„free tier project"* geantwortet. Danach `supabase config push` → `auth: updated`, Folge-Diff leer.
   - **Zwei fehlende Umgebungsvariablen in Vercel** (siehe Abschnitt 4a).
   - **Kein Konto.** Siehe Abschnitt 4b — die Mail blieb aus, weil es die Adresse nicht gab, nicht weil das Template fehlte.

2. **Der Mac.** Die iOS-App existiert nicht als eine Zeile Code. M0 Task 7 (Universal-Link-Validierung) und Task 8 (physischer NFC-Test) warten dort. **Task 8 ist ein Gate:** liest der Tag am echten Gerät nicht zuverlässig, wird das Produkt QR-first statt NFC-first.
3. **`APPLE_TEAM_ID` / `APPLE_BUNDLE_ID`** stehen in Vercel auf Platzhaltern (`ABCDE12345` / `de.fitretro.member`). Muss vor jedem TestFlight-Build weg.

### 4a. Was die Produktion am 1. September lahmlegte

`SUPABASE_URL` und `SUPABASE_ANON_KEY` waren in Vercel **nicht gesetzt** — nur die `NEXT_PUBLIC_`-Varianten. Die werden zur Bauzeit ins Bundle eingesetzt, die anderen zur Laufzeit gelesen; `requiredEnv` warf also bei jedem Client-Bau.

Die Messung, die es festnagelte — jede Route, die einen Supabase-Client baut, lieferte 500, jede andere 200:

| Route | Client? | vorher | nachher |
| --- | --- | --- | --- |
| `/login`, `/api/aasa`, AASA-Datei | nein | 200 | 200 |
| `/api/v1/me/bootstrap` *ohne* Header | nein (`bearerClientFrom` gibt vorher `null`) | 401 | 401 |
| `/`, `/t/<token>` | **ja** | **500** | 200 |
| `/api/v1/me/bootstrap` *mit* Header | **ja** | **500** | 401 |

**Die Lehre war der Smoke-Test.** `pnpm smoke:aasa` stand im M0-Plan als ✅ und prüft ausschliesslich die AASA-Route — ausgerechnet eine der wenigen, die **keinen** Supabase-Client baut. Er meldete grün, während die halbe Anwendung 500 warf.

Zweite Falle bei der Messung: Vercel liefert Fehlerseiten aus dem Edge-Cache. Nach dem Fix meldete `curl` weiter 500 (`X-Vercel-Cache: HIT`), obwohl die Seite längst lief.

**Beides ist jetzt Werkzeug statt Anekdote.** `pnpm smoke:web <domain>` prüft beide Routenklassen getrennt und benennt sie — Routen ohne Supabase-Client als Kontrollgruppe, Routen mit Client als eigentliche Probe. Fällt nur die zweite Gruppe aus, druckt er die Diagnose aus, die hier eine Stunde gekostet hat. Jede Anfrage trägt einen Cache-Buster. `pnpm smoke:migrations` vergleicht Platte gegen Projekt.

### 4b. Warum keine Mail kam, obwohl alles richtig konfiguriert war

`apps/web/app/login/actions.ts` ruft `signInWithOtp` mit `shouldCreateUser: false`. Existiert die Adresse nicht, antwortet Supabase mit `422 otp_disabled` und verschickt **nichts** — das Portal meldet trotzdem *„Code gesendet"*, absichtlich, gegen User-Enumeration.

Das Produktivprojekt wurde am 30. August zurückgesetzt; `auth.users` war damit leer. Konten entstehen bis Phase 2 **von Hand** im Dashboard (Authentication → Users → Add user, *Auto Confirm User* anhaken — sonst greift das `confirmation`-Template, das nirgends angepasst ist).

**Wo der Beweis stand:** die Action loggt `console.error("OTP-Versand fehlgeschlagen: …")`. Die Antwort lag seit dem ersten Versuch in den Vercel-Logs. Bei einem stillen Fehlschlag in der Anmeldung ist das die erste Adresse.

### 4c. Die Produktionsdatenbank war zehn Migrationen zurück — erledigt

Auf Platte `0001`–`0021`, in der Cloud nur `0001`–`0011`. Es fehlten `0012`–`0021`: Trainingsdaten, Tag-Schreibpolicies, Medien-Buckets und `0021_fallback_inhalte`.

Ursache: Das Projekt wurde am 30. August zurückgesetzt und neu migriert — damals endete es bei `0011`. Die vier Migrationen vom 31. August und die sechs aus dem Medien-Plan kamen danach und blieben lokal.

**Das war latent, nicht sichtbar.** `/t/<token>` antwortete mit 200, weil ein unbekannter Token die leere Menge liefert und die Seite korrekt *„unbekannt"* zeigt, ohne je eine Spalte zu lesen. Erst ein **echter** Tag hätte es zum Vorschein gebracht: die Cloud trug noch die `0003`-Fassung von `resolve_tag_fallback` mit einer Rückgabespalte, die Seite erwartet die `0021`-Fassung mit fünf. Ebenso hätte das Portal dort kein Foto hochladen können — die Buckets aus `0020` fehlten.

**Nachgezogen am 1. September:** alle zehn angewendet, `supabase migration list` meldet Gleichstand über 21 Einträge, und die Produktion antwortet danach unverändert (`/`, `/login`, `/api/aasa`, `/t/<token>` mit 200, `/api/v1/me/bootstrap` mit ungültigem JWT mit 401).

**Die Lehre, die bleibt:** ein Rückstand dieser Art meldet sich nicht von selbst — er wartet auf den ersten echten Datensatz. Deshalb fragt ihn jetzt `pnpm smoke:migrations` ab. Er hat bei seinem ersten Lauf prompt die nächste Drift gefunden: `0022`–`0024` lagen seit dem Worktree-Merge auf Platte und noch nicht im Projekt.

### 4d. Die zweite Drift — geschlossen am 2. September, auf einem Umweg

Am 2. September war der Rückstand auf **zehn** angewachsen (`0022`–`0031`, Cloud auf `0021`). Alle zehn sind angewendet; `list_migrations` meldet Gleichstand über 31 Einträge, und eine Gegenprobe am Schema bestätigt neun Funktionen, `tag_batches`/`tag_shipments`, `machine_tags.token` mit generiertem `token_hash`, `studios.join_code` und fünf Policies auf `studio_memberships`.

**Der Umweg ist der eigentliche Befund.** `supabase db push` und `supabase migration list` scheitern auf dieser Maschine mit `LegacyDbConfigLoginRoleNetworkError: TransportError`, während `api.supabase.com` per HTTPS erreichbar ist (401 ohne Token). Die CLI baut eine **direkte Postgres-Verbindung** zum Pooler auf; die HTTPS-Management-API tut das nicht. Ausgehend gesperrter 5432/6543 ist die naheliegende Erklärung. Angewendet wurden die zehn deshalb über den Supabase-MCP-Server, der über die Management-API geht.

Zwei Dinge, die daraus zu merken sind:

- **`pnpm smoke:migrations` ist auf dieser Maschine blind.** Er ruft die CLI auf und bekommt denselben Transportfehler — er meldet dann `exit 2` („lief nicht"), nicht `exit 1` („Drift"), unterscheidet also sauber zwischen *kaputt* und *auseinander*. Das ist die richtige Trennung, aber sie heißt auch: der Abgleich muss von woanders laufen oder über die API gehen.
- **`apply_migration` über MCP vergibt eigene Zeitstempel-Versionen** (`20260902152032` statt `0026`). Das hätte `supabase migration list` dauerhaft als Drift gemeldet, obwohl das Schema stimmt. Die Einträge wurden anschließend auf `0022`–`0031` normalisiert. Wer den Weg wieder geht, muss das mitmachen.

### Das Ungleichgewicht, das die Reihenfolge bestimmt

| | Web-Portal | iOS Member-App |
| --- | --- | --- |
| Design | 39 Artboards ✅ | 34 Artboards ✅ |
| Backend | Katalog ✅, Tag-Kette ✅, Auth ✅, Leute ✅, Studio-Einstellungen ✅, Datenschutzgrenze ✅ — Phase 2 zu | vollständig für M1 ✅ |
| Frontend-Code | acht Seiten, ungestaltet | **null** |

Die Member-App ist backendseitig fertig und scheitert nur an Blocker 2 und 3. Das Portal hat sein Backend jetzt beisammen — offen ist weiterhin nur die Gestaltung, dazu die neuen Bauabschnitte Einrichtung am Gerät (Phase 3) und Kurse (Phase 4).

---

## 5. Der Fahrplan

### Phase 0 — Entscheiden *(läuft)*

- [x] **SMTP:** Supabase Pro, entschieden und gebucht 1. September (Organisation `Gymodo`)
- [x] **Template ins Projekt gepusht**, per leerem Folge-Diff belegt
- [x] **Echte OTP-Mail mit sechsstelligem Code angekommen** — Blocker 1 ist zu
- [x] **`supabase db push`** — zehn Migrationen nachgezogen, lokal und Cloud standen auf `0021` (Abschnitt 4c)
- [x] **Zweite Drift geschlossen** — `0022`–`0031` angewendet, Gleichstand über 31 Einträge (Abschnitt 4d)
- [ ] **`auth_leaked_password_protection` einschalten** — seit der Passwort-Umstellung fällig, ein Haken im Dashboard
- [ ] **Mac-Übernahme:** wann — und wird vorher NFC oder QR entschieden
- [ ] **Kurse:** Teil von M2 oder vertagt (der größte ungeplante Brocken)

### Phase 1 — Die Tag-Kette schließen ✅ *abgeschlossen 2. September*

Der einzige Strang, in dem Design, Datenbank und Umsetzungsplan bis zum Ende durchgezogen waren. Die Reihenfolge war nicht wählbar, und sie hat gehalten:

```
Worktree 2b2be9c gemerged                       ✅
   ↓
0022–0025   scan-beitritt-datenbank.md          ✅ 5 Aufgaben
   ↓        (tag_kind + Constraint, join_studio_by_tag,
   ↓         Selbstaustritt, Web-Fallback)
   ↓
0026–0029   tag-lieferung.md                    ✅ 8 Aufgaben
            Testhelfer → createTag-Rückbau → Klartext →
            Chargen → Funktionen → pnpm tags → TagBinden → Vorrat
```

Aus den drei geplanten Migrationen der Tag-Lieferung sind vier geworden: `0029_tag_batches_read` kam beim Abschlussreview dazu, weil `tag_batches` ohne Policy zwar ein *unverbundenes* Studio richtig aussperrte, aber auch dem verbundenen die eigene Charge verbarg — die Tags-Seite konnte „Charge 7" nicht anzeigen.

**Der Nebengewinn ist eingetreten:** Aufgabe 7 hat `TagZuweisen` zu `TagBinden` auf ein Token-Textfeld umgebaut. Der Rückfallweg für den Sucher steht damit, **bevor** der Sucher gebaut ist — `einrichtung-am-geraet-design.md` §7 hat seinen *„einzigen Ausfallpunkt ohne Rückfallweg"* verloren.

### Phase 2 — Portal-Backend-Lücken ✅ *abgeschlossen 2. September*

Vier Bauabschnitte waren vorgesehen. Die ersten beiden wurden ohne Umsetzungsplan gebaut — direkt aus Spec und Artboards; das hat funktioniert, war aber kein Präzedenzfall: beide waren eng umrissen (eine Migration plus eine Seite). Für die verbleibenden zwei hat sich das bestätigt — sie brauchten einen eigenen Plan, `2026-09-02-studio-einstellungen-datenschutzgrenze.md`, 9 Aufgaben.

1. ~~**Auth**~~ — Passwort, Registrierung, Bestätigung, Zurücksetzen ✅
2. ~~**Leute**~~ — `0030` Beitrittscode, `0031` vier Policies statt einer ✅
3. ~~**Studio-Einstellungen**~~ — Spalten am Studio, Stornofrist ✅
4. ~~**Datenschutzgrenze**~~ — vier Policies + Aggregatfunktion → schaltet *Überblick* frei ✅

Punkt 4 hing an Punkt 3 nicht fachlich, aber beide fassten `studios` an; nacheinander gebaut haben sie sich eine Migration erspart, die die andere wieder angefasst hätte.

### Phase 3 — Einrichtung am Gerät

Die 16 `Telefon*`-Artboards: der Gang durch die Halle, sechs Schritte, Modell → Einstellungen → Gerät → Tag → Übungen → Video. Hier sitzt **der Sucher** — `getUserMedia` und ein Decoder im Browser, weil Safari `BarcodeDetector` nicht kennt. Spec steht (`2026-09-01-einrichtung-am-geraet-design.md`), Umsetzungsplan fehlt.

Der größte Brocken mit fertiger Spec, und der einzige echte Neubau, der nach Phase 1 übrig bleibt. Das Risiko ist gedeckt: der Rückfallweg über das Token-Textfeld steht seit `TagBinden`.

### Phase 4 — Kurse

Drei Tabellen, Platzvergabe unter Nebenläufigkeit, Endpoints, Server Actions. Heute nur `2026-08-30-kurse-datenmodell.md` als Vorabnotiz — der einzige Bereich ganz ohne Spec.

### Phase 5 — Portal-Frontend

Die 39 Artboards gestalterisch umsetzen. Kommt zuletzt, weil erst dann feststeht, welche Seiten es überhaupt gibt.

### Phase 6 — iOS auf dem Mac

M0 Task 7 und 8, danach die 34 Member-Artboards. **Kann ab sofort parallel laufen** — das Backend der Member-App steht vollständig, und Phase 1 ist zu.

### Was parallel geht und was nicht

Nach Phase 1 und dem Abschluss von Phase 2 zerfällt die Arbeit in zwei Stränge, die einander nicht berühren:

| Strang | Inhalt | Berührt |
| --- | --- | --- |
| **B** | Phase 3 — Einrichtung am Gerät samt Sucher | eigene Telefonseiten |
| **C** | Phase 6 — iOS | eigenes Repo-Verzeichnis, blockiert nur durch Hardware |

**Nicht parallel:** Phase 5 gegen B — beide fassen dieselben Portalseiten an. Und Phase 4 (Kurse) sollte warten: sie braucht zuerst eine Entwurfsrunde, und die ist nach der Lehre aus Abschnitt 7 erst dann fällig, wenn der Abstand zwischen Entwurf und Code wieder klein ist.

---

## 6. Offene Entscheidungen, gesammelt

Verstreut über fünf Specs, hier einmal an einem Ort. Jede bleibt in ihrem Ursprungsdokument gültig; das hier ist der Index.

| Punkt | Wo | Blockiert |
| --- | --- | --- |
| Druckmaße des QR — Modulgröße, Fehlerkorrektur | einrichtung §7, scan-beitritt §7 | die erste Tag-Bestellung |
| NFC-Tags programmieren — vorprogrammiert bestellen oder Werkzeug bauen | scan-beitritt §7 | den NFC-Teil, nicht den QR-Teil |
| Trefferquote NFC gegen QR | M0 Task 8 | Gate, siehe Blocker 2 |
| Ratenbegrenzung auf `join_studio_by_tag` | scan-beitritt §7 | nichts, aber vor dem ersten echten Studio fällig |
| Wie viele Aushangschilder pro Studio | tag-lieferung §10 | die Ergonomie von `--nummern` |
| Chargengröße gegen Lieferungsgröße | tag-lieferung §10 | Beschaffung |
| `replaced` ist unbenutzt — Weg geben oder streichen | tag-lieferung §10 | nichts |
| Kein Weg zurück in die Halde | tag-lieferung §10 | nichts |
| Mindestzahl für die Aufschlüsselung im Überblick — auf 5 gesetzt, vor dem ersten echten Mitglied zu prüfen | 0034, Spec §4 | nichts |
| Nachrück-Benachrichtigung — Push gibt es nicht | trainerportal-struktur §8 | Phase 3 |
| Kursvideo | trainerportal-struktur §8 | vertagt, nicht verworfen |
| Studiogründung gibt es bewusst nicht | trainerportal-struktur §8 | den zweiten Betreiber |
| Nummernvergabe — soll das Portal `machines.label` erzwingen | einrichtung §7 | nichts, Entwurf sagt nein |
| Leerer Vorrat mitten in der Halle — kein Bestellweg | einrichtung §7, tag-lieferung §8 | nichts |
| Videoupload vom Trainerhandy ist nie an einem echten Gerät gelaufen | trainerportal-medien, Verifikation | den ersten Betreibertermin |

---

## 7. Die Lehre, die dieses Dokument festhält

`2026-09-01-konflikte-scan-und-einrichtung.md` musste aufräumen, was zwei parallele Entwurfsrunden am selben Tag hinterlassen hatten. Sein Schlusssatz gilt weiter:

> Der Bruch lag nicht zwischen den Runden, sondern in der Lücke, die beide für die jeweils andere offen gelassen haben.

**Der Abstand zwischen Entwurf und Code ist die Quelle dieser Lücken.** Er war auf 29 Commits gewachsen. Phase 1 hat ihn für die Tag-Kette geschlossen, Phase 2 zur Hälfte für das Portal-Backend.

**Was die Erstfassung nicht vorhersah:** dass Auth und Leute *ohne* Umsetzungsplan gebaut werden würden — direkt aus Spec und Artboards. Es ist gutgegangen, und der Grund ist nicht Glück: beide Abschnitte waren eng umrissen (eine Migration, eine Seite, ein E2E-Gang) und hatten fertige Artboards, an denen sich jede Entscheidung ablesen ließ. Für Phase 3 gilt das nicht — sechzehn Bildschirme, ein Sucher und ein Gang, der über mehrere Sitzungen trägt. Dort ist der Plan keine Formalie.

**Und ein zweiter Abstand ist dazugekommen:** der zwischen Platte und Cloud. Er hat sich am 1. September auf zehn Migrationen aufgebaut und am 2. September gleich noch einmal (Abschnitt 4c und 4d). Beide Male hat nichts ihn gemeldet, weil nichts ihn melden konnte — bis `pnpm smoke:migrations` entstand. Dass der jetzt auf dieser Maschine selbst am Netz scheitert, ist die nächste offene Kante.

---

## 8. Wann dieses Dokument zu aktualisieren ist

Nach jedem abgeschlossenen Bauabschnitt: die Zeile in Abschnitt 3 auf ✅, den Bezugsstand in der Kopftabelle nachziehen, und erledigte Punkte in Abschnitt 6 streichen statt durchzustreichen — die Begründung steht im jeweiligen Plan.
