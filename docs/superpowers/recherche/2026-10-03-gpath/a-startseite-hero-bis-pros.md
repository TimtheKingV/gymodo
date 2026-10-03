# Bericht A – getgpath.com Startseite, Sections 03–08

Quelle: Wayback-Snapshot 13.08.2026, Dateien in `scratchpad/gpath/home/`. CSS und JS wurden vollständig gelesen.

## Gemeinsame Grundlagen (Theme-Kontext)

- Shopify-Theme auf Dawn-Basis: `html { font-size: calc(var(--font-body-scale) * 62.5%) }`, damit gilt **1rem = 10px** (alle rem-Werte unten also ×10 px rechnen).
- Schrift: **Poppins** für Body und Headings, Body-Gewicht 400/700, Heading-Gewicht 500; `--font-heading-scale: 1.0`, `--font-body-scale: 1.0`.
- `--buttons-border-width: 1px`, `--page-width: 120rem` (1200px).
- Die Typo-Klassen `type-display`, `type-headline`, `type-subheadline`, `type-subheadline--muted`, `type-card-title`, `type-caption` und `type-body` sind in `assets/base.css` definiert. Diese Datei liegt **nicht** im Snapshot, deshalb fehlen ihre Größen hier. Nur wo die Section selbst überschreibt, stehen Werte im Bericht.
- Markenfarben: Primärblau **#4A4CFF** (Hover #3A3BCC), Schwarz #000/#111, Grau #555. Signal-Rot #e53935 / #ff3b30, Gelb #ffcc00, Grün #2db84d.
- Einheitlicher Primär-Button (Hero und CTA identisch): bg #4A4CFF, weiß, 1.2rem (12px), `letter-spacing: .12em`, UPPERCASE, Gewicht 600, Radius 10px, `padding: 0 3rem`, min-width 12rem+2px, min-height 4.5rem+2px (= 47px), `inline-flex` zentriert, `transition: background-color .2s ease`. Hover, focus und focus-visible setzen nur bg #3A3BCC und **`outline: none`**, es gibt also keinen sichtbaren Fokusring.
- Reihenfolge der Seite: Hero (schwarz) → Stats-Laufband (weiß) → Workout Clarity (weiß, dunkle Karte) → How it works (schwarz) → CTA „Get Gpath“ (schwarz) → Pros use it (weiß).

---

## 03 – Custom Hero (`03_custom_hero_cdiBRi.html`)

### 1. Inhalt (wörtlich)
- H1 (`.hero-title.type-display`): **„Stop Guessing<br>Your Lifts.“**
- Subline (`p.hero-subtitle.type-subheadline`): **„Finally, a device that turns raw workout metrics into actionable insights.“**
- Button: **„Shop Now“** → `/products/gpath-pin` (`a.button.button--primary`)
- Mobil-Video: `<video autoplay muted loop playsinline webkit-playsinline preload="metadata" aria-hidden="true" data-hero-mobile-video>`
  - Quelle: `https://cdn.shopify.com/videos/c/o/v/0325c98aca8c4b5192f63f07f1c167e8.mp4` (video/mp4)
  - Poster: `…/files/GpathPinHero3.png?v=1770379978&width=750` (PNG, 750px breit)
- Desktop-Bild: `<picture class="hero-background-desktop">`
  - `<source media="(min-width:990px)" type="image/webp">` mit srcset `V3GpathDektop-2.jpg …&width=1100|1500|1800&format=webp` (1100w/1500w/1800w), `sizes="100vw"`
  - zweite Source mit demselben srcset als JPG
  - `<img src="…V3GpathDektop-2.jpg?v=1770381037&width=1500" alt="Hero background" width="1500" height="1000" loading="eager" fetchpriority="high" decoding="async">`, also **3:2**
  - Alt-Text „Hero background“ ist nichtssagend.
- `<div class="hero-fade" aria-hidden="true">&nbsp;</div>`: das `&nbsp;` ist nötig, weil das Theme `div:empty` versteckt.

### 2. Aufbau

**Basis (alle Breiten):**
- `.hero-section`:
  - `position: relative`, `display: flex`, `align-items: flex-end`, `justify-content: flex-start`, `overflow: hidden`, `background: #000`, `z-index: 1`
  - **Höhe:** `calc(var(--hero-height-lock, 100svh) - var(--announcement-height, 0px))`. Fallback ist zuerst `var(--hero-height-lock, 100svh)`.
  - Laut Kommentar „never use 100dvh“: dvh verursacht Jank, sobald die Browser-Leiste ein- oder ausfährt.
  - `margin-top: calc(-1 * var(--header-height))`. Der schwebende Pill-Header liegt **über** dem Hero, der Hero beginnt also hinter dem Header.
- Bild und Video: `position: absolute`, `inset 0`, 100 % × 100 %, `object-fit: cover`, `object-position: center`, `z-index: 1`, `transform: translateZ(0)`, `backface-visibility: hidden` (eigene Compositor-Ebene gegen iOS-Jank), `pointer-events: none`, `-webkit-user-drag: none`.
- Umschaltung Video/Bild:
  - `.hero-background-video { display: block }`, `.hero-background-desktop { display: none }`
  - ab **990px**: Video `none`, Picture `display: contents`
  - bei `prefers-reduced-motion: reduce` ebenfalls Bild statt Video, auch mobil
