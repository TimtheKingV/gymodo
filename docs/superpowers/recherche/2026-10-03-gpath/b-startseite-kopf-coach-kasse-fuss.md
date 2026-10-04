# Bericht B – getgpath.com Startseite (Header, Coach, Checkout, FAQ, Newsletter, Footer, Popups, `<head>`)

Quelle: Wayback-Snapshot 13.08.2026, Dateien unter `scratchpad/gpath/home/` + `home.html`.
Theme: „Gpath 4.1 BIG BET“, Dawn 15.4.0 (Shopify), Theme-ID 186094190928. Shop-Markt im Snapshot: **Polen / PLN** (Wayback-Crawler landete im PL-Markt → Preise in zł).

Einheiten-Hinweis: `html { font-size: 62.5% }` → **1rem = 10px**. Alle rem-Werte unten also ×10 px.

---

## 0. `<head>` – global

### Meta
- `<html class="js" lang="en">`, `charset utf-8`, `viewport width=device-width,initial-scale=1`, `theme-color=""` (leer)
- `<title>`: **Gpath - Your Smart Workout Companion**
- description / og:description / twitter:description: **„Track. Improve. Excel. Real-time feedback during a gamified gym workout experience“**
- canonical `https://getgpath.com/`, favicon `//getgpath.com/cdn/shop/files/Frame_169.jpg` (32×32 Crop)
- og:image `…/files/youtubeThumbnail_8985a6ba-….jpg` 1270×720; `twitter:card=summary_large_image`
- JSON-LD (im Header-Section): `Organization` (name Gpath, Logo-SVG, sameAs Instagram/TikTok/YouTube) und `WebSite` mit `SearchAction` (`/search?q=`)

### Fonts
- **Poppins** self-hosted über Shopify-CDN (`fonts.shopifycdn.com` preconnect), woff2+woff, `font-display: swap`
  - Gewichte: 400 normal, 700 normal, 400 italic, 700 italic, **500 normal**
  - Preload: n4 und n5 (woff2)
- `--font-body-family: Poppins, sans-serif` (Weight 400, bold 700); `--font-heading-family: Poppins` (**Weight 500**); Scale 1.0/1.0

### Globale Basis
- `body`: `display:grid; grid-template-rows:auto auto 1fr auto;` font-size **15px** (mobil) / **16px** (≥750px), `letter-spacing: .06rem` (0.6px), `line-height: 1.8`
- Textfarbe überall `rgba(var(--color-foreground), .75)` (Dawn-Default: Fließtext 75 % Deckkraft)
- `--page-width: 120rem` (1200px), `--spacing-sections-*: 0px`
- `--buttons-radius: 26px`, Border 1px; `--inputs-radius: 0`; `--variant-pills-radius: 40px`; `--badge-corner-radius: 4rem`
- Grid-Spacing desktop 8px / mobil 4px
- Die Typo-Tokens `type-headline`, `type-card-title`, `type-subheadline`, `type-caption`, `--type-subheadline-size` werden benutzt, sind aber **in `base.css` definiert (extern, nicht im Snapshot)**. Werte müssen aus der Live-CSS oder anderen Berichten ergänzt werden.

### Farbschemata (RGB-Tripel)
| Schema | Hintergrund | Vordergrund | Button | Button-Text |
|---|---|---|---|---|
| scheme-1 (Default, Header/FAQ) | #FFFFFF | 18,18,18 (#121212) | **74,76,255 = #4A4CFF** | weiß |
| scheme-2 | #F3F3F3 | #121212 | #4A4CFF | weiß |
| scheme-3 (Newsletter, Footer) | **#000000** | weiß | #4A4CFF | weiß; Shadow 36,40,51 |
| scheme-4 | #121212 | weiß | #4A4CFF | weiß |
| scheme-5 (Announcement) | **#4A4CFF** | weiß | #121212 | weiß |
| scheme-20cd… | #FFFFFF | #000000 | #4A4CFF | weiß |

**Markenfarbe: `#4A4CFF`**, Hover `#3A3BCC`. Sterne `#F5A623` (Section) bzw. `#FDB600` (Junip).

### Stylesheets
`base.css` (blocking), plus `component-cart-items.css` (print→all, async), `component-cart-drawer.css`, `component-cart.css`, `component-totals.css`, `component-price.css`, `component-discounts.css`, `component-localization-form.css`. Pro Section weitere `component-*.css` (list-menu, search, menu-drawer, cart-notification, slideshow, slider, list-social, accordion, collapsible-content, newsletter, newsletter-section, section-footer, list-payment). Alles aus `//getgpath.com/cdn/shop/t/61/assets/`.

