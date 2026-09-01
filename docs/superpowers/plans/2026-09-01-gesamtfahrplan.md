# Gesamtfahrplan — Stand, Lücken und Reihenfolge

**Stand:** 1. September 2026
**Status:** Bestandsaufnahme. **Kein ausführbarer Task-Plan** — dieses Dokument ordnet die vorhandenen Pläne, es ersetzt keinen.
**Bezugsstand:**

| | Commit | Inhalt |
| --- | --- | --- |
| `master` | `7570aad` | letzter Stand mit Code |
| `designplan` | `e00268c` | Entwurfsarbeit plus der umgebungsfaehige Auth-Config-Umbau vom 1. September |
| `worktree/brave-forest-c9d8` | `a2810c7` | Tag-Lieferung: Spec + Umsetzungsplan, **noch nicht gemerged** |

---

## 0. Wie dieses Dokument zu lesen ist

Es beantwortet drei Fragen, die sich nach fünf Entwurfsrunden nicht mehr aus einem einzelnen Dokument beantworten ließen: *Was steht? Was fehlt? In welcher Reihenfolge?*

Es ist bewusst kurz und verweist. Die Wahrheit über einen Bauabschnitt steht immer in seinem eigenen Plan, nie hier.

---

## 1. Der Stand in einem Satz

**Das M1-Fundament trägt; die letzten beiden Tage waren reine Entwurfsarbeit, und die daraus entstandenen Baustellen sind zu null gebaut.**

Belegt: `git diff master designplan -- . ':(exclude)docs'` ist leer. 29 Commits, keine Zeile Code. Auf Platte endet es bei `0021_fallback_inhalte.sql`.

---

## 2. Was gebaut ist und läuft

| Bereich | Stand |
| --- | --- |
| Monorepo, CI, Vercel (`gymodo-web.vercel.app`), AASA-Route | ✅ |
| Migrationen `0001`–`0021`, RLS mit Positiv-, Negativ- und Cross-Tenant-Test je Policy | ✅ |
| Gerätekatalog — `equipment_models`, `equipment_setting_definitions`, `exercises`, `instruction_assets`, `machines`, `machine_tags` | ✅ |
| Trainingsdaten — `workout_sessions`, `workout_sets`, `member_machine_calibrations`, `progression_suggestions` | ✅ |
| Fachschicht `@fitretro/domain`, inkl. deterministischer Progressionsregel | ✅ |
| Sechs Endpoints unter `/api/v1` (Spec 6.3) + Web-Fallback `/t/<token>` | ✅ |
| Trainerportal: Geräte, Modelle, Tags, Medien-Upload | ✅ funktional, **ungestaltet** |
| Testlage: 27 Integrationsdateien, 3 E2E-Dateien; laut `trainerportal-medien` 342 Integrations-, 39 Unit-, 8 E2E-Tests | ✅ grün |

**Der Gerätekatalog ist weiterhin der einzige Bereich, der vollständig trägt** — der Kassensturz aus `2026-08-31-trainerportal-struktur-design.md` §7 gilt unverändert.

---

## 3. Was entworfen, aber nicht gebaut ist

70 Artboards (34 Member, 36 Portal) und fünf Specs stehen. Dahinter:

| Baustelle | Migrationen | Umsetzungsplan | Gebaut |
| --- | --- | --- | --- |
| **Beitritt durch Scannen** — `tag_kind`, `join_studio_by_tag`, Selbstaustritt, Fallback-Erweiterung | `0022`–`0025` | ✅ `2026-09-01-scan-beitritt-datenbank.md`, 5 Aufgaben | ❌ |
| **Tags als Lieferung** — Klartext-Tokenraum, Chargen/Lieferungen/Halde, `inspect_tag`/`bind_tag_to_machine`, Betreiberwerkzeug | `0026`–`0028` | ✅ `2026-09-01-tag-lieferung.md`, 8 Aufgaben — **im Worktree, nicht gemerged** | ❌ |
| **Sucher im Portal** — `getUserMedia` + Decoder | — | ❌ | ❌ |
| **Auth-Umstellung** — OTP → Passwort, Registrierung, Studio-Beitritt | — | ❌ | ❌ |
| **Leute** — Mitglieder und Mitarbeiter | — | ❌ | ❌ |
| **Studio-Einstellungen, Datenschutzgrenze, Überblick** | — | ❌ | ❌ |
| **Kurse** — drei Tabellen, Platzvergabe unter Nebenläufigkeit | — | ❌ nur Vorabnotiz (84 Zeilen) | ❌ |
| **Portal-Frontend nach den 36 Artboards** | — | ❌ | ❌ |
| **iOS Member-App** | — | ❌ | ❌ `apps/` enthält nur `web` |