- `.hero-fade` (z-index 4, inset 0, eine einzige Ebene über volle Höhe; der Kommentar erklärt, dass kurze Streifen Haarlinien über `<video>` erzeugen):
  - **mobil/Basis:**
    - von oben: `linear-gradient(to bottom, #000 0%, rgba(0,0,0,.85) 10%, .55 24%, .25 38%, .08 50%, transparent 62%)`
    - von unten: `linear-gradient(to top, rgba(0,0,0,.55) 0%, .18 6%, transparent 12%)`
  - **ab 990px:** nur unten, `linear-gradient(to top, rgba(0,0,0,.45) 0%, .12 8%, transparent 16%)`
- `.hero-content`: z-index 5, weiß, `max-width: 700px`, `padding: 0 60px 20px`, linksbündig, `margin-bottom: 88px`. Ab 990px `margin-bottom: 100px`. Ab 1200px: `max-width: 800px`, `padding: 0 80px 20px`, `margin-bottom: 88px`.
- `.hero-title`:
  - `font-size: calc(var(--font-heading-scale) * 3.4rem)` = **34px**, ab **750px** 4.4rem = **44px**
  - `margin-bottom: 15px`, weiß
- `.hero-subtitle`: `margin-bottom: 30px`, `max-width: 90%`, linksbündig.
- `.hero-buttons`: flex, gap 20px. Ab **769px** `margin-top: 2.5rem`.

**Mobil (≤768px), deutlich anders:**
- Section: `align-items: flex-start`, `justify-content: center`, `min-height: unset`.
- `.hero-content` wird eine Flex-Spalte über die **volle Höhe** (`height: 100%`), `padding: 8px 30px 36px`, zentriert, `max-width: 100%`.
- `.hero-text-group`: `margin-top: calc(var(--header-height) - 4px)`, damit der Text **oben direkt unter dem Header** sitzt, also über dem schwarzen Top-Fade.
- Titel `margin-bottom: .9rem`. Subtitle zentriert, `max-width: 70%`, keine Margins.
- `.hero-buttons`:
  - `flex-direction: column`, `margin-top: auto`: **der Button klebt unten**
  - `padding-bottom: .5rem`
  - Button `width: 100%`, `max-width: 320px`, `min-width: unset`
- Ergebnis mobil: Headline oben auf Schwarz, Produkt-Video in der Mitte, CTA unten (klassischer „Sandwich“-Hero).

**≤480px:**
- `.hero-content` `padding: 4px 20px 28px`
- text-group `margin-top: calc(header - 8px)`
- Titel `margin-bottom: .85rem`
- Button `max-width: 280px`, `padding: 0 2rem`

**≤768px im Querformat:** text-group `margin-top: calc(header + 10px)`, Titel-Margin .85rem, Subtitle zentriert.

**Desktop (≥990px):** Standbild 3:2, Text links unten (align-items flex-end), Button inline. Nur die leichte Abdunklung unten bleibt.

### 3. Animationen und JS
- **Höhenfixierung:** `lockHeroHeight()` setzt `--hero-height-lock = window.innerHeight + 'px'` einmal beim Laden. Neu gemessen wird **nur** bei `orientationchange`, mit `setTimeout(…, 250)`. Auf `resize` wird bewusst nicht reagiert, weil iOS beim Ausblenden der URL-Leiste `resize` feuert.
- **Chrome-Messung:**
  - `measureChrome()` liest `offsetHeight` von `.announcement-bar-section` und `.header-wrapper` und setzt `--announcement-height` und `--header-height` auf `:root`. Bei unveränderten Werten passiert nichts.
  - Aufgerufen sofort, bei `DOMContentLoaded` und über einen `ResizeObserver` auf Header und Announcement-Bar. Der Observer bündelt per rAF (`scheduleMeasure`).
- **Video-Logik** (`setupHeroVideo`):
  - setzt `muted`, `defaultMuted` und `playsInline` per Property und Attribut (iOS-Autoplay-Absicherung)
  - Bedingungen: `matchMedia('(max-width: 989px)')` UND nicht `prefers-reduced-motion` UND `inView`
  - `sync()` pausiert, sobald eine Bedingung fehlt. Sonst ruft es beim ersten Mal `video.load()` auf (wegen `preload=metadata`) und dann `play()`, die Promise-Rejection wird geschluckt.
  - `IntersectionObserver` mit `{ threshold: 0.15 }` auf das Video. Weitere Trigger: MQ-`change` (mit `addListener`-Fallback), `loadedmetadata`, `canplay`, `visibilitychange` (wenn nicht hidden), `pageshow` (bfcache).
- Keine Keyframe-Animationen und kein Text-Einblenden. Der Button hat nur den bg-Farbwechsel in 0,2 s.