### Skripte (Theme)
`constants.js`, `pubsub.js`, `global.js`, `details-disclosure.js`, `details-modal.js`, `search-form.js`, `junip-reviews-default-sort.js`, `animations.js`, `localization-form.js`, `cart.js`, `quantity-popover.js`, `cart-notification.js`, `cart-drawer.js`, `gpath-coach-persona.js` (Canvas-Avatar). **Die Logik für das mobile Pillen-Menü (`--menu-dropdown-height`, `.menu-open`) und `<sticky-header>` steckt in `global.js` – nicht im Snapshot.**

### Tracking / Drittanbieter (grob)
- **Google Tag Manager server-side über Stape**: `GTM-KVWQVHZ5`, First-Party-Domain `d.getgpath.com` (noscript-iframe im body); Stape-App-Block (`window.dataShopStape`, `marketShopStape` in localStorage, `dataLayer`-Bridge über `postMessage`)
- **Shopify Web Pixels Manager**: mehrere App-Pixel (Klaviyo, Essential A/B-Testing, Triple Whale u. a.) + 2 Custom-Pixel (u. a. `stape-io-custom`); `facebookCapiEnabled: false`
- **Triple Whale** (TriplePixel, `api.config-security.com`)
- **Klaviyo** onsite.js (Company `VPWZJV`)
- **Essential A/B Testing** (Inline-Embed, Template „index“)
- **UpPromote Affiliate** (Referral-Messagebar, Cookies `up_uppromote_aid`, `_up_a_info`, URL-Param `sca_ref`)
- **AfterSell** (UTM-Trigger), **Shopify Forms**, **Junip Reviews** (Store-Key, Sternfarbe #FDB600)
- **Cookiebot**-Anbindung an `Shopify.customerPrivacy` (alles false bis `CookiebotOnConsentReady`) – das Cookiebot-Script selbst ist nicht im Snapshot sichtbar
- Microsoft Clarity: App-Block **fehlgeschlagen** („does not exist“)
- Shopify-Standard: Trekkie, Monorail, perf-kit, Shop Pay/Sign-in-with-Shop, Accelerated Checkout, Shopify MCP (`/api/mcp`)
- Shopify-Newsletter-Popup schreibt an eine **eigene Supabase Edge Function** (`mxustcnzyqlbtkigvigb.supabase.co/functions/v1/newsletter-signup`)

---

## 1. Announcement-Bar (`01_announcement-bar`)

**Inhalt wörtlich:** `Free Worldwide Shipping` – einziger Text, keine Links. `role="region" aria-label="Announcement"`, Klasse `h5`.

**Aufbau**
- Hintergrund `#4A4CFF !important`, alle Kinder `#ffffff !important` (color-scheme-5)
- `.announcement-bar__message`: inline-flex, nowrap, zentriert, gap .55rem; **15px / lh 1.4** desktop, **12px / lh 1.5** unter 749px
- Lädt slideshow/slider-CSS (Dawn-Default für mehrere Ansagen), wird aber nicht genutzt

**Countdown (vorbereitet, aber inaktiv)**
- CSS + JS für `[data-announcement-countdown]` vorhanden, im Markup aber **kein Countdown-Element** → Script beendet sich sofort (`if (!countdowns.length) return`).
- Zielzeit hart codiert: `2026-07-19T23:59:59+02:00` (Sale-Ende, im Snapshot vom 13.08. bereits abgelaufen).
- Logik: `setInterval(1000)`, Tage/Std/Min/Sek mit `pad2`, nach Ablauf `00`. Ziffern `font-variant-numeric: tabular-nums`, jede Einheit `width: 2ch` rechtsbündig (kein Springen). Gap Label–Countdown .55rem, Einheiten .6rem.
- Es ist ein **fester Termin**, kein Fake-Evergreen-Countdown – nach Ablauf zeigt er 00:00:00:00 statt sich zurückzusetzen.

**Einschätzung:** Simpel und nachbaubar. Countdown-Muster (tabular-nums, 2ch-Breite) ist sauber; Weiß auf #4A4CFF = Kontrast ≈ 5,6:1 (ok). Der leere Locale-Wrapper ist Ballast.

---

## 2. Header (`02_header`)

### Inhalt
- Logo: `//getgpath.com/cdn/shop/files/GpathLogoShopify.svg` (SVG, 120×46.9, `loading=eager`), alt „Gpath“, Link `/`; in `<h1>` (auf jeder Seite → SEO-Schwäche)
- Navigation: **Home** (`/`, aria-current="page"), **Our Story** (`/pages/our-story`), **Support** (`/pages/contact`)
- CTA-Pille: **Shop** → `/products/gpath-pin` (auf der Produktseite ausgeblendet; dort stattdessen Cart-Icon)
- Versteckt: Suche (Modal), Account, Cart-Icon (`/cart`), Desktop-Lokalisierung
- Mobiles Menü zusätzlich: Länderauswahl (30 Länder, „Poland | PLN zł“), Social Instagram/TikTok/YouTube – **per CSS ausgeblendet** im offenen Menü

### „Floating Pill“-Aufbau
- Section/Wrapper transparent, `z-index: 500`, `.section-header { position: sticky }`, `<sticky-header data-sticky-type="always">` → Header bleibt **immer** oben (Dawn-Logik in global.js); Announcement-Bar scrollt weg.
- Wrapper-Padding (Abstand der Pille zum Rand): **mobil 7.5px 10px 0**, **≥750: 10px 15px 0**, **≥990: 11px 20px 0**
- Pille `.header`: Höhe **54px**, `max-width: min(72rem,100%)` = 720px, ≥990: **min(78rem,100%) = 780px**; zentriert
  - Padding innen 0 6px / 0 8px (≥750) / 0 10px (≥990)
  - Glas: `background: rgba(255,255,255,.86)`; `backdrop-filter: blur(12px) saturate(1.1)`; `transform: translateZ(0)`
  - **Mobil (<990)** stärkeres Glas: `rgba(255,255,255,.78)`, `blur(22px) saturate(1.2)` (= identisch zur Checkout-Karte)
  - `border-radius: 16px`; `border: 1px solid rgba(255,255,255,.28)`; Schatten `0 1px 0 rgba(255,255,255,.35) inset, 0 10px 28px rgba(0,0,0,.12)`
- Logo: max-height **40px** mobil, **38px** ≥750; Wrapper max-width 11/12/13rem; `translateY(1px)` zur optischen Zentrierung
- Shop-Pille: mobil **36px hoch, Padding 0 16px, 13px, weight 550**, ≥990 **38px, 0 18px, 13.5px**; `#4A4CFF`, radius 100px, Hover `#3A3BCC`, `transition: background-color .2s ease`
- Desktop (≥990): Grid `1fr auto 1fr`, gap 15px – Logo links, Menü **mittig** (Spalte 2), Icons rechts. Link-Padding vertikal 2.5px (≥750).
- Mobil: Flex `space-between`, Logo links, rechts `Shop` + Hamburger (40×54px Trefferfläche, Icon 30×30px), gap 4px.

### Negativer Margin unter dem Hero
- CSS-Fallback `--header-height`: **66px** mobil (Kommentar „0.75rem top pad + 54px pill“, gerundeter Näherungswert), **70px** ≥750, **72px** ≥990.
- Inline-Script direkt nach dem Header misst `header-wrapper.offsetHeight` → `--header-height`, Announcement → `--announcement-height` und friert `--hero-height-lock = window.innerHeight` ein (absichtlich **nicht** bei Scroll/Resize aktualisiert, damit die mobile Browserleiste den Hero nicht rescaled).
- Hero (Section 03) nutzt `margin-top: calc(-1 * var(--header-height))` und `height: calc(var(--hero-height-lock, 100svh) - var(--announcement-height))`; ein `ResizeObserver` im Hero misst nur bei echter Größenänderung von Header/Announcement neu.

### Mobiles Menü („eine wachsende Pille“)
- Kein Fullscreen-Drawer: `header-drawer` und `details` werden mit `display: contents` (inkl. Chrome-131-Fix `::details-content { display: contents }`) „durchgereicht“; Overlay/Abdunklung per `content: none` entfernt.
- Pille wächst: `height: calc(54px + var(--menu-dropdown-height, 0px))`, gleichzeitig `margin-bottom: calc(0px - var(--menu-dropdown-height))` → Seite darunter bewegt sich nicht.
- `transition: height .34s cubic-bezier(0.16,1,0.3,1), margin-bottom .34s …` (Ease-out-expo-artig)
- `.menu-drawer` absolut bei `top: 54px`, `max-height: var(--menu-dropdown-height)`, transparent (kein zweites backdrop-filter), Padding geschlossen `0 5px`, offen `4px 5px 7.5px`; `visibility` verzögert um .34s beim Schließen.
- Innencontainer: `opacity 0→1` (.22s, Delay .06s) und `translateY(-6px → 0)` (.28s, Delay .04s), gleiche Kurve.
- Links: zentriert, Spalte, gap 10px, **17px, weight 500, letter-spacing -0.01em, Farbe #6B7280**, Hover/aktiv `#111827`, Padding 3.5px 10px.
- Hamburger ↔ X-Icon im selben `<summary>` (Dawn-Swap).
- Die JS-Seite (Setzen von `--menu-dropdown-height` und `.menu-open`) liegt in `global.js` – **nicht im Snapshot**; muss nachgebaut werden (Höhe des Inhalts messen → Variable setzen; `.menu-opening`-Klasse für Fade).

### Einschätzung
Sehr nachbauenswert: das Glas-Pillen-Design und das „wachsende“ Menü ohne Layout-Shift sind gut gelöst und performance-bewusst (schwächerer Blur auf Desktop, translateZ). Schwächen: Logo in `<h1>` auf allen Seiten; Menü hat keinen Escape/Fokus-Trap (Dawn `details` bietet Basis); Menülinks #6B7280 auf weißem Glas ≈ 4,8:1 – knapp ok; Lokalisierung im Menü versteckt (Nutzer kann Währung mobil nicht wählen).

---

## 3. Gpath Coach (`09_gpath_coach_home`)

### Inhalt wörtlich
- Persona: `<canvas width=320 height=320>` animiert durch `gpath-coach-persona.js` (extern, `data-size="110"`, aria-hidden). 96×96px mobil / 110×110px ≥750.
- H2: **„Understand more with“** (55 % Weiß) + Umbruch + **„Gpath Coach“** (Weiß)
- Button: Play-Icon (SVG 16px) + **„Watch Video“** (`aria-haspopup="dialog"`)
- Video: `https://cdn.shopify.com/videos/c/o/v/b341c854fa9e4edd9db30c5c2bd27d51.mp4` (MP4), Poster `https://cdn.shopify.com/s/files/1/0888/9355/5024/files/fallbackImageV3.jpg`, `playsinline controls preload="none"`
- 3 Feature-Karten (Bild jeweils PNG 400×700, lazy, alt = Titel):
  1. **„Get answers from your data“** – „Ask questions about data gathered by Gpath Sensor. Finally, a device that can see into your real workout metrics.“ – `…/files/920shots_so.png`
  2. **„Find trends and break through plateaus“** – „Spot patterns in your training and know exactly when to push harder or pull back.“ – `…/files/314shots_so.png`
  3. **„Personalised training plans“** – „Based on your recovery, workload, and real training data from Gpath Sensor.“ – `…/files/123shots_so.png`
  (Basis-URL `https://cdn.shopify.com/s/files/1/0888/9355/5024/files/`)

### Aufbau
- Section: Hintergrund **#000**, Text weiß, Padding **56/56px** mobil, **88/80px** ≥750.
- Lichtschein oben (`::after`): Höhe `min(36vw, 220px)`, `radial-gradient(ellipse 80% 70% at 50% 0%, rgba(199,85,255,.18) 0%, rgba(30,96,255,.10) 35%, transparent 72%)` – Violett→Blau.
- Container max 1200px, Seitenpadding 15px / 50px (≥750).
- Header zentriert max 800px, margin-bottom 27.5px (mobil ≤768: 22.5px, ≥750: 32.5px).
- Titel: `clamp(2.6rem, 7.2vw, 4.2rem)` = **26–42px**, line-height 1.05, letter-spacing -0.03em, max-width 14ch, Heading-Font (Poppins 500).
- Watch-Button: Weiß/Schwarz, Pille radius 999px, min-height **38px**, Padding 10px 19px 10px 16px, 13.5px, weight 400, gap 7.5px; ≥750: **42px**, 11.5px 22.5px 11.5px 19px, 15px, Icon 15.5px. Hover `#F2F2F2` + `translateY(-1px)`, Transition .2s ease (bg, transform, opacity).
- Feature-Liste: Spalte, gap 20px, margin-top 40px (≤768: gap 15px, mt 30px; ≤480: gap 12.5px).
- Karte: Grid **2 Spalten (Text | Bild)**, min-height **380px**, radius **16px**, Border `1px rgba(255,255,255,.18)`, Hintergrund (helle Karte auf schwarzem Grund):
  ```
  radial-gradient(ellipse 90% 80% at 100% 0%, rgba(199,85,255,.22) 0%, transparent 58%),
  radial-gradient(ellipse 75% 70% at 0% 100%, rgba(30,96,255,.16) 0%, transparent 55%),
  radial-gradient(ellipse 55% 50% at 85% 100%, rgba(255,148,102,.14) 0%, transparent 50%),
  linear-gradient(145deg, #ffffff 0%, #f6f4ff 42%, #eef1ff 72%, #f8f0ff 100%)
  ```
- Karten-Text: Padding 35px 37.5px, gap 7.5px, Titel #111 (`type-card-title`), Text `rgba(17,17,17,.8)` (`type-subheadline`), max 36ch.
- Bild: `object-fit: cover; object-position: center top`, min-height 380px.
- **≤768px**: Karte 1-spaltig, Text oben (Padding 27.5px 20px 22.5px), Bild unten min-height **300px** (≤480: **260px**, Text-Padding 22.5px 15px 17.5px).

### Video-Overlay (exakt)
- Öffnen (`click` auf Button):
  1. Modal wird per `document.body.appendChild(modal)` **in den body verschoben** (vorher Kommentar-Platzhalter `gpath-coach-modal-slot` gesetzt), um Stacking-/overflow-hidden-Probleme der Section zu umgehen.
  2. `hidden=false`, Klasse `is-open`, `html.gpath-coach-modal-open`, Button `aria-expanded="true"`, `video.play()` (Fehler stumm geschluckt).
- Darstellung: `position: fixed; inset: 0; 100vw × 100vh` (100dvh wird von 100vh überschrieben – Reihenfolge-Bug), `z-index: 10000`, Hintergrund **reines Schwarz**, Video **vollflächig `object-fit: cover`** (schneidet ab!), kein Rand/Radius, **keine Ein-/Ausblend-Animation** (sofort).
- Schließen-Button: fixed, `top/right: calc(40px + env(safe-area-inset-*))`, 36×36px rund, `rgba(255,255,255,.18)`, „×“ 26px, `aria-label="Close"`.
- **Header & Kaufleiste ausblenden**: `html.gpath-coach-modal-open #md-sticky-atc, .section-header, .shopify-section-group-header-group { visibility: hidden !important; pointer-events: none !important }` (Announcement-Bar gehört zur header-group und wird mit versteckt).
- **Scroll-Lock**: nur `html.gpath-coach-modal-open { overflow: hidden }` – kein iOS-Fix (position:fixed body), daher auf iOS Safari evtl. durchscrollbar.
- Schließen: Backdrop-Klick oder ×: `video.pause()`, `currentTime = 0`, Klassen weg, `hidden=true`, Modal zurück an Platzhalter, `aria-expanded="false"`, **Fokus zurück auf den Button**.
- **Escape**: globaler `keydown`-Listener schließt, wenn offen.
- **Kein Fokus-Trap**, kein initialer Fokus ins Dialog (Fokus bleibt auf verdecktem Button), `aria-label="Watch Video"` am Dialog.
- Bug: Nach dem Verschieben in den body greifen die section-spezifischen Selektoren nicht mehr – funktioniert nur, weil zusätzlich `.gpath-coach__modal.is-open` / `.gpath-coach__modal .…` definiert sind.

### Einschätzung
Visuell stark (schwarz + farbiger Glow + helle Verlaufskarten). Overlay-Muster (Header/Sticky ausblenden per html-Klasse, Fokus-Rückgabe, Escape, Video-Reset) gut übertragbar – nachbauen mit Fokus-Trap, Fokus auf Close beim Öffnen, `object-fit: contain` statt cover und iOS-tauglichem Scroll-Lock. Persona-Canvas ist extern und nicht analysierbar.

---

## 4. Checkout-Block „Shop Gpath Pin“ (`10_checkout_gpath_home`)

### Inhalt wörtlich
- H2 (`type-headline`): **„Shop Gpath Pin“**
- Rating: **★★★★★** (5 volle Sterne als Text, `#F5A623`) + „Rated **4.5** by **4000+** customers“ (`aria-label="Rated 4.5 by 4000+ customers"`) → **5 Sterne dargestellt bei 4,5 – irreführend**
- Formular `POST /cart/add`: `id=49973835858256`, `quantity=1`, `return_to=/checkout` → **direkt in den Checkout**
- Button: **„Checkout - 556,00 zł“** (PL-Markt; kein Alt-/Streichpreis auf der Startseite)
- Hintergrundbild: `//getgpath.com/cdn/shop/files/GpathHAnd.jpg` (JPG 2400×3000, lazy, alt="" dekorativ)

### Aufbau
- Section `#F5F7FB` (sichtbar nur bis Bild lädt), `isolation: isolate`, Padding **54px 15px** mobil, **72px 25px** ≥750.
- Bild absolut, cover, `object-position: center 20%` (≥750: center 12%).
- Unterer Fade: Höhe 55 %, `linear-gradient(to top, rgba(0,0,0,.78) 0%, rgba(0,0,0,.35) 45%, transparent 100%)` **+ `backdrop-filter: blur(22px)` mit `mask-image: linear-gradient(to top, #000 0%, #000 42%, transparent 100%)`** → progressiver Blur nach unten.
- Karte schiebt sich über das Bild: `padding-top` des Shells `clamp(18rem, 78vw, 30rem)` (≤749, also 180–300px), sonst `clamp(20rem,62vw,38rem)`, ≥750 `clamp(24rem,46vw,44rem)` (240–440px).
- Glas-Karte: `rgba(255,255,255,.78)`, `blur(22px) saturate(1.2)`, Border `1px rgba(255,255,255,.28)`, Schatten wie Header, radius **20px** (mobil **16px**), Padding 34px 15px (mobil 28px 15px), ≥750 40px 25px 38px; Innenbreite max 360px.
- Titel #111, mb 10px (mobil 8.5px). Rating flex zentriert, gap 7.5px (mobil 6.5px, wrap), mb 17.5px (mobil 15px); Sterne 16.5px, letter-spacing .12em.
- Button: `#4A4CFF`, radius **10px** (≠ Pillen sonst!), min-height ~47px (4.5rem + 2×1px), min-width ~122px, Padding 0 30px, **12px, weight 600, letter-spacing .12em, UPPERCASE**, Hover/Focus `#3A3BCC`, Transition .2s. Mobil: `width: 100%; max-width: 320px`.

### Einschätzung
Glas-Karte über Foto mit maskiertem Blur-Verlauf: sehr nachbauenswert. Schwächen: 5 volle Sterne bei 4,5-Rating; Button-Stil inkonsistent (eckiger, Caps); Fokus-Zustand nur Farbwechsel (kein Ring); Direkt-Checkout ohne Warenkorb-Rückmeldung.

---

## 5. FAQ „Want to know more?“ (`11_collapsible_content_bpgcKt`)

### Inhalt wörtlich
Überschrift (H2, `type-headline`, zentriert): **„Want to know more?“**

1. **Can I use the app without subscription?**
   „Yes, you can use Gpath Pin device and fully track your workouts without a premium subscription. All essential features, including workout tracking and performance data, are available to you. Upgrading to Gpath Premium simply unlocks additional advanced features to enhance your training experience.“
2. **Is the Gpath app available on both Android and iOS?**
   „Yes, the Gpath app is available for download on both the App Store (iOS) and Google Play Store (Android).“
3. **Is Gpath compatible with all gym equipment?**
   „Gpath currently works best with barbells and weight stack machines. While it may be compatible with other equipment, optimal performance is achieved with these types of equipment.“
4. **Can I track my athletes as a personal trainer?**
   „Currently, Gpath is designed for gym enthusiasts, not personal trainers. We do not yet offer features specifically for managing multiple athletes or clients, as our main development focus is on individual workout tracking.“

### Aufbau / Interaktion
- Natives **`<details>/<summary>`** (Dawn `component-accordion.css`), alle geschlossen, kein JS, **keine Höhenanimation** (Standard-Dawn: nur Caret dreht).
- Summary: Fragezeichen-Kreis-Icon (SVG 20×20) + H3-Titel (`type-card-title`) + Caret-Icon.
- Antwort im `div.accordion__content rte` mit `role="region"` + `aria-labelledby` auf die Summary – **Antworten stecken in `<h5>`** (semantisch falsch), per CSS auf Body-Font/`--type-subheadline-size` zurückgestellt, margin 0.
- Layout: Dawn „collapsible-none-layout“, schmaler Wrapper, `grid--1-col grid--2-col-tablet` (eine Spalte gefüllt), color-scheme-1 (weiß).
- Padding Section 27px/27px mobil, 36px/36px ≥750. Scroll-Einblendung `scroll-trigger animate--slide-in` (animations.js).
- Kein FAQPage-JSON-LD.

### Einschätzung
Inhalt kurz, ehrlich (sagt klar, was nicht geht). Nachbau mit details/summary ist barrierearm; besser: `<p>` statt `<h5>`, FAQ-Schema ergänzen, ggf. sanfte Höhenanimation.

---

## 6. Newsletter (`12_newsletter_KmHtEL`) – Footer-Gruppe

### Inhalt wörtlich
- H2 (Klasse `h1`): **„Subscribe to our emails“**
- Sub: **„Be the first to know about new collections and exclusive offers.“**
- Formular `POST /contact#contact_form`, `form_type=customer`, `contact[tags]=newsletter`, Feld `contact[email]` (type email, required, Placeholder + Floating Label „Email“), Submit-Icon-Button (Pfeil-SVG, `aria-label="Subscribe"`) im Feld.

### Aufbau
- color-scheme-3 (**schwarz/weiß**), volle Breite, zentriert, Padding **30/39px** mobil, **40/52px** ≥750.
- Dawn-Standard (`component-newsletter.css`, `newsletter-section.css` – extern), Input-Radius 0 (globale Variable).
- Scroll-Animation `animate--slide-in` mit `data-cascade` und `--animation-order` 1/2/3 (gestaffelt).
- Shopify-native Kundenanlage (≠ Popup, das an Supabase sendet → **zwei getrennte Newsletter-Pipelines**).

### Einschätzung
Generischer Dawn-Standardtext („new collections“ passt nicht zu einem Ein-Produkt-Shop). Nachbau trivial; Text anpassen, Double-Opt-in/Datenschutzhinweis fehlt hier komplett.

---

## 7. Footer (`13_footer`)

### Inhalt wörtlich (Reihenfolge)
1. Social-Icons: **Instagram** (`https://www.instagram.com/gpath.gym/`), **YouTube** (`https://youtube.com/@gpath_gym?si=xZekdgb9Nwvit-NZ`), **TikTok** (`https://www.tiktok.com/@gpath.gym?is_from_webapp=1&sender_device=pc`)
2. Links: **SUPPORT** (`/pages/contact`), **RETURNS** (`/pages/returns`), **LEGAL ▾** (Dropdown):
   - Privacy policy `/policies/privacy-policy`
   - Refund policy `/policies/refund-policy`
   - Terms of service `/policies/terms-of-service`
   - Contact information `/policies/contact-information`
   - Legal notice `/policies/legal-notice`
3. Zahlungs-Icons (SVG 38×24): Apple Pay, Google Pay, Visa, Mastercard, American Express, Klarna, BLIK
4. Länderauswahl „Country/region“ – „Poland | PLN zł“; Länder: Austria, Belgium, Bulgaria, Croatia, Cyprus, Czechia, Denmark, Estonia, Finland, France, Germany, Greece, Hungary, Ireland, Italy, Latvia, Lithuania, Luxembourg, Netherlands, Norway, Poland, Portugal, Romania, Slovakia, Slovenia, Spain, Sweden, Switzerland, Ukraine, United Kingdom, United States
5. **© 2026 Gpath** (Link `/`)

(Der Newsletter-Block im Footer ist leer.)

### Aufbau
- color-scheme-3 (**schwarz**), Padding oben 0, unten **27px** mobil / **36px** ≥750; alles **zentriert**, Reihen `padding: 10px 0`.
- Support/Returns/Legal: weiß, **14px, weight 500**, Hover opacity .8; Policies-Liste flex wrap gap 15px; **mobil Spalte, gap 7.5px**.
- Legal-Dropdown öffnet **nach oben** (`bottom: 100%`), min-width 180px, radius 5px, Border `rgba(fg,.2)`, Schatten `0 4px 12px rgba(0,0,0,.15)`; Animation `opacity 0→1, visibility, translateY(5px → 0)`, `transition: all .2s ease`; Pfeil dreht 180°. Items Padding 7.5px 10px, 12px, Hover-Hintergrund `rgba(fg,.05)`.
- JS: Klick toggelt `.open` + `aria-expanded`; Klick außerhalb schließt. **Kein Escape, keine Tastatur-Navigation**, Items ohne role/menu.
- Lokalisierung: Spalte mobil, gap 10px.

### Einschätzung
Minimalistisch, gut übertragbar. Schwächen: Rechtliches hinter Dropdown versteckt (für DE: Impressum muss „leicht erkennbar, unmittelbar erreichbar“ sein → als direkte Links nachbauen); Dropdown ohne Escape.

---

## 8. sticky-gtp = Rabatt-Popup „Want to unlock discount?“ (`15_sticky-gtp`)

Die Section selbst ist leer; das Popup `#custom-newsletter-popup-custom` hängt direkt dahinter (vor `</body>`). **Das zugehörige CSS ist im Snapshot nicht inline** – es kommt aus `base.css`/einer Asset-Datei (nicht vorhanden). Nur Struktur/Logik ist dokumentierbar.

### Inhalt wörtlich
- **Schritt 1:** H3 „**Want to unlock discount?**“ – Button „**Yes, of course!**“ – Button „**No thanks**“ (schließt)
- **Schritt 2:** H3 „**You've got 10% OFF**“ – „**plus access to subscriber-only news.**“ – E-Mail-Feld (Placeholder „Enter your email“, visually-hidden Label „Email“) – Button „**Unlock my discount**“ – Rechtstext: „By signing up, you agree to receive marketing emails. View our privacy policy and terms of service for more info.“ (ohne Links)
- **Erfolg:** „**Here is your 10% OFF:**“ – „Your code is:“ – Button mit Code **LIFT10** + „Copy“ (→ „Copied“) – Link „**Use code**“ → `/discount/LIFT10?redirect=/products/gpath-pin`
- Fehler: „Something went wrong. Please try again.“
- Close-× `aria-label="Close popup"`, Backdrop klickbar.

### Logik (exakt)
- **Trigger:** reiner Timer, `setTimeout(openPopup, 3500)` → **3,5 s nach Laden**, unabhängig von Scroll/Exit-Intent, auf jeder Seite.
- **Nicht anzeigen, wenn:**
  - `localStorage['popup-custom-converted'] === '1'` **oder** irgendein Cookie `discount_code=` existiert (die LIFT10-Prüfung ist redundant – jeder Rabattcode unterdrückt es)
  - `sessionStorage['popup-custom-dismissed'] === '1'` (gesetzt bei jedem Schließen) → **pro Browser-Session nur einmal**; in neuer Session/Tab wieder.
- **Pending-Fortsetzung:** Beim Submit `sessionStorage['popup-custom-pending-submit']='1'`; wenn die Seite während des Requests neu lädt, öffnet das Popup **sofort** in Schritt 2.
- Öffnen: `hidden` entfernen, `body.custom-newsletter-popup-open` (vermutlich Scroll-Lock im externen CSS); Schritt 2 fokussiert das E-Mail-Feld.
- Submit: `preventDefault`, Button disabled, `fetch POST https://mxustcnzyqlbtkigvigb.supabase.co/functions/v1/newsletter-signup` mit `{email}` (JSON); bei OK → Erfolgskarte, `markConverted()` (localStorage); bei Fehler → Meldung, Button wieder aktiv. **Keine clientseitige Validierung außer „leer“** (`novalidate`).
- **Der Code LIFT10 ist statisch im HTML** – jeder kann ihn aus dem Quelltext lesen; die Supabase-Funktion „vergibt“ ihn nicht wirklich.
- Copy: `navigator.clipboard.writeText` → Label „Copied“ (kein Fallback, kein Reset).
- „Use code“ setzt converted und nutzt Shopifys `/discount/CODE`-Route (Cookie `discount_code`) mit Redirect auf die Produktseite.
- Escape schließt (globaler Listener). **Kein Fokus-Trap, Fokus wird beim Schließen nicht zurückgegeben**, Schritt 1 setzt keinen Fokus.

### Einschätzung
Zweistufiges „Yes/No“-Muster (Mikro-Commitment vor E-Mail-Feld) ist ein bekannter Conversion-Trick; „No thanks“ ist hier neutral formuliert (kein Confirm-Shaming) – ok. Dark-Pattern-Aspekte: Auto-Popup nach 3,5 s auf jeder Seite, Marketing-Einwilligung per „By signing up…“ statt aktiver Checkbox (DSGVO/UWG § 7 in DE nicht ausreichend, Double-Opt-in fehlt), Rabatt ohne echte E-Mail-Bindung (Code im Quelltext). Für einen Nachbau: Timer + Session-Suppression + Converted-Flag übernehmen, aber mit Checkbox/DOI, Fokus-Management und Zurückhaltung auf Mobil.

---

## 9. Sticky-ATC / Kaufleiste auf der Startseite

- `14_sticky-atc` (`#shopify-section-sticky-atc`) ist **leer** – auf der Startseite wird **keine Kaufleiste gerendert**.
- Die einzigen `position: fixed`-Elemente in den Home-Sections sind das Coach-Video-Modal und dessen Close-Button; `position: sticky` nur am Header.
- Der Coach-CSS-Selektor `#md-sticky-atc` verweist auf die Kaufleiste der **Produktseite** (`product/12_sticky_atc.html`, `id="md-sticky-atc"`, ~40 KB) – auf der Startseite also wirkungslos.
- Kaufimpulse auf der Startseite stattdessen: dauerhaft sichtbare **„Shop“-Pille im Sticky-Header** (→ `/products/gpath-pin`) und der **Checkout-Block** (Section 10) mit Direkt-Checkout.
- Zusätzlich (vor der Header-Gruppe) ein angepasster **Dawn-Cart-Drawer** (`<cart-drawer>`, volle Breite, Rabattcode-Akkordeon mit Pillen-Input 44px + Button `#4A4CFF` „Apply“-Stil, Checkout-Button 48px Pille). Auf der Startseite praktisch unbenutzt, da Cart-Icon ausgeblendet und Checkout-Block direkt zu `/checkout` geht.

---

## Gesamt-Einschätzung

**Nachbauenswert**
- Glas-Pillen-Header (54px, radius 16, blur 12/22, Schatten-Duo) + wachsendes Mobil-Menü ohne Layout-Shift (.34s cubic-bezier(0.16,1,0.3,1))
- Header-Höhe/Hero-Höhe einmalig messen und per CSS-Variable „einfrieren“
- Schwarze Coach-Section mit violett-blauem Radial-Glow und hellen Verlaufskarten
- Glas-Karte über Foto mit maskiertem Blur-Verlauf (Checkout-Block)
- Video-Overlay-Muster: html-Klasse blendet Header/Sticky aus, Escape, Fokus-Rückgabe, Video-Reset
- Konsistente Tokens: #4A4CFF / Hover #3A3BCC, Glas rgba(255,255,255,.78) + blur(22px) saturate(1.2)

**Schwächen / Dark Patterns / A11y**
- 5 volle Sterne bei „4.5“-Rating
- Auto-Popup nach 3,5 s, Einwilligung ohne Checkbox, Code im Quelltext, zwei getrennte Newsletter-Systeme
- Dialoge (Coach, Popup) ohne Fokus-Trap; Popup ohne Fokus-Rückgabe; Footer-Dropdown ohne Escape
- Logo als `<h1>`, FAQ-Antworten als `<h5>`, kein FAQ-Schema
- Video im Overlay `object-fit: cover` (beschneidet), 100dvh durch 100vh überschrieben, Scroll-Lock nur `overflow:hidden`
- Rechtliche Links hinter Dropdown (für DE-Impressum ungeeignet)
- Inaktiver Countdown-Code mit festem Datum als Altlast
- Typo-Tokens (`type-*`), Popup-CSS, Menü-JS und Persona-Canvas liegen in externen Assets – im Snapshot nicht enthalten
