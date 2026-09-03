# Gesamtfahrplan — Stand, Lücken und Reihenfolge

**Stand:** 3. September 2026 *(fortgeschrieben; Erstfassung 1. September)*
**Status:** Bestandsaufnahme. **Kein ausführbarer Task-Plan** — dieses Dokument ordnet die vorhandenen Pläne, es ersetzt keinen.
**Bezugsstand:**

| | Commit | Inhalt |
| --- | --- | --- |
| `master` | `2f81861` | alles zusammengeführt und **ausgeliefert**: Phase 1, 2 und 3, `0001`–`0034` |
| `designplan` | `7c1f18c` | in `master` aufgegangen |
| `design-geräteeinrichtung` | `13d065b` | in `master` aufgegangen |
| `worktree/brave-forest-c9d8` | `2b2be9c` | Tag-Lieferung, in `master` aufgegangen |
| `worktree/calm-forest-3c59` | `05be485` | Studio-Einstellungen, Datenschutzgrenze, Überblick: `0032`–`0034`, Fachschicht, Reiter Studio/Konto, E2E-Gang — **in `master` aufgegangen am 3. September** |
| `phase3-einrichtung-am-geraet` | `a4e4057` | Der Gang durch die Halle, Route-Gruppe `(schreibtisch)`, drei Fachschichtfunktionen, Fix an `stripImageMetadata` und `bodySizeLimit` — in `master` aufgegangen am 3. September; **der Sucher (9b) fehlt** |

> **Was sich gegenüber der Erstfassung geändert hat, in einem Satz:** Sie beschrieb einen Stand, an dem die entworfenen Baustellen *zu null* gebaut waren — inzwischen stehen Phase 1, 2 und 3. Die Abschnitte 1 bis 5 sind entsprechend fortgeschrieben; die Betriebsbefunde aus 4a–4f bleiben als Lehre stehen, auch wo ihr Anlass erledigt ist.

---

## 0. Wie dieses Dokument zu lesen ist

Es beantwortet drei Fragen, die sich nach fünf Entwurfsrunden nicht mehr aus einem einzelnen Dokument beantworten ließen: *Was steht? Was fehlt? In welcher Reihenfolge?*

Es ist bewusst kurz und verweist. Die Wahrheit über einen Bauabschnitt steht immer in seinem eigenen Plan, nie hier.

---

## 1. Der Stand in einem Satz

**Der Abstand zwischen Entwurf und Code, den die Erstfassung als Quelle aller Lücken benannte, ist geschlossen.** Phase 1, 2 und 3 stehen, und zwar gleichlautend an allen vier Orten: auf Platte, in der lokalen Datenbank, in der Cloud und in der Auslieferung.

Die Erstfassung hielt fest: `git diff master designplan -- . ':(exclude)docs'` war **leer** — 29 Commits, keine Zeile Code, auf Platte endete es bei `0021_fallback_inhalte.sql`. Drei Sessions später liegen **dreizehn weitere Migrationen** (`0022`–`0034`), die Fachschicht dazu, der ganze Gang durch die Halle, Einstellungen und Überblick — und 41 Integrationsdateien statt 27.

Das Ungleichgewicht aus der Erstfassung hat sich verschoben, aber nicht aufgelöst: **das Portal ist funktional vollständig und ungestaltet; die Member-App hat ihr Backend und keine Zeile Code.**

---

## 2. Was gebaut ist und läuft

| Bereich | Stand |
| --- | --- |
| Monorepo, CI, Vercel (`gymodo-web.vercel.app`), AASA-Route | ✅ |
| Migrationen `0001`–`0034`, RLS mit Positiv-, Negativ- und Cross-Tenant-Test je Policy | ✅ |
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
| **Einrichtung am Gerät** — der sechsschrittige Gang auf 390 px, Route-Gruppe `(schreibtisch)`, Upload-Warteschlange über Geräte hinweg, Tag ersetzen | ✅ neu, **ohne den Sucher** |
| Testlage: **41** Integrationsdateien (461 Tests), **8** E2E-Dateien (30 Tests), 85 Unit-Tests | ✅ grün |
| Produktion — `0001`–`0034` angewendet, `master` ausgeliefert, `smoke:web` bestanden | ✅ **3. September**, siehe 4f |