### 4. Einschätzung
- **Wirkung mobil:**
  - Vollbild-Video in exakt eingefrorener Höhe ohne Ruckeln beim Scrollen
  - schwarzer Verlauf oben, der nahtlos in den schwarzen Header bzw. die Announcement-Bar übergeht
  - große Zweizeiler-Headline oben, breiter Daumen-CTA unten
- **Nachbauenswert:**
  - Höhen-Lock per `innerHeight` statt dvh
  - Video nur mobil und nur im Viewport
  - reduced-motion schaltet auf Standbild
  - Fade als **eine** Ebene
  - Hero hinter dem schwebenden Header (negativer margin-top)
- **Schwächen:**
  - `outline: none` auf focus-visible
  - Alt-Text „Hero background“
  - kein Video-Pause-Button (WCAG 2.2.2 bei Loop > 5 s)
  - Poster ist PNG 750px (schwer), Video ohne WebM/HEVC-Alternative
  - Nach Rotation ohne `orientationchange` (z. B. Desktop-Fensterresize) bleibt die Höhe falsch.

---

## 04 – Stats Loop Slider (`04_stats_loop_slider_home.html`)

### 1. Inhalt
- `<section aria-label="Gpath stats" data-stats-loop>`
- 4 Items, je `<span class="value">` + `<span class="text">`:
  - **41** countries
  - **4000+** lifters
  - **43 000+** workouts logged
  - **3 432 232+** reps tracked
- Die Tausendertrenner sind Leerzeichen.
- Zwischen den Items sitzt ein Punkt-Separator. Jede Gruppe enthält die 4 Items **3×**, also 12 Items.
- Es gibt **2 Gruppen**. Die zweite hat `aria-hidden="true"`.

### 2. Aufbau
- Section:
  - bg #fff, Text #111, `padding: 12px 0` (mobil ≤768px: `10px 0`)
  - `border-top` und `border-bottom` je `1px solid rgba(0,0,0,.08)`
  - `overflow: hidden`, `contain: paint`
- Track: `display: flex`, `width: max-content`, `translate3d(0,0,0)`, `backface-visibility: hidden`.
- Gruppen: flex, `align-items: center`, `flex-shrink: 0`.
- Item:
  - UPPERCASE, nowrap, `margin-right: 42px` (mobil 30px), Gewicht 500, `letter-spacing: .02em`
  - Klasse `type-body`, die Größe kommt aus base.css
  - Wert: #111, Gewicht 600. Text: #555.
- Separator: 5×5px Kreis, `rgba(0,0,0,.35)`, `margin-right: 42px` (mobil 30px), `margin-top: -1px`, `vertical-align: middle`.

### 3. Animation
- `@keyframes stats-loop-scroll { from translate3d(0,0,0) to translate3d(-50%,0,0) }`, `45s linear infinite`. **Mobil (≤768px): 36s.**
- Der Endlos-Effekt entsteht so: Der Track enthält 2 identische Gruppen. −50 % entspricht genau einer Gruppe, danach springt die Animation unsichtbar auf 0 zurück.
- JS: `IntersectionObserver` mit `{ rootMargin: '100px 0px', threshold: 0 }` togglet `.is-paused`, das setzt `animation-play-state: paused`, sobald die Section außerhalb des Viewports liegt. Laut Kommentar wird bewusst nicht remountet oder neu gestartet, weil das Stottern verursacht hatte. Ein Guard `root.__statsReady` verhindert Doppel-Init.
- `prefers-reduced-motion: reduce` → `animation: none`. Das Band steht dann, die Gruppe läuft rechts aus dem Bild, sichtbar sind nur die ersten Items.

### 4. Einschätzung
- Einfaches, robustes Pure-CSS-Marquee mit sauberem Pausieren außerhalb des Viewports. Liefert mobil Social Proof direkt unter dem Hero bei nur ca. 40px Höhe.
- **Nachbauenswert:** Doppelgruppe mit −50 %, `contain: paint`, schnellere Dauer mobil.
- **Schwächen:**
  - Die erste Gruppe liest Screenreadern die Stats 3× vor (nur die zweite ist `aria-hidden`).
  - Kein Pause-Bedienelement (WCAG 2.2.2).
  - Bei reduced-motion fehlt ein Umbruch-Layout.

---

## 05 – Workout Clarity (`05_workout_clarity_home.html`), das Herzstück

### 1. Inhalt
- H2 (`type-headline`): **„Train with absolute certainty.“**
- Subhead (`type-subheadline type-subheadline--muted`): **„Turn workout chaos into clear, actionable steps.“**
- Kartenhintergrund:
  - `<img src="…/files/DSC09793.jpg?v=1785852128&width=1200" alt="" width="1200" height="825" loading="eager" decoding="async" fetchpriority="low">`
  - Format ≈ **16:11** (1,45:1)
- **Chaos-Pillen**: 18 Stück. Jede hat eine Tiefe (back/mid/front), CSS-Variablen `--x/--y` (Position in %), `--rot` und `--sx/--sy` (Flugziel). Ein optionales Badge ist entweder `?` (warn, gelb) oder `!` (alert, rot).