### Die vier, die am weitesten offen stehen

- **Leute:** `memberships_select_own` erlaubt heute genau die *eigene* Zeile. Ein Trainer kann seine Mitgliederliste **nicht einmal lesen.** Es braucht vier Policies, wo eine steht.
- **Studio-Einstellungen:** `studios` hat `studios_select` und keine Spalte für die Stornofrist. Speichern ist nicht möglich.
- **Datenschutzgrenze:** vier Policies zu ändern, eine Aggregatfunktion zu bauen. Sie schaltet zugleich den *Überblick* frei.
- **Auth:** jeder Entwurf zeigt Passwort (`MemberPasswort`, `MemberRegistrieren`, `PasswortVergessen`, `Verifizieren`). Der Code kennt ausschließlich E-Mail-OTP — `signInWithPassword` kommt im Repo nicht vor.

---

## 4. Die drei Blocker

Keiner davon ist Code.

1. **SMTP-Versand.** ✅ **Weitgehend geloest am 1. September.** Die Organisation `Gymodo` steht auf Pro (Supabase rechnet **pro Organisation** ab — ein Upgrade in einer der drei anderen Organisationen haette nichts bewirkt), und `supabase config push` hat das OTP-Template ins Projekt gebracht: `auth: updated`, Folge-Diff leer. Betreff *„Dein Anmeldecode"*, `{{ .Token }}` statt `{{ .ConfirmationURL }}`, `otp_length` 6.
   **Es fehlt der letzte Beweis:** eine echte Mail mit sechsstelligem Code in einem echten Posteingang. Bis dahin bleibt dieser Punkt offen — lokal ist er gegen Mailpit gefuehrt.
   **Nachtrag, teurer als der Blocker selbst:** `config push` ueberträgt die **gesamte** `[auth]`-Sektion, nicht einzelne Schluessel. `config.toml` trug reine Entwicklungswerte; ein unbesehener Push haette `site_url` der Produktion auf `127.0.0.1` gesetzt, die Bestaetigungspflicht der Mailadresse abgeschaltet und TOTP-MFA deaktiviert. Vier Werte stehen jetzt auf `env()` mit getrennten Dateien (`.env` lokal, `.env.production` fuer den Push). Merke: **`SUPABASE_ENV=production` waehlt `.env.production` nicht aus** — das leistet in Supabases Beispiel dotenvx, nicht die CLI; verlaesslich ist nur eine echte Shell-Variable.

2. **Der Mac.** Die iOS-App existiert nicht als eine Zeile Code. M0 Task 7 (Universal-Link-Validierung) und Task 8 (physischer NFC-Test) warten dort. **Task 8 ist ein Gate:** liest der Tag am echten Gerät nicht zuverlässig, wird das Produkt QR-first statt NFC-first.
3. **`APPLE_TEAM_ID` / `APPLE_BUNDLE_ID`** stehen in Vercel auf Platzhaltern (`ABCDE12345` / `de.fitretro.member`). Muss vor jedem TestFlight-Build weg.

### Das Ungleichgewicht, das die Reihenfolge bestimmt

| | Web-Portal | iOS Member-App |
| --- | --- | --- |
| Design | 36 Artboards ✅ | 34 Artboards ✅ |
| Backend | teils — Katalog ✅, vier Bereiche offen | vollständig für M1 ✅ |
| Frontend-Code | fünf Seiten, ungestaltet | **null** |