**Der Kassensturz aus `2026-08-31-trainerportal-struktur-design.md` §7 ist überholt.** Er nannte den Gerätekatalog als einzigen vollständig tragenden Bereich; das gilt nicht mehr. Die Tag-Kette trägt vom Herstellungslos bis zum Scan vor dem Gerät, und von den vier dort als „am weitesten offen" bezeichneten Punkten sind jetzt alle vier zu (Leute, Auth, Studio-Einstellungen, Datenschutzgrenze).

---

## 3. Was entworfen, aber nicht gebaut ist

73 Artboards (34 Member, 39 Portal) und sieben Specs stehen. Dahinter:

| Baustelle | Migrationen | Umsetzungsplan | Gebaut |
| --- | --- | --- | --- |
| ~~**Beitritt durch Scannen**~~ — `tag_kind`, `join_studio_by_tag`, Selbstaustritt, Fallback-Erweiterung | `0022`–`0025` | ✅ `2026-09-01-scan-beitritt-datenbank.md`, 5 Aufgaben | ✅ **2. September** |
| ~~**Tags als Lieferung**~~ — Klartext-Tokenraum, Chargen/Lieferungen/Halde, `inspect_tag`/`bind_tag_to_machine`, Betreiberwerkzeug | `0026`–**`0029`** | ✅ `2026-09-01-tag-lieferung.md`, 8 Aufgaben | ✅ **2. September** |
| ~~**Auth-Umstellung**~~ — OTP → Passwort, Registrierung, Studio-Beitritt | — | ❌ ohne Plan gebaut | ✅ **2. September** |
| ~~**Leute**~~ — Mitglieder und Mitarbeiter | `0030`–`0031` | ❌ ohne Plan gebaut | ✅ **2. September** |
| ~~**Sucher im Portal**~~ — `getUserMedia` + `jsQR` | — | ✅ als Aufgabe 9b im Plan | ✅ **3. September**, Handprüfung bestanden — gedruckte Codes bis herunter auf 15 mm |
| ~~**Einrichtung am Gerät**~~ — 16 `Telefon*`-Artboards, der Gang durch die Halle | keine | ✅ `2026-09-02-einrichtung-am-geraet.md`, 13 Aufgaben | ✅ **3. September**, vollständig |
| ~~**Studio-Einstellungen, Datenschutzgrenze, Überblick**~~ — Stornofrist, Speicherrecht mit Spaltengrenze, vier Policies ohne Staff-Klausel, `studio_overview` | `0032`–`0034` | ✅ `2026-09-02-studio-einstellungen-datenschutzgrenze.md`, 9 Aufgaben | ✅ **2. September** |
| **Kurse** — drei Tabellen, Platzvergabe unter Nebenläufigkeit | — | ❌ nur Vorabnotiz (84 Zeilen) | ❌ |
| **Portal-Frontend nach den 39 Artboards** | — | ❌ | ❌ |
| **iOS Member-App** | — | ❌ | ❌ `apps/` enthält nur `web` |

### Was von den vier „am weitesten offenen" übrig ist

Die Erstfassung nannte vier. Alle vier sind zu:

- ~~**Leute:**~~ `memberships_select_own` erlaubte genau die *eigene* Zeile — ein Trainer konnte seine Mitgliederliste nicht einmal lesen. `0031` legt die vier Policies nach (`memberships_select_staff`, `_update_staff`, `_delete_staff`, dazu `list_studio_members` für die E-Mail-Adresse, die außerhalb der `public`-Policies liegt). Die Inhaberzeile ist über alle drei Pfade unerreichbar — die Regel *„niemand entzieht sich die letzte Inhaberrolle"* ist damit von der Policy erzwungen, nicht von einer Zählfunktion.
- ~~**Auth:**~~ `signInWithPassword` steht, dazu Registrierung, Bestätigung, Passwort vergessen und zurücksetzen. `auth_leaked_password_protection` war zunächst aus — solange nur OTP lief, war die Einstellung gegenstandslos, mit Passwörtern nicht mehr. **Am 2. September eingeschaltet.**
- ~~**Studio-Einstellungen:**~~ `studios` hatte `studios_select` und keine Spalte für die Stornofrist — Speichern war nicht möglich. `0032` legt `cancellation_deadline_hours` an (Vorgabe 2 Stunden, Bereich 0–168) und zieht das Spaltenrecht auf `join_code` aus `authenticated` ab; der Reiter *Studio* unter `/einstellungen` speichert Name, Zeitzone und Frist.
- ~~**Datenschutzgrenze:**~~ `0033` nimmt vier Policies (`workout_sessions`, `workout_sets`, `member_machine_calibrations`, `progression_suggestions`) die Staff-Klausel — Personal kommt an kein einzelnes Trainingsdatum eines Mitglieds mehr heran. `0034` liefert mit `studio_overview` die einzige verbliebene Stelle, ausschließlich als Summen, ohne Aufschlüsselung je Gerät unterhalb von fünf aktiven Mitgliedern.