| # | Text | Tiefe | x / y | rot | sx / sy | Badge |
|---|---|---|---|---|---|---|
| 1 | RPE 3? | back | 2% / 5% | −7° | −58vw / −28vh | ? |
| 2 | 0.34 m/s | front | 68% / 4% | 5° | 55vw / −32vh | – |
| 3 | Should I progress? | mid | 1% / 40% | 9° | −62vw / −8vh | ! |
| 4 | Velocity loss 18% | back | 76% / 36% | −4° | 60vw / −12vh | ! |
| 5 | RIR 2 or 3? | front | 0% / 58% | −11° | −58vw / 30vh | ? |
| 6 | Bar path off? | mid | 78% / 60% | 6° | 62vw / 22vh | ! |
| 7 | Felt heavy… | back | 3% / 84% | 3° | −52vw / 38vh | ! |
| 8 | Mean vel 0.41 | front | 62% / 86% | −8° | 48vw / 42vh | – |
| 9 | Fatigue? | mid | 34% / 5% | 12° | −38vw / −42vh | ? |
| 10 | Last set? | back | 54% / 48% | −2° | 42vw / 6vh | ? |
| 11 | Tempo? | front | 8% / 28% | 8° | −54vw / 2vh | ? |
| 12 | Peak force | mid | 84% / 3% | −9° | 58vw / −36vh | ! |
| 13 | ROM? | back | 28% / 88% | 4° | −44vw / 48vh | – |
| 14 | Eccentric slow? | front | 52% / 1% | −6° | 28vw / −48vh | ! |
| 15 | Add weight? | mid | 42% / 90% | 10° | −28vw / 52vh | ? |
| 16 | Set quality | back | 70% / 90% | −5° | 52vw / 46vh | – |
| 17 | Depth ok? | front | 22% / 48% | −10° | −48vw / 8vh | ? |
| 18 | Form check | mid | 58% / 58% | 7° | 46vw / 18vh | ! |

Regel der Flugrichtung: Das Ziel liegt immer in der eigenen Bildschirmhälfte und vom Zentrum weg. Links liegende Pillen fliegen nach links (−sx), oben liegende nach oben (−sy).

- **Coaching-Feed** (4 Items): „Add 2.5 kg“ · „Rest for 90 seconds“ · „Keep this pace“ · „Stop here today“
- **Schalter**:
  - Knopf-Bild: `…/files/gpathPinFront.png?v=1785168326&width=160` (width 80, height 120, also 2:3, eager)
  - Label: „Without Gpath“ ↔ „With Gpath“

### 2. Aufbau

**Section und Header:**
- Section: bg #fff, fg #111, `padding: 64px 1.5rem` (also 15px seitlich). Ab 750px seitlich 2.5rem (25px), oben und unten bleiben 64px.
- `.inner`: Flex-Spalte, zentriert, `gap: 2rem`, volle Breite.
- Header: zentriert, `max-width: 36rem`. Subhead `margin-top: .75rem`.

**Karte und Hintergrund:**
- `.card`:
  - volle Breite, `border-radius: 2rem` (mobil <750: **1.5rem**, ≥750: **2.4rem**)
  - bg #111, `overflow: hidden`
  - `border: 1px solid rgba(0,0,0,.08)`, `box-shadow: 0 18px 50px rgba(0,0,0,.08)`
- `::before`-Overlay: `rgba(0,0,0,.1)`, im with-Zustand `.05`, `transition: background .55s ease`, z-index 1.
- Hintergrundbild im without-Zustand:
  - `transform: scale(1.08)`, `filter: blur(6px) saturate(.75) contrast(.92) brightness(.95)`, `opacity: .92`
  - with: `filter: none`, `scale(1)`, `opacity: 1`
  - Transition jeweils `.45s ease` (filter, transform, opacity)
  - Kommentar: CSS-Blur statt SVG-`feTurbulence`, weil Letzteres die Seite eingefroren hatte.

**Bühne und Pillen:**
- `.stage`: z-index 2, `height: 70vh` mit `min-height` 420px (Basis), **380px mobil**, 480px ≥750px.
- Pillen-Basis:
  - absolut auf `left: var(--x)` / `top: var(--y)`, `inline-flex`, gap .5rem
  - `padding: 1.35rem 2rem`, min-height 4.4rem, `radius: 1.5rem`
  - bg `rgba(232,232,232,.94)`, Text #1a1a1a, `border: 1px solid rgba(255,255,255,.4)`
  - Schatten `0 1px 0 rgba(255,255,255,.28) inset, 0 10px 28px rgba(0,0,0,.12)`
  - `font-size: 1.55rem` (15,5px), Gewicht 600, `line-height: 1.15`, nowrap
- Größenvariation über nth-child:
  - 3n: `padding 1.15rem 1.7rem`, min-height 3.9rem
  - 4n: `1.5rem 2.2rem` / 4.8rem
  - 5n: `1.2rem 1.85rem` / 4.1rem
