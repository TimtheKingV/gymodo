# gymodo — Landeseite neu (`/` und `/studios`), Referenz getgpath.com

**Stand:** 3. Oktober 2026
**Status:** Entscheidungen E1–E9 getroffen (Abschnitt 9). **Etappe 1 umgesetzt am 6. Oktober 2026** (7.7/1), die drei App-Screenshots stehen noch aus. Plan für Etappe 1: `docs/superpowers/plans/2026-10-03-landeseite-etappe1.md`.
**Rohdaten:** `docs/superpowers/recherche/2026-10-03-gpath/` (drei Berichte mit allen Texten wörtlich, allen CSS-/JS-Werten, je Section).
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktgrenze, Käufer/Nutzer) und `2026-08-30-designsystem.md` (zitiert als `§n`).

---

## 0. Quellenlage

- **getgpath.com rate-limitiert hart** (HTTP 429, `retry-after: 60`, auch über WebFetch). Live abrufbar war am 03.10. nur der Text der Startseite.
- Rohes HTML/CSS/JS stammt aus der **Wayback Machine, Snapshots vom 13.08.2026** (Startseite, Produktseite, Our Story). Theme damals „Gpath 4.1 BIG BET" bzw. „Copy of Gpath 4.0 NO BDAY SALE" (`role: treatment` → A/B-Test lief).
- **Abweichung zum Brief:** Die Kaufleiste im Snapshot hat **keine** Richtungserkennung, sitzt 10 px vom Rand, `rgba(26,26,26,.8)`, `.4s`, und legt in den Warenkorb **ohne** `return_to`. Die Werte im Brief (Schwelle 4 px/24 px, 1.2rem, `rgba(28,28,30,.72)`, 350/450 ms, drei Merkmale mit Icons, `return_to=/checkout`) stammen also aus dem neueren Live-Theme 73. **Für den Nachbau gelten die Live-Werte aus dem Brief**; der Snapshot liefert den Rest.
- Live am 03.10. (Text): Ansageleiste „20% OFF Sale" mit Countdown, Hero-Button „Shop Sale", Preis ~~549,00 zł~~ 430,00 zł. Am 13.08.: „Free Worldwide Shipping", „Shop Now", 556,00 zł. Gpath dreht also laufend an Angebot und Ansprache, nicht an der Struktur.
- Unbekannt geblieben (liegt in `base.css`/`global.js`, nicht im Snapshot): die Typo-Tokens `type-display/headline/…`, das JS des mobilen Menüs, das Popup-CSS.

---

## 1. Was Gpath macht — Inhalt und Argumentation

### 1.1 Startseite, Reihenfolge = Argumentationskette