`0032`–`0034` stehen auf Platte, lokal **und in der Cloud** — nachgezogen am 3. September, Abschnitt 4f.

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

### 4e. Die dritte Drift — und diesmal war die Platte hinten

Am 3. September meldete die Integrationssuite auf dem Phase-3-Zweig vier Fehlschläge, alle nach demselben Muster: *„ein Trainer sieht die … seiner Studiomitglieder"* lieferte die leere Menge. Der erste Verdacht — ein Defekt in der Datenbank — war falsch, und die Messung, die ihn widerlegt hat, ist die Merkwürdigkeit dieses Falls:

| Prüfung, mit frischem Studio und Trainer | Ergebnis |
| --- | --- |
| `is_studio_member(studio)` | `true` |
| `is_studio_staff(studio)` | `true` |
| Trainer sieht sein Studio | ja |
| Trainer sieht die Session seines Mitglieds | **leer** |

`0012` verlangt `is_studio_member and (eigene Zeile or is_studio_staff)`. Mit beiden Funktionen auf `true` **musste** die Policy greifen. Sie tat es nicht — also stand in der Datenbank eine andere Fassung als in der Datei.

**Der Grund war kein Rückstand, sondern ein Vorsprung.** Die Datenbank führte **34** Migrationen, das Repository **31**: `0032`–`0034` waren angewendet, lagen aber nur auf dem noch nicht gemergten `worktree/calm-forest-3c59`. Die vier Tests prüften den Vertrag *vor* der Datenschutzgrenze; `0033` hatte ihn längst abgeschafft.

**Was daraus zu merken ist, und es ist nicht die Lehre aus 4c und 4d:**

- **Dort fehlten Migrationen in der Cloud, hier fehlten sie im Repository.** Der Reflex aus den ersten beiden Fällen — „die Datenbank nachziehen" — wäre hier zerstörerisch gewesen: ein `supabase db reset` hätte drei Migrationen und den ganzen Bauabschnitt dahinter gelöscht, weil sie in keiner Datei standen. Vor jedem Reset gehört die Frage: *ist die Datenbank hinten oder vorn?*
- **Rekonstruierbar waren sie nur, weil Supabase die Anweisungen mitschreibt.** `supabase_migrations.schema_migrations.statements` enthielt alle drei im Wortlaut. Das ist die Rettungsleine — aber kein verlässlicher Zeuge: der Eintrag zu `0034` trug eine ältere Fassung als die laufende Funktion, weil sie später ohne Nachtrag neu eingespielt worden war.
- **Ein paralleler Worktree ist eine Drift-Quelle wie eine Cloud.** Beide Zweige teilten sich dieselbe lokale Datenbank; der eine wendete an, der andere sah die Dateien nicht. Solange zwei Zweige eine Datenbank teilen, ist der Migrationsstand kein Merkmal des Zweigs mehr.

Geschlossen am 3. September: Worktree nach `master`, `master` in den Phase-3-Zweig, danach `supabase db reset`. Verzeichnis und Platte stehen seither beide auf **34**.

### 4f. Cloud-Abgleich am 3. September — und einmal ohne Überraschung

Nach der Zusammenführung standen Platte auf **34**, Cloud auf **31**. Der Rückstand war exakt `0032`–`0034` und sonst nichts: die Nummerierung der ersten 31 war noch die normalisierte aus §4d, es gab keine zweite Drift darunter.

Alle drei über den MCP-Server angewendet (die CLI kommt von dieser Maschine weiterhin nicht an die Postgres-Strecke). Die Warnung aus §4d hat sich wortgetreu bestätigt: `apply_migration` vergab `20260903080038`, `20260903080055`, `20260903080119`. Anschließend auf `0032`–`0034` normalisiert.

**Gegengeprüft wurde am Schema, nicht am Verzeichnis** — der Eintrag dort hat sich in §4e als unzuverlässiger Zeuge erwiesen:

| Prüfung | Ergebnis |
| --- | --- |
| Migrationen | 34 |
| `studios.cancellation_deadline_hours` | vorhanden |
| Policy `studios_update_staff` | vorhanden |
| `authenticated` darf an `studios` ändern | `cancellation_deadline_hours, name, timezone` — `join_code` außen vor |
| Funktion `studio_overview` | vorhanden |
| `workout_sessions_select` | `is_studio_member(...) and user_id = auth.uid()` |
| **Policies mit `is_studio_staff`-Klausel auf den vier Trainingstabellen** | **0** |

Der Sicherheitsbefund vor und nach der Anwendung ist bis auf einen Eintrag gleich: `studio_overview` ist jetzt zusätzlich als `SECURITY DEFINER` für Angemeldete aufrufbar — genau der Entwurf, sie prüft `is_studio_staff` im Rumpf selbst. Keine Fehlerstufe, nichts verschlechtert.

**Reihenfolge, die hier zählte:** Datenbank vor Deploy. Alle drei sind mit der laufenden Vercel-Fassung verträglich (eine Spalte mit Vorgabewert, weggenommene Rechte, eine neue Funktion), aber der neue Überblick auf der Portal-Wurzel ruft `studio_overview` auf — umgekehrt hätte die Seite zwischen Deploy und Migration in einen Fehler gelaufen.

**Ausgeliefert am 3. September, direkt danach.** 47 Commits nach `origin/master`, Vercel baut ueber die GitHub-Integration. `pnpm smoke:web gymodo-web.vercel.app` bestanden — beide Routenklassen, also auch die mit Supabase-Client, die am 1. September die 500er warfen.

Dass der **neue** Stand liegt und nicht der alte weiterlaeuft, ist eigens belegt: die drei Routen, die es vorher nicht gab, antworten unangemeldet mit 307 (Weiterleitung zum Login), eine erfundene Route mit 404.

| Route | |
| --- | --- |
| `/portal/<id>/einrichten` | 307 |
| `/portal/<id>/einstellungen` | 307 |
| `/portal/<id>/modelle` | 307 |
| `/portal/<id>/gibtesnicht` | 404 — die Kontrolle |

**Was damit nicht belegt ist:** dass der Ueberblick in der Produktion tatsaechlich rendert. Dafuer braeuchte es ein angemeldetes Konto, und Konten entstehen dort bis auf Weiteres von Hand (Abschnitt 4b). Die Funktion `studio_overview` ist vorhanden und der Weg lokal durch 26 E2E-Tests gedeckt — der erste echte Blick darauf ist der erste Betreibertermin.

**Nebenbefund, nicht dringend:** vier Funktionen tragen keinen gesetzten `search_path` — `set_updated_at`, `is_valid_setting_choices`, `storage_studio_id`, `generate_join_code`. Das Projekt setzt ihn sonst überall (`set search_path = public, pg_temp`); diese vier sind mit der eigenen Gewohnheit uneins. Eine Migration, wenn ohnehin eine ansteht.

### 4g. Die vierte Drift — diesmal die Auth-Konfiguration

Am 3. September, beim **ersten menschlichen Anmeldeversuch in der Produktion**: die Mail zum Zurücksetzen des Passworts enthielt einen Link, die Oberfläche verlangt einen sechsstelligen Code.

Auf Platte setzen alle drei Vorlagen (`confirmation`, `magic_link`, `recovery`) auf `{{ .Token }}`. Ein Link ist Supabases Standardvorlage — die Cloud trug die eigenen also nicht. `config.toml` bekam `recovery` und `confirmation` erst mit `6a1fffb` am 2. September; der letzte `config push` liegt davor, am 1. September.

**Es ist dieselbe Drift wie 4c bis 4f, zum vierten Mal — und zum ersten Mal nicht im Schema, sondern in der Auth-Konfiguration.** Die Lehre aus 4e gilt unverändert: erst fragen, welche Seite hinten ist. Hier war es die Cloud.

**Was den Fehler verdeckt hat:** der Link führt auf `site_url` und trägt sein Token im URL-Fragment. Ein Fragment erreicht den Server nie, `/` ist eine Server-Komponente — sie sah keine Sitzung und schrieb *„Nicht angemeldet."* Der Nutzer sieht damit einen Anmeldefehler, wo eine falsche Vorlage liegt.