- Tiefenebenen (Chaos-Zustand):
  - back: z0, `scale(.88)`, `opacity .86`, bg `rgba(210,210,210,.92)`
  - mid: z1, `scale(1.02)`, `.92`, `rgba(218,218,218,.94)`
  - front: z2, `scale(1.08)`, `.96`, `rgba(228,228,228,.96)`
  - alle zusätzlich `rotate(var(--rot))`
- Badge:
  - absolut `top: -.5rem`, `right: -.5rem`, 1.7rem-Kreis, Schrift 1rem/700, `box-shadow: 0 2px 8px rgba(0,0,0,.22)`
  - alert #ff3b30 mit weißer Schrift, warn #ffcc00 mit Schrift #111

**Shade, Feed und Schalter:**
- `.shade` (z3): `linear-gradient(to top, rgba(0,0,0,.88) 0%, .55 22%, .22 40%, 0 50%)`. Opacity 0 → 1 im with-Zustand, `.55s ease`.
- `.bottom` (z5, inset 0, pointer-events none) enthält Feed und Schalter.
- **Feed-Container:**
  - `left: 50%`, `top: 50%`, `bottom: 0`, also die **untere Kartenhälfte**
  - `width: min(92%, 28rem)` (mobil `min(90%, 24rem)`), `translateX(-50%)`
  - opacity 0 → 1 (`.4s ease`)
- **Feed-Item:**
  - absolut zentriert, `padding: 1.15rem 1.85rem`, min-height 3.9rem, `radius: 1.5rem`
  - bg `rgba(255,255,255,.92)`, Rand `rgba(255,255,255,.28)`, gleicher Schatten wie die Pillen
  - `font-size: 1.85rem`, Gewicht 500, `line-height: 1.15`
  - Mobil: `font-size: 1.5rem`, `padding: 1rem 1.55rem`, min-height 3.4rem, `radius: 1.25rem`
- **Schalter** (Pille im iOS-Stil):
  - `left: 50%`, **`top: 25%`**, `translate(-50%,-50%)`, also in der oberen Kartenhälfte
  - `width: min(86%, 20rem)`, `height: 5.6rem`, `padding: .35rem`, `radius: 999px`
  - bg **#e53935** (rot) → **#2db84d** (grün), `transition: .55s ease`
  - Schatten `0 12px 40px rgba(0,0,0,.28), inset 0 1px 0 rgba(255,255,255,.18)`
  - **Mobil:** `width: min(88%, 17.5rem)`, `height: 5rem`
- **Knopf:**
  - weißer Kreis 4.9rem, padding .5rem, Schatten `inset 0 1px 0 rgba(255,255,255,.95), 0 4px 16px rgba(0,0,0,.22)`
  - darin das Produktbild (`object-fit: contain`) mit `filter: blur(2.5px)` → `blur(0)` im with-Zustand (`.55s`)
  - Position `left: .35rem` → `calc(100% - 5.25rem)`
  - **Mobil:** Knopf 4.3rem mit padding .4rem, Endposition `calc(100% - 4.65rem)`
- **Label:**
  - `flex: 1`, zentriert, weiß, Gewicht 600, `line-height: 1.1`
  - Margin wechselt von `0 0 0 5.1rem` zu `0 5.1rem 0 0` (mobil 4.5rem), damit das Label immer neben dem Knopf zentriert steht

**Mobil (<750px) zusätzlich:**
- Pillen kleiner: `padding: 1.05rem 1.5rem`, min-height 3.8rem, `radius: 1.25rem`, `font-size: 1.3rem`.
- **`nth-child(n+11)` → `display: none`**, also nur die ersten **10** Pillen.
- Badge 1.5rem, Schrift .9rem, Offset −.4rem.
- Feed-Abstände: prev/next ±3.9rem, scale .6, current scale 1.1.

### 3. Zustandslogik und Animationen (exakt)

**Umschalten nur per Scroll, kein Klick, kein Auto-Toggle per Timer:**
- Trigger-Element ist ein unsichtbares 1×1px-`<span>` bei **`top: 50%` der Karte** (`data-clarity-trigger`).
- Konfiguration: `IntersectionObserver({ rootMargin: '0px 0px -42% 0px', threshold: 0 })`, mit `triggerRatio = .58` → `bottomCutoff = 42`.
- Ergebnis: Der Zustand ist **„With Gpath“, solange die Kartenmitte zwischen Viewport-Oberkante und 58 % Viewport-Höhe liegt.**
- Konsequenzen:
  - Beim Herunterscrollen schaltet es um, sobald die Kartenmitte die 58-%-Linie passiert.
  - Scrollt die Kartenmitte oben aus dem Bild, ist `isIntersecting` false und der Zustand fällt auf **„Without“ zurück**.
  - Beim Zurückscrollen wird es rückwärts wiederholt.
  - Der Effekt ist damit voll reversibel und scroll-gebunden.