Die Member-App ist backendseitig fertig und scheitert nur an Blocker 2 und 3. Das Portal ist umgekehrt: Gerüst da, Backend halb.

---

## 5. Der Fahrplan

### Phase 0 — Entscheiden *(läuft)*

- [x] **SMTP:** Supabase Pro, entschieden und gebucht 1. September (Organisation `Gymodo`)
- [x] **Template ins Projekt gepusht**, per leerem Folge-Diff belegt
- [ ] **Verifizieren**, dass eine echte OTP-Mail mit sechsstelligem Code ankommt
- [ ] **Mac-Übernahme:** wann — und wird vorher NFC oder QR entschieden
- [ ] **Kurse:** Teil von M2 oder vertagt (der größte ungeplante Brocken)

### Phase 1 — Die Tag-Kette schließen

Der einzige Strang, in dem Design, Datenbank und Umsetzungsplan bis zum Ende durchgezogen sind. Die Reihenfolge ist nicht wählbar:

```
Worktree a2810c7 nach designplan mergen
   ↓
0022–0025   scan-beitritt-datenbank.md          5 Aufgaben
   ↓        (tag_kind + Constraint, join_studio_by_tag,
   ↓         Selbstaustritt, Web-Fallback)
   ↓
0026–0028   tag-lieferung.md                    8 Aufgaben
            Testhelfer → createTag-Rückbau → Klartext →
            Chargen → Funktionen → pnpm tags → TagZuweisen → Vorrat
```

`tag-lieferung.md` nennt die Abhängigkeit in seinen Global Constraints selbst: *„Auf Platte muss `0025` liegen, bevor Aufgabe 3 beginnt."*

**Nebengewinn, der die Reihenfolge rechtfertigt:** Aufgabe 7 baut `TagZuweisen` auf ein Token-Textfeld um. Damit steht der Rückfallweg für den Sucher, **bevor** der Sucher gebaut wird — und `einrichtung-am-geraet-design.md` §7 verliert seinen *„einzigen Ausfallpunkt ohne Rückfallweg"*.

### Phase 2 — Portal-Backend-Lücken

Vier Bauabschnitte, **je ein eigener Umsetzungsplan, keiner existiert.** Reihenfolge nach Abhängigkeit:

1. **Auth** — OTP → Passwort, Registrierung, Studio-Beitritt *(braucht Phase 0)*
2. **Leute** — vier Policies statt einer
3. **Studio-Einstellungen** — Spalten am Studio, Stornofrist
4. **Datenschutzgrenze** — vier Policies + Aggregatfunktion → schaltet *Überblick* frei

### Phase 3 — Kurse

Drei Tabellen, Platzvergabe unter Nebenläufigkeit, Endpoints, Server Actions. Heute nur `2026-08-30-kurse-datenmodell.md` als Vorabnotiz.

### Phase 4 — Portal-Frontend

Die 36 Artboards umsetzen, plus **der Sucher** — `getUserMedia` und ein Decoder im Browser, weil Safari `BarcodeDetector` nicht kennt. Der einzige echte Neubau, der nach Phase 1 übrig bleibt.

### Phase 5 — iOS auf dem Mac

M0 Task 7 und 8, danach die 34 Member-Artboards. **Kann ab Phase 1 parallel laufen** — das Backend der Member-App steht.

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
| Stornofrist — Wert offen | trainerportal-struktur §8 | Phase 2.3 |
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

**Der Abstand zwischen Entwurf und Code ist die Quelle dieser Lücken.** Er ist gerade auf 29 Commits gewachsen. Phase 1 schließt ihn für die Tag-Kette; jede weitere Entwurfsrunde vor Phase 1 vergrößert ihn wieder.

---

## 8. Wann dieses Dokument zu aktualisieren ist

Nach jedem abgeschlossenen Bauabschnitt: die Zeile in Abschnitt 3 auf ✅, den Bezugsstand in der Kopftabelle nachziehen, und erledigte Punkte in Abschnitt 6 streichen statt durchzustreichen — die Begründung steht im jeweiligen Plan.