**Und warum es niemand vorher sah:** kein Test ging den Weg, den ein Mensch geht. Die E2E-Dateien melden sich an und springen dann per `page.goto` auf ihr Ziel. `e2e/onboarding.spec.ts` schließt diese Lücke — er navigiert nach dem Login nicht mehr, sondern misst, wo man landet.

**Ein zweiter Befund aus derselben Runde, unabhängig vom Onboarding:** auf Port 3000 hing ein Dev-Server aus einem früheren Lauf. Lokal gilt `reuseExistingServer: true` — Playwright verwendet einen solchen Server wieder, mitsamt Code von *vor* der Änderung. Ein neuer Test schlug dadurch zweimal fehl, obwohl sein Code stimmte; gegen den Produktionsbau lief dieselbe Suite zweimal mit 29 von 29 durch. Wer lokal einem roten Test nachgeht, prüft deshalb zuerst, was auf Port 3000 lauscht.

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
- [x] **`magic_link`-Vorlage ins Projekt gepusht** (1. September), per leerem Folge-Diff belegt
- [x] **`recovery`- und `confirmation`-Vorlage gepusht** (3. September), per leerem Folge-Diff belegt — der Push ersetzte in beiden Supabases englische Standardmail mit `{{ .ConfirmationURL }}` durch die eigene mit `{{ .Token }}`. Nebenwirkung, die der Plan nicht vorhergesehen hatte: dieselbe `[auth]`-Sektion hob `minimum_password_length` von 6 auf 10 — der Wert steht so in `config.toml`, die Cloud stand noch auf der Voreinstellung.
- [x] **Echte OTP-Mail mit sechsstelligem Code angekommen** — Blocker 1 ist zu
- [x] **`supabase db push`** — zehn Migrationen nachgezogen, lokal und Cloud standen auf `0021` (Abschnitt 4c)
- [x] **Zweite Drift geschlossen** — `0022`–`0031` angewendet, Gleichstand über 31 Einträge (Abschnitt 4d)
- [x] **Dritte Drift geschlossen** — `0032`–`0034` lagen nur in der lokalen Datenbank und auf einem unvermergten Worktree; zusammengeführt und in die Cloud nachgezogen, Gleichstand über 34 Einträge (Abschnitte 4e und 4f)
- [x] **`auth_leaked_password_protection` eingeschaltet** — am 2. September, seit der Passwort-Umstellung fällig
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

### Phase 3 — Einrichtung am Gerät ✅ *abgeschlossen 3. September*

Die 16 `Telefon*`-Artboards: der Gang durch die Halle, sechs Schritte, Modell → Einstellungen → Gerät → Tag → Übungen → Video. Dreizehn Aufgaben, **ohne eine einzige Migration** — die Spec hatte es versprochen, und es hat gehalten.

**Der Sucher (9b) kam am selben Tag nach** und hat die Teilung im Nachhinein gerechtfertigt: er brauchte `jsqr`, eine dritte Ansicht und eine verschobene Hauptaktion — sonst nichts. Alles hinter ihm stand schon, weil die Spec den Rückfallweg als eigenständig entworfen hatte.

**Was bleibt, ist eine Handprüfung.** `getUserMedia` verlangt einen sicheren Kontext, eine LAN-Adresse zählt nicht — es braucht also ein Telefon über HTTPS, einen gedruckten QR und zehn Minuten. Der einzige Punkt des Bauabschnitts, den kein Test abnimmt.

**Zwei Fehler, die der Bauabschnitt nebenbei freigelegt hat**, beide seit dem Medienplan im Schreibtischpfad und beide unsichtbar, weil jeder Test mit einem 22-Byte-JPEG lief:

- `stripImageMetadata` warf ab einem halben Megabyte `RangeError: Maximum call stack size exceeded` — beide Stripper füllten ein `number[]` per Spread. Jedes Foto aus einer Kamera zerbrach daran.
- Next schnitt den Rumpf jeder Server Action bei 1 MB ab, mit 413, bevor die Fachschicht die Bytes sah.

Die Lehre steht als Rahmenbedingung im Umsetzungsplan: **eine Mediendatei im Test hat die Größe, die sie in der Halle hat.**

### Phase 4 — Kurse

Drei Tabellen, Platzvergabe unter Nebenläufigkeit, Endpoints, Server Actions. Heute nur `2026-08-30-kurse-datenmodell.md` als Vorabnotiz — der einzige Bereich ganz ohne Spec.