- Ein Fallback ohne IntersectionObserver nutzt scroll/resize mit rAF und vergleicht `rect.top + height*.5 < innerHeight*.58`. Ohne Obergrenze bleibt der Zustand dort „With“, sobald die Grenze einmal überschritten ist.

**`setState(next)`:**
- toggelt `.is-with-gpath` auf der Section
- setzt das Label „With Gpath“ / „Without Gpath“
- schaltet `aria-hidden` auf Feed und Chaos-Ebene gegenläufig
- startet bzw. stoppt den Feed

**Sichtbarkeitsobserver:** Ein zweiter IO auf der Section (`rootMargin: '20% 0px'`, `threshold: 0`) stoppt den Feed, wenn die Section weit außerhalb liegt, und startet ihn neu, wenn sie zurückkommt und `withGpath` gilt.

**Pillen-Flug (with-Zustand):**
- Ziel: `translate(var(--sx), var(--sy)) scale(.55) rotate(var(--rot) ± X)`, opacity 0
  - back: `rot − 28deg`
  - mid: `rot + 24deg`
  - front: `rot + 32deg`
- `transition: transform .55s cubic-bezier(.22,1,.36,1)` (easeOutQuint-artig), `opacity .4s ease`.
- **Stagger per `transition-delay`** (nicht linear, bewusst durchmischt), nur im with-Zustand:

  | nth-child | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
  |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
  | Delay (s) | .02 | .05 | .08 | .04 | .10 | .06 | .12 | .09 | .03 | 0 | .07 | .11 | .14 | .05 | .13 | .08 | .10 | .06 |

- Rückweg (without) läuft ohne Delay. Die Pillen „fallen“ alle gleichzeitig zurück.
- Dazu, alle gleichzeitig:
  - Hintergrund wird scharf (blur 6px → 0, scale 1.08 → 1, .45s)
  - Shade blendet ein (.55s)
  - Schalter wird grün, Knopf gleitet nach rechts (`left`-Transition .55s, gleiche Bezier), Knopfbild wird scharf
  - Label wechselt sofort den Text, der Margin gleitet

**Feed (vertikaler Karussell-Ticker):**
- `startFeed()`: `stopFeed()`, dann `feedIndex = 0`, nach **120ms** (reduced: 50ms) Positionen setzen und `playFeedStep()`.
- `playFeedStep()`: Positionen setzen, nach **hold 1100ms** (reduced 300) `feedIndex++` modulo 4, Positionen setzen, nach **slideDuration 480ms** (reduced 40) rekursiv weiter.
- Zyklus also **≈1580ms pro Schritt**, endlos.
- Zuweisung über `offset = (i - feedIndex + total) % total`:
  - offset 0 → `is-current`
  - offset 1 → `is-next`
  - offset total−1 → `is-prev`
  - Rest → `is-hidden`
- Bei 4 Items ist immer genau eins versteckt.
- Item-Transforms (Desktop/Basis):
  - Default (vor dem Start): `translate(-50%, calc(-50% + 5.2rem)) scale(.55)`, opacity 0
  - `is-next`: `+4.6rem`, `scale(.62)`, opacity .28
  - `is-current`: `translate(-50%,-50%) scale(1.12)`, opacity 1, z2
  - `is-prev`: `−4.6rem`, `scale(.62)`, opacity .28
  - `is-hidden`: `+7rem`, `scale(.5)`, opacity 0
- Transition: `transform .55s cubic-bezier(.22,1,.36,1)`, `opacity .45s ease`.
- Es entsteht eine nach oben laufende „Rolle“: unten taucht das nächste auf, die Mitte ist groß, oben verblasst der Vorgänger. Das Hidden-Item springt von oben nach unten (+7rem), mit opacity 0 unsichtbar.
- `stopFeed()` löscht alle Timer und entfernt alle Klassen, die Items fallen auf den Default zurück.

**prefers-reduced-motion:**
- Alle Transitions → `none` (Pillen, Shade, Feed, Schalter, Knopf, Label, Bild, Overlay).
- Bildfilter dauerhaft `contrast(.95) saturate(.85)`, also ohne Blur. Die with-Regel `filter: none` hat aber höhere Spezifität und hebt das wieder auf.
- Der Feed tickt weiter, nur schneller (300/40ms) und ohne Übergänge. Das ist eher mehr Flackern als weniger.

### 4. Einschätzung
- **Wirkung mobil:**
  - Die Karte füllt mit 70vh fast den Bildschirm.
  - Ein „Daumen-Scroll“ löst eine dramatische Verwandlung aus: rot → grün, unscharf → scharf, 10 Fragezeichen-Pillen explodieren gestaffelt aus dem Bild.
  - Danach tickt unten ein ruhiger Coaching-Feed mit klaren Anweisungen.
  - Die Story „Chaos → Klarheit“ wird ohne Text erzählt.
- **Nachbauenswert:**
  - scroll-gebundenes, reversibles Umschalten per IO mit Trigger-Span und negativem rootMargin, ohne Scroll-Listener
  - CSS-Variablen pro Pille (x/y/rot/sx/sy) plus Tiefenstufen
  - gemischter Stagger
  - eine Bezier `.22,1,.36,1` für alles
  - Reduktion auf 10 Pillen mobil
  - Feed-Pausierung außerhalb des Viewports