| # | Section | Rolle | Kerntext (wörtlich) |
|---|---|---|---|
| 1 | Ansageleiste | Dringlichkeit | „20% OFF Sale – 00d 00h 00m 00s" (live) |
| 2 | Pillen-Header | Dauer-CTA | Home · Our Story · Support · **Shop**-Pille |
| 3 | Hero | **Problem als Imperativ** | „Stop Guessing Your Lifts." / „Finally, a device that turns raw workout metrics into actionable insights." / „Shop Sale" |
| 4 | Stats-Laufband | **Beweis, sofort** | 41 countries · 4000+ lifters · 43 000+ workouts logged · 3 432 232+ reps tracked |
| 5 | Workout Clarity | **Problem → Lösung, gezeigt statt gesagt** | „Train with absolute certainty." / „Turn workout chaos into clear, actionable steps." — 18 Fragepillen („RPE 3?", „Add weight?", „Fatigue?"…) → Feed „Add 2.5 kg · Rest for 90 seconds · Keep this pace · Stop here today" |
| 6 | How it works | **Aufwand wegreden** | 1. Clip it on (one second) · 2. Just lift (silently) · 3. Level up (free app) |
| 7 | CTA | Kaufmoment 1 | „Get Gpath" |
| 8 | Pros use it | **Aspiration + Preisanker** | „Unlock the pro athlete's secret." / „NBA and Champions League pros track velocity, not feelings. We believe this tech shouldn't cost thousands." |
| 9 | Gpath Coach | **Mehrwert über das Gerät hinaus** | „Understand more with Gpath Coach" · 3 Karten: Antworten aus deinen Daten · Trends/Plateaus · Pläne |
| 10 | Checkout-Block | Kaufmoment 2 | „Shop Gpath Pin" ★★★★★ „Rated 4.5 by 4000+ customers" · „Checkout – Preis" |
| 11 | FAQ | **Einwände** | ohne Abo nutzbar? · iOS+Android? · welche Geräte? · für Personal Trainer? (ehrliches „not yet") |
| 12 | Newsletter, Fuß | | + Rabatt-Popup nach 3,5 s (LIFT10, 10 %) |

**Muster:** Problem (Hero) → Beweis (Zahlen) → Problem *erlebbar* (Clarity) → Lösung ist mühelos (3 Schritte) → Kauf → Aspiration/Preisanker → Zusatznutzen → Kauf → Einwände. **Zwei Kaufmomente auf der Startseite, plus Dauer-CTA im Header.** Die Startseite hat *keine* Kaufleiste — die gibt es nur auf der Produktseite.

**Tonalität:** kurz, imperativ, Du-Ansprache (englisch „you"), Versprechen von Gewissheit („absolute certainty", „know exactly what to lift next"), Underdog gegen teure Profitechnik (Our Story: „Fair pricing. Simple data. Built by lifters who use it every day."). Gamification-Vokabular („Level up", „PRs").

### 1.2 Produktseite `/products/gpath-pin`

Kaufbox (10 quadratische Bilder, „NEW", 4,67★ aus 102 Junip-Bewertungen, Trust-Badges *Made in Poland · 2 Year Warranty · 14 Days Returns*) → 4 Kundenvideos „Trusted by 3000+ Lifters" → How it works (mobil Scroll-Snap-Slider) → „Progress you can measure" (4 Metriken + Modal mit 9) → **Vergleich nur nach Kategorie** (Gpath / Training Apps / VBT Devices, 5 Kriterien) → Coach → „3000+ lifters improved their workouts." + 10 Reviews → Specs (8 h Akku, 32 g, 57×30×17 mm, BT 5.0, USB-C, 6-Achsen) → FAQ (10) → Kaufleiste.

### 1.3 Our Story

Philosophie („VBT-Geräte überteuert") → Gründungsgeschichte (zwei Studenten, Garage in Suwałki) → **Timeline mit offen benannten Pivots** (2023 Prototyp … 2025 zweiter Pivot) → Fotogalerie 4:5. Wirkt, weil es Scheitern zeigt.

### 1.4 Was wir *nicht* übernehmen

- **Zahlen ohne Deckung.** „Rated 4.5" mit fünf vollen Sternen; „4000+ lifters" neben „3000+ lifters" auf der Produktseite. Bei uns: § 5 UWG, und es passt nicht zu „keine Behauptung ohne Beleg" aus `marketing/daten` im Schwesterprojekt.
- **Auto-Popup nach 3,5 s** mit Rabattcode gegen E-Mail, ohne Checkbox/Double-Opt-in.
- **Countdown-Rabatt** mit Streichpreis — in DE nur mit niedrigstem Preis der letzten 30 Tage zulässig (§ 11 PAngV). Bei Vorbestellung gibt es keinen Vorpreis → kein Streichpreis.
- **Rechtliche Links hinter einem Dropdown** — Impressum muss „unmittelbar erreichbar" sein (§ 5 DDG).
- Barrierefreiheit: `outline: none` auch bei Fokus, `aria-hidden` auf der sichtbaren Kaufleiste, keine Fokusfallen in Dialogen, Logo als `<h1>`.

---

## 2. Was Gpath macht — Aufbau mobil

Einheit dort: `html { font-size: 62.5% }`, 1 rem = 10 px. Breakpoints 480 · 750 · 768 · 990.

- **Rhythmus:** Schwarz (Hero) → Weiß (Stats) → Weiß mit dunkler Karte (Clarity) → Schwarz (How, CTA) → Weiß (Pros) → Schwarz (Coach) → Bild (Checkout). Der Hell-Dunkel-Wechsel trägt die Gliederung, nicht Linien oder Überschriften.
- **Seitenrand** 15 px mobil (Clarity-Karte), 50 px ab 750 px. Section-Abstände 39–64 px mobil.
- **Typo:** Poppins, Headings Gewicht 500 (nicht fett!), Body 15 px/1.8, Laufweite 0.6 px, Fließtext 75 % Deckkraft. Hero-H1 34 px (44 px ab 750). Section-Titel 30 px (40). Coach-Titel `clamp(26px, 7.2vw, 42px)`, −0.03em.
- **Buttons:** 12 px, Versalien, +.12em, 600, Radius 10 px, min. 47 px hoch; mobil volle Breite bis 320 px.
- **Bildformate:** Hero-Video mobil hochkant (MP4, Poster 750 w), Desktop 3:2-Bild · How it works 4:3 · Pros 3:5 hochkant als Treppe (Höhen 330 px mobil, äußere +14 px, innere +44 px versetzt, Reihe ragt −1.5 rem über den Rand) · Coach-Karten 400×700 · Checkout-Bild 4:5 (2400×3000) · Produkt 1:1 · Story 4:5.
- **Mobil anders:** Hero-Video statt Bild; Hero-Text oben, Button unten (`margin-top: auto`); Clarity zeigt nur 10 von 18 Pillen; How it works auf der Produktseite als Snap-Slider statt 3 Spalten; Specs als 3×2-Grid statt Overlay; Kaufleiste ohne Produktbild.

---

## 3. Was Gpath macht — Bewegung, mit Werten

**Gemeinsame Kurve:** `cubic-bezier(.22,1,.36,1)` (Clarity), Header-Menü `cubic-bezier(.16,1,.3,1)`, Kaufleiste `cubic-bezier(.4,0,.2,1)`.

| Element | Mechanik | Werte |
|---|---|---|
| **Header** | `sticky`, z 500; Pille 54 px, Radius 16 px, Glas `rgba(255,255,255,.78)` + `blur(22px) saturate(1.2)` mobil (`.86`/12 px Desktop), Schatten `0 10px 28px rgba(0,0,0,.12)`. Hero liegt per `margin-top: calc(-1 * var(--header-height))` darunter. Mobilmenü: **die Pille wächst** (`height: calc(54px + var(--menu-dropdown-height))`, negativer `margin-bottom` gegen Layout-Shift) | .34s; Inhalt opacity .22s (Delay .06s), `translateY(-6px)` .28s |
| **Hero-Höhe** | `calc(var(--hero-height-lock, 100svh) - var(--announcement-height))`; JS setzt `--hero-height-lock = innerHeight` **einmal**, danach nur bei `orientationchange` (+250 ms). `resize` bewusst ignoriert | — |
| **Hero-Video** | nur `max-width: 989px` ∧ kein reduced-motion ∧ sichtbar (IO `threshold .15`); erstes Mal `load()`; Neuprüfung bei `visibilitychange`/`pageshow`/`canplay` | Abdunklung oben 0→.85 (10 %)→.55 (24 %)→.25 (38 %)→.08 (50 %)→0 (62 %), unten .55→0 (12 %) |
| **Stats-Laufband** | Inhalt 2× (zweite Hälfte `aria-hidden`), `translate3d(0 → -50%)` linear endlos; IO (`rootMargin 100px 0px`) pausiert außerhalb | 45 s, mobil 36 s; reduced-motion: steht |
| **Clarity-Schalter** | **Nicht klickbar, rein scroll-gesteuert und umkehrbar.** 1-px-Sonde in Kartenmitte, IO `rootMargin '0px 0px -42% 0px'`: „With", solange die Kartenmitte zwischen Oberkante und 58 % Viewport liegt | Pillen fliegen weg: `translate(--sx,--sy) scale(.55) rotate(±24–32°)`, opacity 0; transform .55s, opacity .4s, **gestaffelte Delays 0–140 ms** (Rückweg ohne Delay). Hintergrund `blur(6px) saturate(.75) scale(1.08)` → scharf .45s. Schalter Rot→Grün .55s, Knopf gleitet über `left` |
| **Clarity-Feed** | 4 Einträge, Takt 1100 ms halten + 480 ms gleiten, Start nach 120 ms; IO (`rootMargin 20%`) startet/stoppt | current `scale 1.12`; prev/next ±4.6 rem (mobil 3.9), `scale .62`, opacity .28 |
| **Coach-Overlay** | Modal in `body` verschoben, vollflächig schwarz, z 10000; `html.gpath-coach-modal-open` → `overflow:hidden` + Header und `#md-sticky-atc` `visibility:hidden`. Schließen: X, Hintergrund, Escape → Video pausiert, `currentTime=0`, Fokus zurück | keine Ein-/Ausblendung |
| **Kaufleiste (Live, Brief)** | erscheint nach dem Haupt-Kaufbutton; runter > 4 px → weg, hoch → da; < 24 px unter der Schwelle bleibt sie; weg bei sichtbarem Footer; rAF-gedrosselt; Schwelle neu bei `resize`/`load` | `fixed; bottom/left/right 1.2rem; max-width 42rem` (Desktop 44rem/1.6rem), `rgba(28,28,30,.72)` Glas, `translateY(110%)→0` 350 ms `cubic-bezier(.4,0,.2,1)`, Erst-Einblendung 450 ms |
| **Produkt-Slider** | Scroll-Snap, ein Slide pro Breite, runde Nummern-Indikatoren (50 px), aktive Slide nach Scroll-Ende +150 ms erkannt, nur deren Video spielt | — |
| **FAQ** | natives `details/summary`, ohne Höhenanimation | — |

**Was die mobile Wirkung ausmacht:** genau *eine* große, scroll-gesteuerte Inszenierung (Clarity); alles andere ist ruhig. Dazu der Hero, der beim Scrollen nicht springt, und der Hell-Dunkel-Takt.

---

## 4. Übertragung auf gymodo — Grundsätze

1. **Unser Designsystem bleibt, Gpaths Bauplan wird übernommen.** Kein Poppins, kein Blau, keine Violett-Verläufe. Wir übernehmen Reihenfolge, Rhythmus, Mechanik und Maße, nicht die Optik: `bg #0A0B0D`, Akzent `#D4FF3F`, Systemschrift, Black-Versalien mit negativer Laufweite (§3). Den Hell-Dunkel-Takt ersetzen wir durch Flächenstufen (`bg` ↔ `surface`) und vollflächige Bild-/Video-Sections — eine helle Section wäre ein Bruch mit „Hallenboden" (§1). → **Entscheidung E2.**
2. **Eine Akzentfläche — je Bildschirm, nicht je Seite.** Eine lange Landeseite hat mehrere Kaufmomente. Regel: Im Viewport ist zu jedem Zeitpunkt höchstens eine Akzentfläche sichtbar. Die Kaufleiste erfüllt das von selbst, weil sie erst erscheint, wenn der Hero-Button weg ist, und beim Footer verschwindet. Dafür muss `e2e/helpers/abnahme.ts → akzentflaechen()` auf „im Viewport" eingeschränkt werden (heute zählt es die ganze Seite).
3. **Texte nach §10:** Du-Form, keine Ausrufezeichen, kein Motivationston, „Vorschlag", nie „Du solltest". Gpaths Imperativ-Claims („Stop Guessing") passen — Gpaths Gewissheitsversprechen („absolute certainty") nicht.
4. **Produktgrenze bleibt sichtbar und wahr.** Solange der Sensor nicht ausgeliefert ist, gilt „gymodo misst nichts" unverändert für die App. Mit Sensor wird der Satz **produktbezogen**: „Die App misst nichts. Angezeigt wird, was du bestätigst — oder was der gymodo-Sensor an deinem Gerät gezählt hat." → E1/E5. Bis dahin steht im Sensorteil der Seite ausdrücklich „in Entwicklung".
5. **Nur belegbare Zahlen.** Das Laufband zeigt echte Werte aus der Datenbank (Studios, Geräte mit Tag, bestätigte Sätze), serverseitig gezählt und stündlich neu berechnet — oder es entfällt, bis die Zahlen tragen. Keine Sterne, bis es echte Bewertungen gibt.
6. **Kein Popup, kein Countdown.** Warteliste/Newsletter nur als Section mit Checkbox und Double-Opt-in.
7. **Android:** Die App gibt es nur für iOS; der Web-Fallback `/t/[token]` trägt Android. Wir versprechen nicht „iOS and Android".

> **Nachtrag 10. Oktober 2026:** Der Wortlaut ist entschieden: der kanonische Satz aus Designsystem §10 statt des Vorschlags hier. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.

---

## 5. Übertragung — `/` (Mitglieder und Endnutzer)

Ziel: App laden (heute); Sensor vorbestellen (später). Gegenüber heute fällt der Satz „im Web gibt es nichts für dich zu tun" weg — die Seite *ist* jetzt für Mitglieder. Der Trainer-Zugang wandert in den Kopf („Für Studios" + „Anmelden").

Platzhaltertexte, Stand Entwurf; `[prüfen]` = Aussage muss vor Veröffentlichung belegt sein.

| Gpath | gymodo `/` | Entwurf |
|---|---|---|
| Ansageleiste | entfällt (oder später: „Sensor vorbestellen — Auslieferung ab [Monat]") | — |
| Pillen-Header | `Kopf`: Wortmarke · „Für Studios" · „Anmelden" · CTA-Pille „App laden" | — |
| Hero (Video mobil) | **Hero**: Hochkant-Video eines Taps am Gerät (Handy an Tag, Werte erscheinen), mobil Text oben, Button unten | **H1:** „Nie wieder raten am Gerät." · **Vorspann:** „Halte dein iPhone an das Gerät. Du siehst deine Einstellung, deine letzten Sätze und die Einweisung deines Studios." · **Button:** „App laden" · Nebenlink: „Wie das funktioniert" |
| Stats-Laufband | **Laufband** mit Live-Zahlen | „[n] Studios · [n] Geräte mit Tag · [n] bestätigte Sätze" — oder bis dahin Fakten: „Ein Tap statt Zettel · Kein Konto zum Ansehen · Funktioniert an jedem Gerät deines Studios" `[prüfen]` |
| Workout Clarity | **„Ohne gymodo / Mit gymodo"** — unser stärkstes Bild, weil das Problem unseres ist | Titel: „Weißt du noch, wie du das Gerät eingestellt hast?" · Pillen ohne: „Sitz 4 oder 5?", „Letztes Mal 40 oder 45 kg?", „Wie ging die Übung?", „Wo ist der Zettel?", „3 oder 4 Sätze?", „Lehne verstellt?", „Trainer gerade frei?", „Notizen-App?" · Feed mit: „Sitz 5 · Lehne 3", „Zuletzt 42,5 kg × 10", „Vorschlag +2,5 kg", „Einweisung ansehen" |
| How it works | **So geht's** (3 Schritte, Hochkant-Screenshots) | 1. **Tippen** — „Halte dein iPhone an den Tag am Gerät." · 2. **Trainieren** — „Deine Einstellung steht schon da. Du bestätigst nur deine Sätze." · 3. **Weiterkommen** — „Verlauf und Ziele zeigen dir, wo du stehst." |
| CTA | CTA „App laden" | — |
| Pros use it | **Brücke zum Studio** (statt Profi-Aspiration — unser Beweis ist das eigene Studio) | „Dein Studio ist noch nicht dabei?" · „gymodo kommt mit deinem Studio. Zeig ihm diese Seite." · Button: „Studio empfehlen" (Share-Sheet mit Link auf `/studios`) |
| Gpath Coach (+ Video-Overlay) | **Verlauf & Ziele** — Video-Overlay mit App-Rundgang. *Kein* KI-Coach, keine Empfehlung (§10) | „Dein Fortschritt, ohne Rechnerei." · Karten: „Jedes Gerät mit Verlauf", „Ziele, die du selbst setzt", „Kurse buchen am selben Ort" · Button „Rundgang ansehen" |
| Checkout-Block | **Sensor** (erst wenn E1 entschieden) | „Der gymodo-Sensor. Zählt mit, damit du nur noch trainierst." · „In Entwicklung" · Button: „Vorbestellen – [Preis] €" bzw. „Auf die Warteliste" |
| FAQ | **Fragen** | Kostet die App etwas? `[offen]` · Brauche ich ein Studio mit gymodo? · Gibt es gymodo für Android? (Web-Ansicht per Tag ja, App nein) · Was misst gymodo? (Produktgrenze) · Wo liegen meine Daten? `[prüfen]` · Wann kommt der Sensor? |
| Newsletter | **Warteliste** (Checkbox + Double-Opt-in) | — |
| Fuß | Impressum · Datenschutz · (mit Verkauf: AGB · Widerruf · Versand) offen sichtbar, Produktgrenze | — |
| Kaufleiste | **Kaufleiste** ab Hero-Button | Titel „gymodo" · Merkmale „Tap am Gerät · Deine Werte · Für iPhone" · Button „App laden"; mit Sensor: „Sensor vorbestellen – [Preis] €" |
| Our Story | später `/geschichte` — wir haben selbst eine Retrofit-Geschichte | — |

## 6. Übertragung — `/studios` (Studios, B2B)

Käufer ist der Betreiber (M1 §2). Kernargumente aus der M1-Spec: **Retrofit statt Geräteinvestition**, weniger Personalaufwand, sehen, was genutzt wird. Ziel: Studio anlegen oder Gespräch.

| Gpath | gymodo `/studios` | Entwurf |
|---|---|---|
| Hero | Hero, Video: Mitglied tippt, Einweisung läuft | **H1:** „Jedes Gerät erklärt sich selbst." · **Vorspann:** „Ein Tag an jedem Gerät. Deine Mitglieder sehen die Einweisung und ihre eigenen Einstellwerte — ohne an der Theke zu fragen." · Button „Studio anlegen" · Nebenaktion „Gespräch vereinbaren" |
| Stats | Laufband | wie `/`, oder: „Klebt auf vorhandene Geräte · Einrichtung am Gerät · Kein Umbau" `[prüfen]` |
| Clarity | **„Ohne gymodo / Mit gymodo" aus Betreibersicht** | ohne: „Wie stellt man das ein?", „Trainer unterbrochen", „Einweisung verpasst", „Gerät falsch eingestellt", „Wird das überhaupt genutzt?" · mit: „Einweisungsvideo am Gerät", „Einstellwerte je Mitglied", „Meldung: Beinpresse 2", „Kurs: 3 Plätze frei" |
| How it works | 3 Schritte | 1. **Tags kleben** — „Wir liefern die Tags, du klebst sie ans Gerät." `[Tag-Lieferung prüfen]` · 2. **Katalog pflegen** — „Video und Einstellhinweise im Portal." · 3. **Mitglieder tippen** — „Beitritt per Aushang oder Tag, ohne Einladungsliste." |
| Pros use it | **Vergleich nach Kategorie** (wie Gpaths Produktseite, keine Wettbewerbernamen) | Spalten: gymodo · Sensor-Gerätepark · Aushang/Papier · Zeilen: ohne neue Geräte · Werte je Mitglied · Einweisung am Gerät · Nutzung sichtbar · Investition `[jede Zelle belegen]` |
| Coach | **Portal-Rundgang** (Video-Overlay) | „Was dein Studio sieht": Überblick, Geräte, Kurse, Mitarbeiter |
| Checkout | **Preise** (E4) | bis zum Preismodell: „Preis auf Anfrage" + Gespräch; danach Stripe-Billing-Paket |
| FAQ | Fragen der Betreiber | Was kostet ein Tag? · Brauchen Mitglieder ein iPhone? · Was passiert mit Gerätedaten? · Kündigung? · Wer pflegt die Videos? · Haftung für Einweisungsinhalte? (M1 §13.5) |
| — | **Kontakt** | Formular: Studio, Name, E-Mail, Telefon optional, Mitgliederzahl, Nachricht |
| Kaufleiste | Kaufleiste | „gymodo für Studios" · „Retrofit · Einweisung am Gerät · Portal" · Button „Studio anlegen" |
| Fuß | wie `/` | B2B-Produktgrenze (Pflichttext §10) |

**Die beiden Seiten stützen sich gegenseitig:** `/` → „Studio empfehlen" (Teilen-Link mit `?von=mitglied`) → `/studios`; `/studios` → „Deine Mitglieder laden die App" → `/`. Der Parameter wird nur als Zähler gespeichert, ohne Personenbezug.

---

## 7. Technischer Plan (`apps/web`)

Rahmen: Next.js 16 (Build mit webpack, seit 6. Oktober auf `master`) / React 19, CSS Modules, Tokens aus `globals.css`, **keine Bild-/Animationsbibliothek**. Einzige neue Abhängigkeit: `stripe` (Server-SDK, nur serverseitig, landet nicht im Client-Bundle). Kein `@stripe/stripe-js`, denn wir leiten auf den gehosteten Checkout weiter.

### 7.1 Routen

```
app/page.tsx                 Wurzel: ohne Sitzung → <Startseite />; mit Sitzung unverändert (Portal-Redirect / Mitgliedsbildschirm)
app/studios/page.tsx         öffentlich, statisch (revalidate 3600 für Zahlen)
app/studios/kontakt/actions.ts   Server Action: Anfrage speichern
app/api/stripe/webhook/route.ts  runtime "nodejs", Rohkörper per req.text(), Signatur prüfen
app/kauf/danke/page.tsx      success_url (liest session_id, zeigt Bestellnummer)
app/(rechtliches)/impressum, datenschutz, agb, widerruf, versand
```

`/` ruft weiter `auth.getUser()` auf und bleibt dynamisch. Die Landeseite selbst ist eine Server Component ohne Datenabhängigkeit außer den Laufbandzahlen. Die Zahlen kommen aus `unstable_cache` (revalidate 3600; vor Etappe 3 gegen das Caching von Next 16 prüfen) über eine `security definer`-Funktion, die nur Summen liefert. `/studios` existiert heute nicht; `/api/v1/studios` ist API und kollidiert nicht.

### 7.2 Bausteine — `app/landung/`

Eigener Ordner neben `einstieg/` (die Landeseite ist weder Einstieg noch Schreibtisch, siehe Kommentar in `landeseite.module.css`).

| Baustein | Art | Kern |
|---|---|---|
| `Kopf.tsx` | Client (nur Menü) | sticky Pille 54 px, Radius 16, Glas auf `bg`-Basis (`rgba(10,11,13,.72)` + `backdrop-filter: blur(22px) saturate(1.2)`), `@supports not (backdrop-filter)` und `prefers-reduced-transparency: reduce` → `surface` deckend. Mobilmenü als wachsende Pille, **aber über `clip-path`, nicht `height`**: das Menü liegt fertig ausgelegt absolut unter der Pille und wird von `inset(0 0 calc(100% - 54px) 0 round 16px)` auf `inset(0 round 16px)` aufgezogen — kein Layout pro Frame, kein negativer `margin-bottom` gegen Verschiebung. 240 ms `var(--ease-out)` auf, 180 ms zu, gleicher Weg zurück; Menüeinträge `opacity` + `translateY(-6px)` 200 ms, 40 ms später. CSS-Transition an `data-offen`, damit Auf/Zu mitten im Lauf umkehrt. `aria-expanded`, Escape schließt, Fokus zurück auf den Knopf. **Kein `ResizeObserver`:** `--kopf-hoehe` ist eine CSS-Konstante, **62 px** (8 px Abstand oben + 54 px Pille; sticky `top: 8px` endet ebenfalls bei 62), weil die Pille feste Pixelhöhe hat. **Etappe 1 ohne Menü und ohne CTA-Pille:** „Für Studios“ hat bis Etappe 2 kein Ziel, und „App laden“ im Kopf wäre neben dem Hero-Knopf eine zweite Akzentfläche (§4.2). Der Kopf zeigt Wortmarke + „Anmelden“ (Nebenaktion) |
| `Held.tsx` | Server; Video-Teil Client | Höhe `min-height: 100vh; min-height: 100svh`. **Kein JS-Höhenschloss:** `svh` ist die kleine Viewporthöhe und ändert sich beim Ein-/Ausfahren der Safari-Leiste nicht — genau das, was Gpaths `--hero-height-lock` von Hand nachbaut (dort zusätzlich wegen der Ansageleiste, die wir nicht haben). Keine Einblendanimation. Video (E6: optionale Prop) nur bei `(max-width: 989px)` ∧ `!prefers-reduced-motion` ∧ sichtbar (IO .15), sonst bleibt das Poster (`next/image priority`). **Pause-Knopf** sichtbar, sobald ein Video läuft (WCAG 2.2.2, Schleife > 5 s) |
| `Laufband.tsx` | Server + CSS | **Etappe 1 ruhend (E7):** statische, umbrechende Liste. Ab Etappe 3 Prop `laufend`: Inhalt 2×, zweite Hälfte `aria-hidden`; `@keyframes` `translate3d(-50%)` `linear` 36 s mobil / 45 s (CSS-Animation, läuft abseits des Hauptthreads); Pause per IO außerhalb des Viewports **und ein sichtbarer Pause-Knopf** (WCAG 2.2.2: läuft > 5 s neben anderem Inhalt; Gpath hat keinen). reduced-motion → die ruhende Liste |
| `OhneMit.tsx` | Client | Gpaths Clarity, die eine Inszenierung der Seite. Interaktionsmodell siehe 7.2.2 (Prototyp-Entscheid). Gemeinsam für alle Varianten: Pillen fliegen über `transform` (`translate(--sx,--sy) scale(.55) rotate(±24–32°)`) + `opacity` als **CSS-Transition, nicht Keyframes** — Hin- und Rückweg kehren mitten im Flug um. Hinweg `transform` 550 ms / `opacity` 400 ms `var(--ease-out)`, Staffel 0–140 ms (≈ 15 ms je Pille); Rückweg ohne Staffel. Mobil 10 Pillen, Positionen als Inline-Transform je Pille, nicht als Variable am Elternelement (sonst Stilneuberechnung aller Kinder). **Unschärfe nicht animieren:** zwei gestapelte Hintergrundebenen, eine statisch `blur(6px) saturate(.75) scale(1.08)`, eine scharf, Überblendung nur über `opacity` 450 ms — Gpath animiert `filter` auf einer großen Fläche, das kostet Paint in jedem Frame. Schalterknopf über `translateX`, nicht `left`; Spur aus `--line` → `--accent`. Feed: 4 Einträge, halten 1100 ms, gleiten 480 ms `var(--ease-in-out)` (Bewegung auf der Fläche, kein Ein-/Austritt). **Aktueller Eintrag in Originalgröße, Nachbarn `scale(.55)`** statt Gpaths aktuell `scale(1.12)` — hochskalierter Text wird unscharf. Feed läuft **einen Durchgang** und steht dann auf dem letzten Eintrag; „Ohne“ stoppt ihn (WCAG 2.2.2: der Schalter ist der Stopp-Mechanismus). reduced-motion: Zustandswechsel ohne Flug, Feed als stille Liste aller vier Einträge (§6) |
| `Schritte.tsx` | Server + kleiner Client-Teil | `<ol>`, mobil Scroll-Snap-Slider (wie Gpath-Produktseite) mit Nummern-Indikatoren 44 px (§4 Trefferfläche), Desktop 3 Spalten. Keine eigene Animation — das native Scrollen liefert Impuls und Einrasten. Aktiver Indikator per IO je Folie (`threshold .6`) statt Gpaths „Scroll-Ende + 150 ms“-Timer; Tipp auf Indikator `scrollIntoView({ behavior })` mit `auto` bei reduced-motion |
| `VideoOverlay.tsx` | Client, **nicht in Etappe 1** (E6) | natives `<dialog>` mit `showModal()` → Fokusfalle, Escape und `inert` für den Rest gibt es gratis. Setzt `data-overlay-offen` auf `<html>`; Kopf und Kaufleiste blenden darüber aus. `object-fit: contain`, nicht `cover` |
| `Fragen.tsx` | Server | `details/summary`, Antworten als `<p>`; `FAQPage`-JSON-LD. Keine Höhenanimation (wie Gpath); nur der Pfeil dreht wie `.nochZuTunKopf::after` im Portal, 160 ms `ease-out` |
| `Kaufleiste.tsx` | Client | siehe 7.3 |
| `Fuss.tsx` | Server | Rechtslinks offen, Produktgrenze |

#### 7.2.1 Bewegung — Prüfung mit `apple-design` und `animate` (3. Oktober)

- **Kurven als Tokens in `globals.css`**, nicht als Literale je Baustein (heute gibt es keine): `--ease-out: cubic-bezier(.23,1,.32,1)` (ersetzt Gpaths `.22,1,.36,1` und `.16,1,.3,1`, praktisch gleich), `--ease-in-out: cubic-bezier(.77,0,.175,1)` (Bewegung auf der Fläche), `--ease-drawer: cubic-bezier(.32,.72,0,1)` (Kaufleiste). **Gpaths `cubic-bezier(.4,0,.2,1)` entfällt** — die Material-Standardkurve beginnt zu träge für eine Leiste, die auf Scrollrichtung reagiert.
- **reduced-motion = Zustandswechsel** (Designsystem §6). Die globale Regel in `globals.css` (`transition-/animation-duration: .01ms !important`) bleibt und gilt auch hier; die Bausteine sehen keine eigenen „sanfteren“ Ersatzanimationen vor, die diese Regel ohnehin überschreiben würde. Information geht dabei nie verloren (Feed als Liste, Laufband als Liste, Video als Poster).
- **Unterbrechbarkeit:** Alles, was der Nutzer mehrfach in kurzer Folge auslöst (Menü, Kaufleiste, Ohne/Mit), läuft über **CSS-Transitions an einem Datenattribut** — sie setzen vom aktuellen Wert aus neu an. Keyframes nur für Endlosbewegung (Laufband ab Etappe 3). Keine Bewegungsbibliothek; nichts hier ist gestengesteuert mit Freigabegeschwindigkeit, also keine Federn nötig.
- **Nur `transform`, `opacity`, `clip-path`.** Kein `height` (Menü), kein `left` (Schalter), kein animiertes `filter` (Ohne/Mit).
- **Material:** Glas nur für Kopf und Kaufleiste, nie Glas auf Glas (Menü öffnet in derselben Pille). `prefers-reduced-transparency: reduce` und `prefers-contrast: more` → deckende `surface` mit `--line`-Rahmen.
- **Keine Einblendanimationen beim Scrollen** (kein „fade-up“ je Section). Gpaths Ruhe außerhalb der einen Inszenierung ist Teil der Wirkung (§3, Schluss).

#### 7.2.2 Ohne/Mit — Interaktionsmodell

**Entschieden: „Schwelle“** (E9, Prototyp-Vergleich am 3. Oktober gegen „Bühne“ — Abschnitt klebt, Scrollweg steuert direkt — und „Tippen“ — nur der Schalter).

- **Auslöser:** 1-px-Sonde in der Kartenmitte, IO `rootMargin: 0px 0px -42% 0px`. „Mit“, solange die Sonde schneidet (Kartenmitte zwischen Oberkante und 58 % Viewport), sonst „Ohne“. Umkehrbar in beide Richtungen.
- **Tippen übersteuert:** Der Schalter (`button role="switch"`, `aria-checked`) setzt den Zustand von Hand und schaltet die Sonde ab, **bis die Karte den Viewport ganz verlassen hat** (zweiter IO auf der Karte); danach übernimmt wieder der Scroll. Ohne diese Regel kippte die Sonde den getippten Zustand beim nächsten Scrollpixel zurück.
- **Logik als reine Funktion** `ohneMitZustand(vorher, ereignis)` in `ohnemit.logik.ts` (Ereignisse: `sonde`, `tipp`, `karteWeg`), mit Vitest — wie die Kaufleiste.
- **Pillenflug:** Richtung weg von der Bühnenmitte, Weite 160 px waagrecht / 120 px senkrecht, Drehung abwechselnd ±24–32°, Werte als Inline-Stil je Pille. Zeiten wie in der Tabelle (550/400 ms `--ease-out`, Staffel 15 ms je Pille, zurück ohne Staffel).
- **Feed:** startet 120 ms nach „Mit“, ein Durchgang (halten 1100 ms, gleiten 480 ms), steht dann auf „Einweisung ansehen“; „Ohne“ stoppt und setzt nach dem Rückflug auf den ersten Eintrag zurück.
- **Schalter:** 60 × 36 px, Trefferfläche per `::before` auf 46 px erweitert (§4). Knopf 28 px, `translateX(24px)` 300 ms `--ease-out`, Druckrückmeldung `scale(.92)` auf `:active`. Spur „Ohne“ `--surface-raised`, „Mit“ **`--text` mit Knopf in `--bg` — nicht `--accent`**: der Akzent gehört der Hauptaktion (§2), und `akzentflaechen()` zählte die Spur sonst als zweite Fläche. Beschriftung „Ohne Gymtavo“ / „Mit Gymtavo“ links und rechts, die aktive Seite in `--text`, die andere in `--text-faint` (nur Zustandsanzeige, die Information steht im Schalter).
- **Hinweiszeile** unter dem Schalter: „Scroll, oder tipp auf den Schalter.“ in `--text-muted`.

Typo: Hero-H1 nach dem vorhandenen `.titel` (Black, Versalien, −0.045em), mobil `clamp(44px, 13vw, 92px)`. Buttons nach §4: Hauptaktion 64 px/Radius 16 statt Gpaths 47 px/10.

### 7.3 Kaufleiste — wiederverwendbar

```tsx
<Kaufleiste
  anker="held-aktion"            // id des Haupt-CTA; Leiste erscheint, wenn dieser oben raus ist
  verdecker={["landung-cta", "landung-fuss"]}  // weicht, solange eines davon sichtbar ist
  titel="gymodo"
  merkmale={["Tap am Gerät", "Deine Werte", "Für iPhone"]}
  bild={{ src, alt }}            // nur ≥ 990 px
  preis={{ betrag: 7900, alt?: undefined }}   // Cent; alt nur mit 30-Tage-Beleg (PAngV)
  aktion={{ art: "link", href: APP_STORE_URL, text: "App laden" }}
       // | { art: "formular", action: sensorKaufen, text: "Vorbestellen" }
/>
```

**Logik** — reine Funktion `naechsterZustand(vorher, messung)` in `kaufleiste.logik.ts`, mit Vitest testbar (die Repo-Konvention „testgetrieben" gilt):

- `ankerVorbei` per **IntersectionObserver** auf den Anker (`rootMargin: -${kopfHoehe}px 0px 0px 0px`; vorbei = nicht schneidend ∧ `boundingClientRect.top < 0`). Ersetzt Gpaths Messung in jedem Frame.
- `verdeckt` per IO auf alle `verdecker` (`threshold: 0.15`), wahr, solange mindestens einer schneidet.
- Richtung: `scroll`-Listener (`passive`), rAF-gedrosselt, `y` auf `[0, scrollHöhe − Viewport]` begrenzt (iOS-Gummiband am Rand liefert sonst negative Werte und kippt die Richtung). Richtung wechselt erst nach **12 px Weg am Stück** in die neue Richtung (Hysterese statt Gpaths 4 px je Frame — bei 120 Hz und Impulsscrollen flackert die Leiste sonst am Umkehrpunkt).
- **Konkurrenten statt nur Fuß:** `ende` wird zu `verdecker: string[]` — ids aller Elemente, bei deren Sichtbarkeit die Leiste weicht: der Fuß **und jede weitere Hauptaktion** (CTA-Section „App laden“ nach „So geht's“). Sonst stehen dort zwei Akzentflächen im Viewport (Regel §4.2).
- **Fokus hält die Leiste:** Liegt der Fokus in der Leiste (`:focus-within`), bleibt sie sichtbar, auch beim Runterscrollen per Tastatur — sonst verschwände das fokussierte Element unter `inert`.
- Sichtbar = `ankerVorbei ∧ ¬verdeckt ∧ (fokusDrin ∨ richtung = hoch ∨ y − ankerUnterkante < 24)`.
- `resize`/`load`: nichts neu messen; `kopfHoehe` ist eine CSS-Konstante, die IOs rechnen selbst.

**Darstellung** (Live-Werte aus dem Brief, auf unsere Tokens übertragen):
`position: fixed; left/right: 1.2rem; bottom: calc(1.2rem + env(safe-area-inset-bottom)); max-width: 42rem; margin-inline: auto` (≥ 990 px: 44rem/1.6rem). Glas `rgba(20,22,26,.72)` (= `surface` mit Deckkraft) + `blur(20px)`, Rahmen 1 px `--line`, Radius 20 px. Versteckt `translateY(calc(100% + 1.2rem + env(safe-area-inset-bottom)))` — Gpaths `110%` reicht bei Randabstand plus Safe Area nicht ganz aus dem Bild. **Eine** Transition für alle Wechsel: Einblenden 240 ms `var(--ease-drawer)`, Ausblenden 200 ms auf demselben Weg nach unten. **Keine eigene Erst-Einblendung als Keyframe** (Gpath 450 ms): Keyframes setzen bei Unterbrechung auf null zurück, und genau beim ersten Erscheinen kehrt der Nutzer oft gleich wieder um. Die Leiste wird einmal pro Besuch oft ein- und ausgeblendet (Größenordnung zehnmal), daher unter 300 ms. reduced-motion → Zustandswechsel (7.2.1).
**Barrierefreiheit:** versteckt = `inert` + `aria-hidden` (beides, nicht nur `aria-hidden` wie Gpath); als `<aside aria-label="Kaufen">`. Kollidiert nie mit dem Overlay (`html[data-overlay-offen] .kaufleiste { visibility: hidden }`).
**Preis-Synchronität:** Hauptpreis und Leiste lesen denselben Server-Wert (7.4). Gpath hält ihn nicht synchron; der Streichpreis steht dort im DOM als „0,00 zł".

### 7.4 Stripe

**Gemeinsam:** `lib/stripe/server.ts` (`import "server-only"`, `new Stripe(requiredEnv("STRIPE_SECRET_KEY"))`). Env: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PREIS_SENSOR`, `STRIPE_PREIS_STUDIO_*`, `NEXT_PUBLIC_APP_STORE_URL`. Getrennte Test- und Live-Keys je Vercel-Umgebung (Preview = Test).
**Preise kommen aus Stripe**, nicht aus Literalen: `preisLesen(priceId)` mit `unstable_cache` (revalidate 3600). Angezeigt wird brutto in EUR mit „inkl. MwSt., zzgl. Versand" (PAngV).

**Sensor → gehosteter Checkout** (Server Action `sensorKaufen`):
```ts
stripe.checkout.sessions.create({
  mode: "payment",
  line_items: [{ price: STRIPE_PREIS_SENSOR, quantity: 1, adjustable_quantity: { enabled: true, maximum: 3 } }],
  shipping_address_collection: { allowed_countries: ["DE", "AT"] },
  shipping_options: [{ shipping_rate: STRIPE_VERSAND_DE }],
  automatic_tax: { enabled: true },
  consent_collection: { terms_of_service: "required" },   // AGB + Widerruf auf der Kasse
  custom_text: { submit: { message: "Voraussichtliche Auslieferung: [Monat]" } },
  locale: "de",
  success_url: `${origin}/kauf/danke?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${origin}/#sensor`,
});
redirect(session.url);
```
Die Kaufleiste ist dann ein `<form action={sensorKaufen}>` und führt ohne Warenkorb direkt zur Kasse, wie bei Gpath (`return_to=/checkout`).
**Vorbestellung:** Eine Kartenautorisierung verfällt nach 7 Tagen, eine Reservierung per `capture_method: manual` taugt also nicht für Wochen Vorlauf. Optionen: (a) sofort abbuchen, Lieferzeit klar nennen; (b) `mode: "setup"` (Zahlungsmittel speichern, beim Versand abbuchen); (c) nur Warteliste. → **E1.**

**Studiomodul → Stripe Billing:**
- Kauf aus dem Portal (eingeloggt, Rolle `owner`): Server Action erstellt bzw. liest `stripe_customer_id` des Studios und dann `checkout.sessions.create({ mode: "subscription", customer, client_reference_id: studio_id, subscription_data: { metadata: { studio_id } }, tax_id_collection: { enabled: true }, automatic_tax, billing_address_collection: "required" })`.
- Verwaltung: `billingPortal.sessions.create({ customer, return_url: /portal/[studioId]/einstellungen })` für Rechnungen, Zahlungsmittel und Kündigung.
- `/studios` → „Studio anlegen" → `/registrieren?weiter=/portal` → im Portal der Abschnitt „Abo". Solange das Preismodell fehlt (M1 §13.1), endet `/studios` beim Kontaktformular.

**Webhook** `app/api/stripe/webhook/route.ts`, `stripe.webhooks.constructEvent(await req.text(), sig, secret)`, idempotent über `event.id`:
- `checkout.session.completed` (payment) → `bestellungen` anlegen.
- `checkout.session.completed` (subscription), `customer.subscription.created|updated|deleted`, `invoice.payment_failed` → `studio_abos` upsert.
- Schreiben mit Service-Role; der Client schreibt nie.

**Migrationen** (fortlaufend ab der nächsten freien Nummer, RLS an; `0046` ist seit 6. Oktober durch `0046_belastung_umfang.sql` belegt, die Nummern unten verschieben sich):
- `0046_stripe_kunden_und_abos.sql`
  - `studios.stripe_customer_id text unique`
  - `studio_abos` (`studio_id` pk/fk, `stripe_subscription_id`, `status`, `price_id`, `aktuelle_periode_ende`, `kuendigung_zum`), select nur für Mitarbeiter des Studios
  - `stripe_ereignisse` (`event_id` pk, für Idempotenz)
- `0047_bestellungen.sql`
  - `bestellungen` (`id`, `stripe_session_id unique`, `email`, `betrag_cent`, `waehrung`, `lieferadresse jsonb`, `status` [`bezahlt`/`versendet`/`erstattet`], `angelegt`)
  - keine Policies für `authenticated`, gelesen wird per Service-Role bzw. später über eine Admin-Ansicht
- `0048_kontaktanfragen.sql`: `insert` nur über die Server Action (Service-Role), Rate-Limit über IP-Hash.

Mails: anfangs die **Stripe-Belege** (Kaufbeleg, Rechnung); eigene Versandmail erst mit dem ersten Versand.

### 7.5 Rechtliches vor dem ersten Verkauf (keine Rechtsberatung, Checkliste)

- Impressum, Datenschutz (Stripe als Empfänger, Video-Hosting), AGB, Widerrufsbelehrung + Muster-Widerrufsformular (Sensor = Fernabsatz, 14 Tage), Versandbedingungen, Lieferzeit bei Vorbestellung.
- Button-Lösung § 312j BGB: Den Kauf-Knopf beschriftet Stripe („Bezahlen"/„Kaufen"). Prüfen, ob das genügt, sonst `submit_type` wählen.
- Streichpreise nur nach § 11 PAngV, Vergleichstabelle nach § 6 UWG mit Beleg je Zelle (Vorbild: `marketing/daten` im Teamodo-Repo).
- B2B-Abo: Unternehmer-AGB, USt-ID über `tax_id_collection`.

### 7.6 Tests

- `e2e/wurzel.spec.ts` neu schreiben. Drei der vier Tests prüfen Sätze, die bewusst wegfallen („Als Trainer anmelden" als Hauptaktion, „im Web gibt es nichts für dich zu tun"). Es bleiben: eine Hauptlandmarke, Produktgrenze sichtbar, Weg zu `/login` und `/registrieren`.
- `akzentflaechen()` auf den Viewport begrenzen und an drei Scrollpositionen prüfen (Hero, Mitte, Fuß).
- `e2e/kaufleiste.spec.ts`:
  - erscheint nach dem Anker
  - verschwindet beim Runterscrollen, kommt beim Hochscrollen
  - weg am Fuß
  - nicht fokussierbar, solange sie versteckt ist
  - `safe-area` im iPhone-Profil
- Vitest: `kaufleiste.logik.test.ts` (Zustandstabelle), `OhneMit` (Schalter per Tastatur), Webhook-Handler mit festen Stripe-Ereignissen (Signatur gemockt).
- Stripe end-to-end nur im Testmodus mit `stripe listen --forward-to localhost:3000/api/stripe/webhook`.

### 7.7 Reihenfolge

1. **Bausteine + `/` ohne Verkauf.** Kopf, Hero (Poster, Video-Logik ohne echtes Video, E6), Laufband ruhend mit Fakten (E7), Ohne/Mit, Schritte mit Screenshots, Verlauf & Ziele ohne Overlay, Fragen (inkl. Sensor „in Entwicklung", E1), Kaufleiste mit „App laden", Fuß; dazu `wurzel.spec` neu. Liefert sofort den Mitgliedsweg, der heute fehlt. Kein Sensor-Abschnitt, keine Warteliste, kein `VideoOverlay`, kein Kopfmenü, keine „Brücke zum Studio“ (beide brauchen `/studios`, kommen mit Etappe 2), Ohne/Mit ohne Hintergrundbild (die Unschärfe-Überblendung braucht ein Foto, E6). Plan: `docs/superpowers/plans/2026-10-03-landeseite-etappe1.md`. **Umgesetzt am 6. Oktober 2026.** Abweichungen: Die Kaufleiste erscheint erst, wenn der Hero-Knopf ganz aus dem Viewport ist (kein `rootMargin -kopfHoehe` wie in 7.3 — der Glas-Kopf deckt den Knopf nicht ab, sonst stuenden zwei Akzentflaechen im Bild). Weicht die Leiste mit dem Fokus darin, geht der Fokus an den sichtbaren Verdecker oder den Hero-Knopf. Offen: Screenshots (Aufgabe 9), Safe Area am echten iPhone, `NEXT_PUBLIC_APP_STORE_URL`.
2. **`/studios` + Kontakt + Rechtsseiten.** Funktioniert ohne Preismodell.
3. **Laufband mit Live-Zahlen**, sobald sie tragen.
4. **Sensor-Checkout (Testmodus)**, sobald E1 und Rechtsseiten stehen; Webhook + `bestellungen`.
5. **Studio-Billing**, sobald das Preismodell steht (M1 §13.1).

---

## 8. Widersprüche zu bestehenden Festlegungen

| Festlegung | Konflikt | Vorschlag |
|---|---|---|
| §10 / M1 Z. 118: „gymodo misst nichts", **sichtbar** | Ein Sensor misst | Satz wird produktbezogen (§4.4 oben). Bis zur Auslieferung unverändert. Erst mit dem Sensor ändern, dann auch in App und `/t/[token]` |
| M1 §2: „Retrofit statt Geräteinvestition — sensorbasierte Systeme bedeuten eine Investition in neue Geräte" | Wir bringen selbst einen Sensor | Kein echter Widerspruch: Der Sensor ist ein Clip am vorhandenen Gerät, also ebenfalls Retrofit. Auf `/studios` aber **nicht** mit dem Sensor werben, solange der Pitch „ohne Hardware" lautet → E5 |
| M1 Out of scope: „Abrechnung, jede Form von Sensorik" | Stripe + Sensor | Diese Spec ist M2+. Für den Studio-Teil muss die M1-Spec nicht geändert werden, nur der Umfang neu festgelegt |
| `wurzel.spec.ts`: eine Akzentfläche je Seite | lange Seite, mehrere CTAs | je Viewport (§4.2 oben) |
| `landeseite.module.css`: „92 pt, eigener Satz, kein Baustein" | wird ein Satz Bausteine | Kommentar dort entsprechend fortschreiben |

> **Nachtrag 10. Oktober 2026:** Aufgelöst: die Grenze ist gefallen, App, Landeseite und `/t/[token]` tragen den neuen Satz. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.

---

## 9. Entscheidungen (getroffen am 3. Oktober 2026)

- **E1 — Was verkauft `/` heute?** → **(a) App laden; Sensor später als Warteliste.** Etappe 1 verkauft nichts und sammelt nichts: kein Sensor-Abschnitt, kein Formular. Der Sensor erscheint nur als Antwort in den Fragen („Wann kommt der Sensor?" → „In Entwicklung. Einen Termin nennen wir erst, wenn er feststeht."). Die Warteliste (Checkbox + Double-Opt-in, eigene Tabelle, Bestätigungsmail, Datenschutztext) wird eine eigene Etappe nach 7.7/2. Vorbestellung mit Zahlung (b) oder gespeicherter Karte (c) erst mit Preis, Lieferzeit und Rechtsseiten.
- **E2 — Optik.** → **gymodo-dunkel mit Flächenstufen** (`bg` ↔ `surface`), harte Zäsuren nur durch vollflächige Bild-/Video-Sections. Keine helle Palette (§1).
- **E3 — App-Preis.** → **Kostenlos für Mitglieder, kein Abo.** Das Studio zahlt (M1 §2). Fragen-Antwort: „Nein. Die App ist kostenlos, dein Studio nutzt Gymtavo."
- **E4 — Preismodell Studio.** → **Vorerst „Preis auf Anfrage"**, `/studios` endet beim Gespräch. Das Modell (M1 §13.1) wird mit dem ersten Betreibertermin entschieden; Stripe Billing (7.7/5) wartet darauf.
- **E5 — Sensor auf `/studios`.** → **Erst ab Auslieferung.** Bis dahin „ohne Hardware", Produktgrenze unverändert.
- **E6 — Medien.** → **Etappe 1 mit echten App-Screenshots (Simulator, Sichtcheck-UI-Test) und einem Posterbild; Video später.** `Held` nimmt ein optionales `video` an; ohne Video bleibt die ganze Video-Logik aus. Die Video-Logik wird in Etappe 1 trotzdem gebaut und per Unit-Test geprüft (reduced-motion, Breite, Sichtbarkeit, Pause-Knopf); die Prüfung mit echtem Clip folgt mit dem Video. `VideoOverlay` und der Button „Rundgang ansehen" entfallen, bis es ein Rundgang-Video gibt — kein Knopf, hinter dem nichts kommt. **Offen:** wer Hero-, Tap- und Rundgang-Video dreht (Tim).
- **E7 — Zahlen im Laufband.** → **Fakten ohne Zahlen, ruhend.** Drei geprüfte Fakten als statische, umbrechende Zeile (= der reduced-motion-Zweig des Bausteins). Das Laufen schaltet eine Prop `laufend` erst in Etappe 3 mit Live-Zahlen frei. Begründung: Ein Laufband trägt den „so viele schon"-Effekt; mit Sätzen ist es Bewegung ohne Zweck und konkurriert mit der einen Inszenierung (Ohne/Mit, §3 Schluss). Jeder Fakt wird vor dem Bau gegen den Code geprüft.
- **E8 — Marke** (nachgetragen). → **GYMTAVO.** Die Landeseite nutzt den Baustein `app/branding/GymtavoWordmark.tsx` aus `feat/gymtavo-branding`; dieser Branch setzt auf dessen Spitze auf. Sichtbare Texte heißen „Gymtavo" (Versalien nur in der Wortmarke); Domain, Bundle-ID und Formatkennungen bleiben (README `assets/branding`). Wo diese Spec „gymodo" schreibt, ist für sichtbare Texte „Gymtavo" gemeint. Die Produktgrenze wird **nicht** auf der Landeseite allein umbenannt — sie zieht mit App, Portal und `/t/[token]` zusammen um (Befund 19: ein Satz, eine Quelle).
- **E9 — Ohne/Mit-Interaktionsmodell** (nachgetragen, aus der Prüfung von Abschnitt 7). → **„Schwelle“** wie Gpath, Tippen übersteuert bis zum Verlassen des Viewports. Details 7.2.2.

> **Nachtrag 10. Oktober 2026:** Mit E1 von Teilprojekt B zusammen umgezogen. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.