### Phase 5 — Portal-Frontend

Die 39 Artboards gestalterisch umsetzen. Kommt zuletzt, weil erst dann feststeht, welche Seiten es überhaupt gibt.

### Phase 6 — iOS auf dem Mac

M0 Task 7 und 8, danach die 34 Member-Artboards. **Der einzige Strang, der jetzt noch wirklich parallel laufen kann** — das Backend der Member-App steht vollständig, und alles, was das Portal betrifft, fasst dieselben Seiten an.

### Was parallel geht und was nicht

Mit dem Abschluss von Phase 3 ist die Aufteilung in Stränge weitgehend hinfällig — es bleibt einer:

| Strang | Inhalt | Berührt |
| --- | --- | --- |
| **C** | Phase 6 — iOS | eigenes Repo-Verzeichnis, blockiert nur durch Hardware (Blocker 2 und 3) |

Alles Übrige hängt an derselben Oberfläche und läuft deshalb nacheinander:

- **Phase 5** gestaltet die Portalseiten, die Phase 2 und 3 gerade funktional gemacht haben. Erst jetzt steht fest, welche es überhaupt gibt.
- **Phase 4 (Kurse)** braucht zuerst eine Entwurfsrunde. Nach der Lehre aus Abschnitt 7 ist die erst fällig, wenn der Abstand zwischen Entwurf und Code klein ist — das ist er heute, also ist sie fällig.

---

## 6. Offene Entscheidungen, gesammelt

Verstreut über sieben Specs und drei Umsetzungspläne, hier einmal an einem Ort. Jede bleibt in ihrem Ursprungsdokument gültig; das hier ist der Index.

| Punkt | Wo | Blockiert |
| --- | --- | --- |
| NFC-Tags programmieren — vorprogrammiert bestellen oder Werkzeug bauen | scan-beitritt §7 | den NFC-Teil, nicht den QR-Teil |
| Trefferquote NFC gegen QR | M0 Task 8 | Gate, siehe Blocker 2 |
| Ratenbegrenzung auf `join_studio_by_tag` | scan-beitritt §7 | nichts, aber vor dem ersten echten Studio fällig |
| Wie viele Aushangschilder pro Studio | tag-lieferung §10 | die Ergonomie von `--nummern` |
| Chargengröße gegen Lieferungsgröße | tag-lieferung §10 | Beschaffung |
| `replaced` ist unbenutzt — Weg geben oder streichen | tag-lieferung §10 | nichts |
| Kein Weg zurück in die Halde | tag-lieferung §10 | nichts |
| Mindestzahl für die Aufschlüsselung im Überblick — auf 5 gesetzt, vor dem ersten echten Mitglied zu prüfen | 0034, Spec §4 | nichts |
| Nachrück-Benachrichtigung — Push gibt es nicht | trainerportal-struktur §8 | Phase 4 (Kurse) |
| Kursvideo | trainerportal-struktur §8 | vertagt, nicht verworfen |
| Studiogründung gibt es bewusst nicht | trainerportal-struktur §8 | den zweiten Betreiber |
| Nummernvergabe — soll das Portal `machines.label` erzwingen | einrichtung §7 | nichts, Entwurf sagt nein |
| Leerer Vorrat mitten in der Halle — kein Bestellweg | einrichtung §7, tag-lieferung §8 | nichts |
| Videoupload vom Trainerhandy ist nie an einem echten Gerät gelaufen | trainerportal-medien, Verifikation | den ersten Betreibertermin |
| **Probe-Scan auf der Fertig-Seite** — er bräuchte den Klartext-Token, den `0026` dem Portal entzieht. Aufzulösen mit einer `security definer`-Funktion je Gerät oder einer Fallback-Seite über die Geräte-ID | einrichtung-am-geraet, Plan Aufgabe 12 | dem Trainer den Blick auf das, was ein Mitglied sieht |
| **Vier Funktionen ohne gesetzten `search_path`** — `set_updated_at`, `is_valid_setting_choices`, `storage_studio_id`, `generate_join_code`; das Projekt setzt ihn sonst überall | Sicherheitsbefund 3. September, Abschnitt 4f | nichts, aber uneins mit der eigenen Gewohnheit |
| **`rls-workout-sessions` ist sporadisch rot** — der Test setzt `completed_at` aus der Node-Uhr gegen `started_at` aus der Datenbank | Bestand, vor allen drei Phasen | nichts, aber es verrauscht jede Abnahme |
| **Die Wurzelseite `/` ist ungestaltet** — seit dem 3. September sieht Personal sie nicht mehr, alle übrigen Angemeldeten schon. Sie trägt das Beitrittsformular und stammt aus M0 | Phase 5 | nichts, aber es ist die erste Seite, die ein Mitglied im Web sieht |
| **Ein verwaister Dev-Server auf Port 3000 verfälscht lokale E2E-Läufe still** — `playwright.config.ts` setzt lokal `reuseExistingServer: true`, Playwright verwendet also einen hängengebliebenen Server wieder, samt Code von vor der Änderung. Am 3. September lief ein Test deshalb zweimal rot, dessen Code korrekt war | Werkzeug | nichts, aber es kostet jedes Mal eine Fehlersuche am falschen Ort |