- **Schwächen:**
  - Der „Schalter“ ist kein Bedienelement: kein `button`/`role=switch`, nicht klickbar, nicht per Tastatur erreichbar. Optisch verspricht er Interaktion (Affordance-Fehler).
  - `aria-live="polite"` auf der ganzen Karte. Bei jedem Scroll-Wechsel wird „With/Without Gpath“ angesagt, der Feed selbst nie (die Klassen ändern sich, der Text nicht).
  - Animiert werden `filter: blur` auf einem 1200px-Bild und `left` am Knopf (Layout-Property statt transform). Beides ist teuer auf schwachen Geräten.
  - `70vh` hängt an der Browser-Leiste. Das widerspricht der dvh-Philosophie des Heros, hier ist es aber unkritisch.
  - Reduced-motion ist nur halb umgesetzt: Der Feed läuft weiter, die Pillen springen hart.
  - Pillen mit x bis 84 % und nowrap können rechts angeschnitten werden (`overflow: hidden` der Karte), was teils gewollt ist.
  - Hintergrundbild `loading="eager"`, obwohl below the fold.

---

## 06 – How it works (`06_how_it_works_carousel_VmXe7R.html`)

**Wichtig:** Trotz des Namens „carousel“ ist es **kein Karussell**. Es gibt kein JS, kein scroll-snap, keine Pfeile und keine Punkte, sondern ein einfaches Grid (mobil gestapelt).

### 1. Inhalt
- H2 (`type-headline`): **„How it works“**
- `<ol>` mit 3 `<li>`. Jedes Bild ist `<img loading="lazy" width="800" height="600">` (4:3) ohne srcset und ohne Größenparameter, das Original wird geladen.
  1. Bild `…/files/meetgpath.jpg?v=1762446451`, alt „Clip it on“. H3 (`type-card-title`) **„1. Clip it on“**. Text (`type-subheadline`): **„Simply snap Gpath onto any barbell or weight machine. It takes just one second.“**
  2. Bild `…/files/GpathPin5.jpg?v=1764155563`, alt „Just lift“. **„2. Just lift“**. **„Gpath silently tracks every movement in the background, turning your effort into simple data.“**
  3. Bild `…/files/gpathPin3.jpg?v=1764155563`, alt „Level up“. **„3. Level up“**. **„Open the free app to check your progress, hit new PRs, and know exactly what to lift next.“**

### 2. Aufbau
- Section: bg #000, Text #fff. Innen `.page-width` (Theme-Container) mit padding oben und unten **39px**, ab 750px **52px**.
- Titel: zentriert, `margin-bottom: 2.5rem` (ab 750px 3.5rem).
- Liste:
  - Grid `1fr`, gap 2.5rem
  - **ab 750px** `repeat(3, 1fr)`, gap 2rem, `align-items: start`
- Step: Flex-Spalte, linksbündig.
- Media:
  - 100 % breit, **`aspect-ratio: 4/3`**, `border-radius: 1rem`, `overflow: hidden`
  - Platzhalter-bg `rgba(255,255,255,.05)`
  - `margin-bottom: 2.5rem` (ab 750px 2rem)
  - Bild `object-fit: cover`
- Titel: `margin: 0 0 .55rem`, `padding: 0 .75rem`, weiß.
- Text: `padding: 0 .75rem`, Farbe `rgba(255,255,255,.85)`.

### 3. Animationen
Keine (keine Transition, kein JS).

### 4. Einschätzung
- Mobil sind das 3 untereinander gestapelte große 4:3-Bilder, es entsteht ein langer Scroll ohne Bewegung. Die Wirkung kommt allein aus der Bildstärke und dem schwarzen Hintergrund.
- **Nachbauenswert:** semantisches `<ol>`, aspect-ratio-Platzhalter, die Mini-Einrückung .75rem der Texte gegenüber dem Bild.
- **Schwächen:**
  - keine Bild-Größenvarianten (Performance)
  - Alt-Texte duplizieren die Überschriften
  - Die Nummer steht im H3-Text, obwohl das `<ol>` schon nummeriert.

---

## 07 – Get Gpath CTA (`07_get_gpath_cta_home.html`)

### 1. Inhalt
Nur ein Button **„Get Gpath“** → `/products/gpath-pin`.

### 2. Aufbau
- bg #000, schließt direkt an „How it works“ an.
- `.page-width` als Flex, zentriert, `padding-top: 18px` / `padding-bottom: 48px` (ab 750px 24px / 64px).
- Button-Stil identisch mit dem Hero (siehe Grundlagen).
- Mobil (≤768px): `width: 100%`, `max-width: 320px`, `min-width: unset`.

### 3. Animationen
Nur die bg-Farbe beim Hover, 0,2s.

### 4. Einschätzung
Ein simpler, wiederholter CTA nach der Erklärung, mobil als breiter Daumen-Button. Schwäche: Der Fokus ist unsichtbar.

---

## 08 – Pros use it (`08_pros_use_it_home.html`)

### 1. Inhalt
- H2 (`type-headline`): **„Unlock the pro athlete's secret.“**
- Text (`type-subheadline type-subheadline--muted`): **„NBA and Champions League pros track velocity, not feelings. We believe this tech shouldn't cost thousands.<br><br>That's why Gpath Pin was created.“**
- Die CSS-Regel für `.pros-use-it__eyebrow` (Blau #4A4CFF, UPPERCASE, `.14em`, Gewicht 600) ist definiert, **ein Eyebrow-Element wird aber nicht gerendert**.
- Bildleiste `aria-hidden="true"`, 4 Bilder, je `alt=""`, `width="900" height="1500"` (**3:5** hochkant), `loading="lazy"`, ohne srcset:
  - `//getgpath.com/cdn/shop/files/basketball.jpg` (short)
  - `football.jpg` (tall)
  - `gym.jpg` (mid)
  - `run.jpg` (short)

### 2. Aufbau
- Section: bg #fff, Text #111. `overflow-x: clip` mobil, `visible` ab 750px.
- `.inner`: `max-width: 46rem`, zentriert, padding oben und unten **54px**, Text zentriert, `overflow-x: clip`. Ab 750px `max-width: var(--page-width)` (120rem), padding **72px**.
- Heading: `margin: 0 auto 1.5rem`, `max-width: 40rem` (mobil `margin-bottom: 1.15rem`). Text `max-width: 40rem`.
- Media-Reihe:
  - Basis: Flex, zentriert, `align-items: flex-start`, gap 1.7rem, `margin-top: 2.5rem`, `max-width: 29rem`
  - Karten: `radius: 2.5rem`, bg #edf2f7, `box-shadow: 0 12px 30px rgba(0,0,0,.08)`, `overflow: hidden`
  - Basis-Höhe 470px. short: `flex: 0 0 22%`, `margin-top: 20px`. tall/mid: 25 %, `margin-top: 28px`.
- **Mobil (≤749px):**
  - Reihe: gap 1.15rem, `margin-top: 2rem`, **`max-width: calc(100% + 3rem)`** mit `margin-left/right: -1.5rem`. Sie ragt also über das Seiten-Padding hinaus.
  - Karten-Radius 1.8rem, Höhe **330px**.
  - short: `flex-basis: 24%`, `margin-top: 14px`. tall/mid: 25 %, **`margin-top: 44px`**.
  - Ergebnis: 4 schmale Hochformat-Kacheln in einer Reihe, die äußeren höher und die inneren 30px tiefer, eine **Wellen- bzw. Treppen-Silhouette**.
  - Durch `flex: 0 0` (ohne Schrumpfen) plus Gaps entsteht ggf. ein Überlauf, `overflow-x: clip` schneidet ihn ab.
- **Ab 750px:** gap 1.5rem, `margin-top: 3rem`, `max-width: 68rem`. Feste Breiten short 13.5rem, tall/mid 15.5rem, Höhe 540px, Versatz 20/28px. Laut Kommentar hatten Prozente plus Gap vorher überlaufen.

### 3. Animationen
Keine.

### 4. Einschätzung
- Die versetzte Hochformat-Galerie mit großen Radien sieht mobil wie eine Reihe App-Screens aus und wirkt modern und sportlich, ganz ohne JS.
- **Nachbauenswert:** negativer Seitenrand plus `overflow-x: clip` für randlose Wirkung, alternierender `margin-top`-Versatz.
- **Schwächen:**
  - feste px-Höhen (330/540) unabhängig vom Seitenverhältnis
  - Bilder ohne srcset (Originale 900×1500)
  - toter Eyebrow-CSS-Code

---

## Gesamtfazit für den Nachbau
1. **Mobile Wirkung entsteht durch:**
   - schwarz-weiß-schwarz-weiß-Rhythmus der Sections
   - Vollbild-Hero mit eingefrorener Höhe und Video
   - schmales Stats-Laufband direkt darunter
   - eine einzige große, scroll-gesteuerte Showpiece-Animation (Clarity)
   - sonst ruhige, statische Sections mit großen Radien (1–2.5rem) und weichen Schatten
2. **Animations-Vokabular:**
   - eine Bezier **`cubic-bezier(.22,1,.36,1)`** mit 0,45–0,55s
   - lineares CSS-Marquee (45s, mobil 36s)
   - IO statt Scroll-Listener
   - Pausieren außerhalb des Viewports
3. **Beim Nachbau besser machen:**
   - Fokus-Styles
   - Schalter als echten `role="switch"`-Button (zusätzlich klickbar) oder rein dekorativ ohne aria-live
   - `transform` statt `left`
   - Blur-Transition vermeiden oder vorab gerendertes Unschärfe-Bild crossfaden
   - reduced-motion konsequent (Feed statisch, Liste aller 4 Tipps)
   - srcset bzw. Bildgrößen
   - Video-Pause
   - Duplikate im Marquee per `aria-hidden` ausblenden