---

## 7. Die Lehre, die dieses Dokument festhält

`2026-09-01-konflikte-scan-und-einrichtung.md` musste aufräumen, was zwei parallele Entwurfsrunden am selben Tag hinterlassen hatten. Sein Schlusssatz gilt weiter:

> Der Bruch lag nicht zwischen den Runden, sondern in der Lücke, die beide für die jeweils andere offen gelassen haben.

**Der Abstand zwischen Entwurf und Code ist die Quelle dieser Lücken.** Er war auf 29 Commits gewachsen. Phase 1 hat ihn für die Tag-Kette geschlossen, Phase 2 für das Portal-Backend, Phase 3 für den Gang durch die Halle. Heute ist er null — und das ist der Moment, in dem die nächste Entwurfsrunde fällig wird, nicht später.

**Was die Erstfassung nicht vorhersah:** dass Auth und Leute *ohne* Umsetzungsplan gebaut werden würden — direkt aus Spec und Artboards. Es ist gutgegangen, und der Grund ist nicht Glück: beide Abschnitte waren eng umrissen (eine Migration, eine Seite, ein E2E-Gang) und hatten fertige Artboards, an denen sich jede Entscheidung ablesen ließ.

**Für Phase 3 galt das nicht, und die Vorhersage hat sich bestätigt.** Sechzehn Bildschirme, dreizehn Aufgaben, und der Plan hat unterwegs vier Dinge gefangen, die ohne ihn erst am Betreibertermin aufgefallen wären: der Absturz von `stripImageMetadata` an jedem echten Foto, die 1-MB-Grenze der Server Actions, der Probe-Scan, der an den Spaltenrechten aus `0026` scheitert, und die Frage, ob das Ersetzen eines Tags den alten sperrt. Drei davon standen im Plan, bevor eine Zeile Code entstand.

**Und ein zweiter Abstand ist dazugekommen:** der zwischen Platte und Datenbank. Dreimal in drei Tagen — 4c, 4d, 4e — und beim dritten Mal in die andere Richtung.

Das ist die eigentliche Lehre dieses Dokuments, und sie hat gedreht. Aus 4c und 4d ließ sich der Reflex ableiten *„die Datenbank ist hinten, zieh sie nach"*. In 4e war sie **vorn**: drei Migrationen waren angewendet, standen aber nur auf einem unvermergten Worktree. Derselbe Reflex hätte sie gelöscht. Vor jedem `supabase db reset` gehört deshalb die Frage: **ist die Datenbank hinten oder vorn?** — und die beantwortet ein Blick in `supabase_migrations.schema_migrations`, nicht das Gefühl.

Zwei Werkzeuge dazu, beide mit ihrer Grenze: `pnpm smoke:migrations` scheitert auf dieser Maschine am Netz und meldet dann sauber `exit 2` statt `exit 1` — *kaputt* ist nicht *auseinander*. Und die mitgeschriebenen Anweisungen im Migrationsverzeichnis haben die drei verschollenen Migrationen überhaupt erst rekonstruierbar gemacht, tragen aber im Fall `0034` eine ältere Fassung als die laufende Funktion. Rettungsleine ja, Zeuge nein.

---

## 8. Wann dieses Dokument zu aktualisieren ist

Nach jedem abgeschlossenen Bauabschnitt: die Zeile in Abschnitt 3 auf ✅, den Bezugsstand in der Kopftabelle nachziehen, und erledigte Punkte in Abschnitt 6 streichen statt durchzustreichen — die Begründung steht im jeweiligen Plan.
