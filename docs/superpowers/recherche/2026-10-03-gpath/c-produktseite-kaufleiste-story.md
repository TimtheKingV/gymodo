# Bericht C – getgpath.com: Produktseite „Gpath Pin" + „Our Story"

Quelle: Wayback-Snapshot 13.08.2026, Section-Dateien unter `scratchpad/gpath/product/` und `scratchpad/gpath/story/`, dazu `product.html` / `story.html`.
Shop-Basis: Shopify, Theme **Dawn 15.4.0** (Theme-Name „Copy of Gpath 4.0 NO BDAY SALE", `role: "treatment"` → die Seite lief in einem A/B-Test-Theme).

**Wichtig für alle Maße:** Dawn setzt `html { font-size: calc(var(--font-body-scale) * 62.5%) }` mit `--font-body-scale: 1.0` → **1rem = 10px**. Alle rem-Werte unten deshalb ×10 lesen (1.2rem = 12px).
Theme-Tokens: Schrift **Poppins** (Body + Heading), `--font-heading-scale: 1.0`, `--page-width: 120rem` (1200px), `--buttons-radius: 26px`. Akzent/Button-Farbe in allen Farbschemata **#4A4CFF** (rgb 74,76,255), Hover #3A3BCC. color-scheme-1 = weiß/#121212, color-scheme-3 = schwarz/weiß, color-scheme-5 = #4A4CFF-Fläche.

---

## 1. Inhalt wörtlich – Produktseite (Reihenfolge = Argumentationsreihenfolge)

| # | Section | Hintergrund |
|---|---------|-------------|
| 01 | Announcement-Bar: **„Free Worldwide Shipping"** | – |
| 02 | Header | – |
| 03 | main (Galerie + Kaufbox + Trust + UGC-Videos) | weiß |
| 04 | How it works (Karussell) | schwarz |
| 05 | Metriken („Progress you can measure" + Modal) | schwarz + Rautenmuster |
| 06 | Vergleichstabelle | weiß |
| 07 | Gpath Coach (KI-Coach) | schwarz + Rautenmuster |
| 08 | Rich Text: **„3000+ lifters improved their workouts."** | weiß |
| 09 | Junip Store-Reviews (Grid, 10 Reviews, Summary an, keine Media-Galerie) | weiß |
| 10 | GIF + Specs | schwarzer Kasten |
| 11 | FAQ (10 Fragen) | weiß |
| 12 | Sticky-ATC (fixed) | – |
| 13 | Newsletter „Subscribe to our emails / Be the first to know about new collections and exclusive offers." | – |
| 14 | Footer | – |
| 16 | Newsletter-Popup (Rabatt) | – |

Argumentationsbogen: Kaufen-sofort (Preis, Sterne, Trust, Social Proof) → Wie funktioniert's (3 Schritte) → Was misst es (Metriken) → Warum besser als Alternativen (Tabelle) → Mehrwert Software (Coach) → Social Proof (3000+, Reviews) → harte Fakten (Specs) → Einwände (FAQ). Sticky-ATC begleitet ab dem Moment, wo der Haupt-Button aus dem Bild ist.

### 03 main
- **Galerie:** Dawn `thumbnail_slider`, `product--medium`, `product--left`, Thumbnails auch mobil (`product--mobile-show`), mobil `grid--peek` + `slider--mobile` mit Zähler „1 / 10". **10 Bilder**, alle 1:1 (width/height 1946 bzw. 1100, `--ratio: 1.0`), `media-fit-contain`, Radius 10px (per Override `border-radius:10px !important`):
  `GpathPin_Product_No_shadow.jpg` (Freisteller, 1080×1080, auch og:image), `ProductPhotoA.jpg` … `ProductPhotoF.jpg` (Dateiname tippfehler „ProdctPhotoE.jpg"), `ProductPhotoG.png`, `ProductPhotoH.jpg`, `ProductPhotoIa.jpg`. Formate: 9× JPG, 1× PNG. Originalbreite 1300px (Bild 1: 1080px), srcset 550/1100/1300. `sizes="(min-width:1200px) 605px, (min-width:990px) calc(55vw - 10rem), (min-width:750px) calc((100vw - 11.5rem)/2), calc(100vw - 4rem)"`. Zoom per Modal (Lightbox `product-modal`), kein Hover-Zoom (`image-magnify-none`). Galerie und Info-Spalte `product__column-sticky`.
- **Titel:** `Gpath Pin` + Badge **„NEW"** (`product__badge--new`).
- **Preis:** **556,00 zł** (Snapshot aus PL, Marktwährung PLN). Durchgestrichener Preis wird gerendert als „0,00 zł" (Compare-at im Markt nicht gesetzt → Sale-Block faktisch leer/versteckt). Im Tracking-JSON (`stape-product-data`) aber `price: 55600, compare_at_price: 64200` → **642,00 zł Alt / 556,00 zł Sale** (−13,4 %). Shop-Basiswährung **EUR**, Kurs `Shopify.currency.rate = 4.30508` → umgerechnet ca. **129 € (Alt ca. 149 €)** – Ableitung, nicht direkt im Snapshot sichtbar.
- „Taxes included."
- **Bewertung:** Junip-Sterne, Farbe #FDB600, 20×20px Sterne, **4.67 / 5 aus (102)** Reviews (Füllbreite 93.4 %).
- **Button:** „Add to cart" (full width, primary #4A4CFF). Keine Mengenwahl, keine Varianten (eine Variante `49973835858256`, „Default Title"), kein Dynamic-Checkout-Button sichtbar. Pickup-Availability-Block (zeigt im Snapshot „Couldn't load pickup availability / Refresh").
- **Trust-Badges** (eine Zeile, `space-between`): 🇵🇱-Flagge (SVG weiß/#dc143c) **„Made in Poland"**, Icon **„2 Year Warranty"**, Icon **„14 Days Returns"**. Schrift 1.1rem (11px)/500, Icons 1.75rem (17.5px); mobil ≤749px 1rem (10px), Icons 1.5rem.
- **UGC-Videos:** H2 **„Trusted by 3000+ Lifters"**, darunter **„2 423 321+ reps tracked"**. 4 Hochkant-Videos (MP4 1080p, `muted loop playsinline preload=metadata`) mit Postern `RafalUGC.png`, `KarolinaUGC.png`, `TomekUGC.png`, `Unboxing.png` → Namen **Rafał, Karolina, Tomek** + Unboxing. Horizontal scrollbar; Desktop Prev/Next-Buttons scrollen um 60 % der Grid-Breite (`scrollBy({left: ±offsetWidth*0.6, behavior:'smooth'})`, Buttons `small-hide`). Klick auf Play → `muted=false`, `controls=true`, play, alle anderen Lifter-Videos pausieren; Klasse `is-playing` blendet Play-Button aus.
- Unsichtbar, aber im ld+json/meta description (Produktbeschreibung): *„You've been putting in the work. But without the right data, you're training blind - guessing whether you're improving, hoping the effort is paying off. Gpath Pin changes that. Clip it onto your barbell or machine and let it do the rest. Gpath automatically tracks every rep, every set, and every session, turning your raw effort into clear, actionable data. The kind of analysis that used to require a professional coach. Now it's in your pocket. Works with barbells, weight stack machines, and cable machines. Compatible with iOS and Android. Core features free. Advanced insights available with Gpath Premium."*
- ld+json: `Product`, brand „Gpath Shop", category „Exercise Machine & Equipment Sets", Offer price „556.00" PLN, InStock. **Kein `aggregateRating`** im ld+json (Junip-Sterne nur visuell).
- Section-Padding: 27/9px mobil, 36/12px ≥750px. Zusätzlich CSS, das in Reviews Datumsangaben und Up-/Downvote-Buttons ausblendet (`[class*="vote"]` u. a. – sehr breiter Selektor).

### 04 How it works (schwarz)
H2 **„How it works?"**
1. **Attach Gpath** – „Simply clip Gpath onto your barbell or weight stack machine." (Video MP4 1080p, autoplay nur aktive Slide)
2. **Track Automatically** – „Gpath tracks your reps, tempo, and more, to turn it into simple insights." (`GpathPin5.jpg`, 800×800)
3. **Get Insights** – „Open the app to view strength gains and other workout insights." (`gpathPin3.jpg`, 800×800)
Fortschrittsanzeige: 1 Attach · 2 Track · 3 Insights.

### 05 Metriken (schwarz, Rautenmuster)
Kopfbild Desktop `gpathApp.png`, mobil `691_1x_shots_so.png` (App-Mockups). Zwischenüberschrift (h3) **„Progress you can measure"**. 4er-Grid:
- **Velocity** – „Track weight speed live to maximize strength & explosiveness."
- **Performance Index** – „Score combining 5 parameters into one powerful number."
- **Power** – „Real-time power output in watts. Know how hard you're pushing."
- **GPE** – „Tracks set effort to help you train at the right intensity."
Button (weiße Pille, Radius 50px) **„View All Metrics"** → Modal **„Tracked Metrics"** mit 9 Einträgen:
Velocity (wie oben) · Performance Index – „Weekly score combining strength, consistency, and others into one powerful number." · Power · GPE · **Acceleration** – „Tracks how quickly you build speed to measure explosiveness" · **Lowering Control** – „Checks if you are controlling the movement of the weight down." · **Mean Velocity** – „Average bar speed during the lift to guide your training intensity." · **Propulsive Velocity** – „Measures bar speed during acceleration to track your true power output." · **Eccentric Velocity** – „Tracks how fast you lower the weight to optimize muscle growth and control."
Fußzeile: „All metrics are tracked automatically during your training sessions."

### 06 Vergleichstabelle (weiß)
H2 **„Compare Products"**, Unterzeile „See how Gpath Pin compares to other solutions".

| Kriterium | Gpath Pin (Produktbild, Spalte #f5f5f5) | Training Apps | VBT Devices |
|---|---|---|---|
| Full workout tracking | ✓ | ✓ | ✗ |
| Easy to understand | ✓ | ✓ | ✗ |
| Detailed workout metrics | ✓ | ✗ | ✓ |
| Real time feedback | ✓ | ✗ | ◐ limited (amber) |
| Long term vision | ✓ | ✗ | ✓ |

Farben: check #22c55e, cross #ef4444, limited #f59e0b; Icons 28px (mobil 22px). Tabelle `table-layout: fixed`, erste Spalte 30 % (mobil 35 %), restliche 23.33 % (mobil 21.67 %), Zellpadding 2rem 1rem (≥750) / 1rem .5rem (mobil), Schrift 1.25rem (12.5px) überall, Zeilentrenner rgba(0,0,0,.1), Radius 10px, Kopfbild max 120px (mobil 80px). Keine Wettbewerber namentlich genannt – nur Kategorien.

### 07 Gpath Coach (schwarz, Rautenmuster)
H2 **„Understand more with Gpath Coach"**, Sub: „Get personalized guidance and actionable advice from your own coach based on your own data."
Hochkant-Video 9:16, max-width 360px, Radius 10px; Poster `fallbackImageV3.jpg` (720×1280) mit `blur(1.5px)` + `scale(1.12)`, zentraler Play-Button (3.2rem Kreis, rgba(0,0,0,.6), CSS-Dreieck). Klick → `controls=true`, play, Poster/Button blenden aus (opacity 0.25s/0.2s).
3 Feature-Karten (Bild 400×700 PNG, App-Screens):
- **Get answers from your data** – „Ask questions about data gathered by Gpath Sensor. Finally, a device that can see into your real workout metrics." (`OwnData.png`)
- **Find trends and break through plateaus** – „Spot patterns in your training and know exactly when to push harder or pull back." (`FindTrends.png`)
- **Personalised training plans** – „Based on your recovery, workload, and real training data from Gpath Sensor." (`trainingPlans.png`)
Karten: Grid 1fr 1fr (Text | Bild), min-height 320px, bg rgba(255,255,255,.04), Border rgba(255,255,255,.08), Radius 16px; Bildseite Verlauf `linear-gradient(180deg, rgba(74,76,255,.1), transparent)`, Bild `object-fit: cover; object-position: center top`. Titel 16px/500, Text 12px opacity .8.

### 08 / 09 Social Proof
„**3000+ lifters improved their workouts.**" (h1-Stil, zentriert, padding-top 30/40px) + Junip-Store-Reviews (`data-layout=grid`, `data-reviews-count=10`, Summary an, Media-Galerie aus). Inhalt der Reviews wird per JS nachgeladen → nicht im Snapshot.

### 10 Specs
GIF `gpathRender.gif` (800×450, 3D-Rendering) in schwarzem Kasten, Label oben links **„SPECS"** (uppercase, Glas-Chip rgba(0,0,0,.7) + blur 10px, padding 12px 18px, Radius 8px).
| Wert | Label |
|---|---|
| 8hrs+ | Battery Life |
| 32g | Weight |
| 57x30x17 mm | Size |
| Bluetooth 5.0 | Connectivity |
| USB-C | Charging |
| 6-axis | Sensor |

### 11 FAQ (H2 „FAQ", Dawn-Accordion, 10 Einträge)
1. **Do I need anything else to use Gpath?** – No, everything you need to start using Gpath Pin during your workout is included in the box!
2. **What if I have pacemaker?** – Gpath Pin uses Bluetooth connectivity and magnets. If you have a pacemaker, please consult your doctor before using the device to ensure it's safe for you.
3. **How do I charge the Gpath Pin?** – Gpath Pin charge via USB C and come with a charging cable.
4. **Does it work with iOS and Android?** – Yes. The Gpath app is available on both the App Store and Google Play.
5. **How do I update my Gpath Pin?** – Through the app. When a firmware update is available, you'll get a notification in the Gpath app. Just follow the steps to update your Pin over Bluetooth — it's fast and easy.
6. **Can I use Gpath Pin without connecting to my phone?** – Not yet. Right now, Gpath Pin needs to be connected to the Gpath app on your phone to record and track your workouts.
7. **What should I do if I experience an issue with my sensor?** – Contact our support team. Just use the support form linked at the bottom of this page. We'll help you out as quickly as possible.
8. **Does it work on any machine?** – Gpath Pin uses built-in magnets to attach securely to most barbells and weight machines. Just make sure the machine has a metal weight stack or surface for it to stick to properly.
9. **Do I have to place it in a specific spot?** – Nope! On barbells, place it wherever it's secure. On machines, just snap it onto the weight stack — Gpath Pin will detect your movement and start tracking automatically.
10. **Does it work with dumbbells?** – Not fully yet. It can stick to all-metal dumbbells, but tracking is limited. We're working on dedicated accessories and algorithm upgrades to support dumbbell workouts in the near future.
Padding 27/75px mobil, 36/100px ≥750 (großer Abstand unten, damit Sticky-ATC nichts verdeckt).

### 16 Newsletter-Popup (in `sticky-gtp`)
Öffnet nach **3500 ms** (`openDelayMs`), pro Session unterdrückt (`sessionStorage 'popup-custom-dismissed'`), dauerhaft unterdrückt nach Conversion (localStorage) oder wenn Cookie `discount_code=` gesetzt.
Schritt 1: „Want to unlock discount?" – Buttons „Yes, of course!" / „No thanks".
Schritt 2: „You've got 10% OFF" / „plus access to subscriber-only news." – E-Mail-Feld „Enter your email", Button „Unlock my discount". Erfolg: „Here is your 10% OFF:" / „Your code is:" **LIFT10** (Copy-Button) + Link „Use code" → `/discount/LIFT10?redirect=/products/gpath-pin`. Legal: „By signing up, you agree to receive marketing emails. View our privacy policy and terms of service for more info." Anmeldung per `fetch` an eine **Supabase Edge Function** (`…supabase.co/functions/v1/newsletter-signup`).

---

## 2. Sticky-ATC (12_sticky_atc) – vollständig

### Markup
```
<div id="md-sticky-atc" class="color-scheme-1" aria-hidden="true" data-offset="0">
  .page-width > .page-width-inner
    .product-content: <img 80×80 lazy> + <h3.product__title.h4>Gpath Pin</h3> + .price (mobil, role=status)
    .sticky-atc-right: .price (desktop, role=status) + <product-form>
        <form method=post action=/cart/add id=product-form-…__sticky_atc>
          hidden: form_type=product, utf8, product-id=9828670734672, section-id=…__sticky_atc
          .select (display:none) > select[name=id] (1 Option, data-img)
          button[type=submit][name=add].product-form__submit.button.button--primary
             <span>Add to Cart</span> + .loading__spinner.hidden
```
- **Kein `return_to`**. Submit läuft über Dawns `<product-form>`-Custom-Element (AJAX `/cart/add`, Cart-Drawer/Notification, Spinner-Klasse `.loading`). Ohne JS normaler POST.
- Menge immer 1 (`.quantity` versteckt, nicht vorhanden).
- Button-Text im Sticky: „Add to **C**art" (groß C) vs. Hauptbutton „Add to cart" – inkonsistent, wird aber durch `text-transform: uppercase` überdeckt.

### Einblend-Logik (JS, `DOMContentLoaded`)
- **Gemessenes Element:** Hauptbutton `button[name="add"]` im Hauptformular. Suche: `#ProductInfo-<data-section des ersten [data-section]>` → sonst `.product__info-container .product-form` / `[data-type="add-to-cart-form"]` → darin `button[name="add"]` oder `#ProductSubmitButton-<id>`; Fallback Formular-Unterkante; letzter Fallback erster `button[name=add]` außerhalb von `#md-sticky-atc` und `quick-add-modal`; sonst 0.
- **Schwelle:** `threshold = window.scrollY + rect.bottom + Number(dataset.offset || 0)` = absolute Dokument-Y der **Button-Unterkante** (+ Offset 0). Bedingung `window.scrollY >= threshold` → sichtbar **genau dann, wenn die Unterkante des Hauptbuttons über den oberen Viewport-Rand hinausgescrollt ist** (Button komplett weg nach oben). Unter dem Header (sticky Header) ist der Button also schon eine Header-Höhe früher verdeckt, ohne dass die Leiste erscheint.
- **Keine Richtungserkennung, keine Hysterese**, keine Mindestdistanz. Schwelle wird **bei jedem Scroll-Frame neu berechnet** (`calculateThreshold()` in `updateStickyVisibility`).
- **Footer-Ausblendung (kein IntersectionObserver!):** pro Frame `querySelectorAll('footer[role="contentinfo"], .shopify-section-footer, footer:not([class*="collapsible"]):not([id*="collapsible"]):not([class*="faq"]):not([id*="faq"])')`, nur echte `<footer>`/`.shopify-section-footer`/`role=contentinfo`. `footerInView = true`, wenn
  1. Footer-Oberkante (absolut) **> 70 % der Dokumenthöhe** (`rect.top + scrollY > scrollHeight * 0.7`), und
  2. Footer schneidet Viewport (`rect.top < innerHeight && rect.bottom > 0`), und
  3. sichtbare Footer-Höhe `min(rect.bottom, innerHeight) - max(rect.top, 0)` **> 15 % der Viewport-Höhe**.
- **Zustandsautomat:**
  ```
  state: isVisible=false, hasShownOnce=false
  on frame:
    threshold = calcThreshold()
    footer = checkFooter()
    shouldShow = scrollY >= threshold && !footer
    if shouldShow && !isVisible:
        if !hasShownOnce: add 'first-show'; hasShownOnce=true; setTimeout(remove 'first-show', 3000)
        add 'show'; remove 'hide-for-footer'; isVisible=true
    elif (!shouldShow || footer) && isVisible:
        remove 'show'; if footer: add 'hide-for-footer'; isVisible=false
    if isVisible && innerWidth <= 989: updateButtonColor()
  ```
- **Drosselung:** `scroll`-Listener (nicht passive gesetzt) mit `ticking`-Flag → max. 1× `requestAnimationFrame` pro Frame.
- **resize:** Schwelle neu + `updateStickyVisibility()` + (≤989px) `updateButtonColor()` – ungedrosselt.
- **load:** Schwelle neu + Update (Bilder verschieben Layout). Initialer Check direkt bei DOMContentLoaded.
- **updateButtonColor (nur mobil ≤989px):** sucht pro Frame alle `.shopify-section, section, [class*="section"]`, nimmt die letzte, die die Viewport-Mitte (`innerHeight/2`) schneidet, ermittelt deren Hintergrund (transparente Eltern hochlaufen, Default weiß), WCAG-Luminanz > 0.5 → `light-section` sonst `dark-section`; bei Wechsel Klasse `transitioning` für 600 ms (Button-Transition `all 0.6s cubic-bezier(0.4,0,0.2,1)`). **Für `light-section`/`dark-section` gibt es kein CSS** → toter Code, der pro Frame teure Layout-Reads macht.
- **Preis-Synchronisierung:** **keine**. Preise sind statisch per Liquid gerendert. Synchronisiert wird nur die Variante: `change` auf `.product-form [name="id"]` (Hauptformular) → `selectField.value = value` im Sticky; `change` auf dem Sticky-Select → Bild-`src` aus `option.dataset.img`. (Bei Einzelvariante irrelevant; Hauptformular nutzt ein hidden input, das kein `change` feuert.)

### CSS – exakte Werte
Basis (alle Breiten):
- `position: fixed; bottom: 1rem (10px); left/right: 1rem; z-index: 2; padding: .5rem 0;`
- Ruhezustand: `visibility: hidden; opacity: 0; transform: translateY(100%);`
- `transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);`
- `.show { visibility: visible; opacity: 1; transform: translateY(0) }`
- `.hide-for-footer { visibility:hidden; opacity:0; transform: translateY(120%); transition: all 0.3s cubic-bezier(0.4, 0, 1, 1) }` (Ease-in beim Wegfahren)
- Erst-Animation `.first-show`: `slideUpFromBottom 0.5s cubic-bezier(0.4,0,0.2,1) both` (0 %: opacity 0, `translateY(100%) scale(0.95)` → 100 %: opacity 1, `translateY(0) scale(1)`) **plus** `pulse 2s ease-in-out 0.6s 2` (box-shadow `0 2px 8px rgba(0,0,0,.15)` → `0 2px 16px rgba(0,0,0,.25)` → zurück; 2 Durchläufe, Start nach 0.6s). Klasse nach 3000 ms entfernt.
- Basis-Hintergrund `rgba(var(--color-background), .8)` + `backdrop-filter: blur(10px)`, `border-top: .1rem solid rgba(var(--color-foreground), .08)` – wird aber auf beiden Breakpoints überschrieben.

Mobil `@media (max-width: 989px)`:
- `background: rgba(26,26,26,0.8) !important; backdrop-filter: blur(10px); border-top: none; padding: 1.25rem (12.5px) rundum; border-radius: 20px; left/right: 1rem (10px); box-shadow: 0 4px 20px rgba(0,0,0,.3), 0 2px 8px rgba(0,0,0,.2);`
- `.page-width { padding: 0 }`, `.page-width-inner { display:flex; justify-content:space-between; align-items:center; gap:1rem }`
- Links: Bild **ausgeblendet**; Titel `clamp(1.1rem, 2.5vw, 1.4rem)` (11–14px), 400, rgba(255,255,255,.9), line-height 1.3, einzeilig mit Ellipsis; darunter Preis `margin-top: 4px`, `clamp(1.1rem, 2.2vw, 1.3rem)` (11–13px), **700**, weiß, gap .5rem; Streichpreis rgba(255,255,255,.6), .875rem (8.75px), 400, line-through; „Save"-Text (`.price__savings`) versteckt.
- Rechts: nur Button. `background: #4A4CFF; color:#fff; border-radius: 10px; padding: .5rem 2.5rem (5px 25px); font-size: 1.2rem (12px); font-weight 600; uppercase; letter-spacing .12em; white-space: nowrap; box-shadow none`; Hover #3A3BCC + `0 4px 8px rgba(0,0,0,.15)`; `:active` kein Transform; Transition `background-color .2s ease, box-shadow .2s ease`. Ladezustand: Text transparent, Spinner absolut zentriert, 1.5rem (15px). Theme-Pseudo-Elemente `::before/::after` (Rahmen/Pfeil/Ripple) entfernt.
- `.shipping-info` (rechtsbündig, 0.6875rem, weiß .9) definiert, aber nicht im Markup.

Desktop `@media (min-width: 990px)`:
- `background: rgba(26,26,26,0.8) !important; backdrop-filter: blur(10px); border-radius: 20px; box-shadow: 0 4px 20px rgba(0,0,0,.3), 0 2px 8px rgba(0,0,0,.2); left/right: 2rem (20px); max-width: 1400px; margin: 0 auto;` Padding vertikal .5rem (5px) + Dawn `.page-width` horizontal (5rem = 50px ab 750px).
- `.page-width-inner { display:flex; justify-content:space-between; align-items:center; gap:2rem }`
- Links: nur Titel (Bild + linker Preis versteckt), weiß .9, `clamp(1.2rem, 1.5vw, 1.6rem)` (12–16px), Ellipsis.
- Rechts `.sticky-atc-right { display:flex; gap:1.5rem; flex-shrink:0 }`: Preis weiß (Streichpreis .6) + Button `padding: .5rem 2.5rem !important`. **Achtung:** ein unscoped Regelblock im 990er-Query setzt global `.button { padding: 12px 30px; font-size: 15px !important; min-width: unset !important }`, `.quantity { width:auto }` sowie außerhalb jeder Query `.select__select { padding-right: 0 !important }` → leakt auf **alle** Buttons/Selects der Seite. Effektiv hat der Sticky-Button daher 15px Schrift.
- Bild-Hover `scale(1.05)` 0.3s (nur relevant, wo Bild sichtbar – faktisch nirgends).

### Barrierefreiheit
- `aria-hidden="true"` **statisch und dauerhaft** auf dem Container, auch wenn sichtbar. Kein `inert`, kein `tabindex="-1"`. Im ausgeblendeten Zustand verhindert `visibility:hidden` den Fokus (ok), im sichtbaren Zustand ist der Button fokussierbar, aber für Screenreader versteckt → **WCAG-Verstoß** (fokussierbares Element in aria-hidden).
- Preise mit `role="status"` (zwei Stück, mobil/desktop) – innerhalb aria-hidden wirkungslos.
- Kein `prefers-reduced-motion`.
- **Keine `env(safe-area-inset-bottom)`** – auf iPhones mit Home-Indicator sitzt die Leiste 10px über der Unterkante (in Safari meist ok wegen Browser-UI, in Standalone/PWA kollidiert sie).
- `z-index: 2` sehr niedrig (Drawer/Popup liegen darüber – gewollt; aber Elemente mit eigenem Stacking-Kontext können sie überdecken).

---

## 3. Aufbau mobil & Interaktionen

Breakpoints im Einsatz: **749/750** (Dawn-Standard, Section-Paddings, Vergleichstabelle, How-it-works), **768/769** (Metriken, Coach, Specs, Galerie Story), **480** (Feintuning Metriken/Coach), **989/990** (Sticky-ATC, Dawn Desktop-Layout Produkt), Story-Galerie zusätzlich **1024/1025** und **1200**.

Section-Paddings (mobil → ≥750): main 27/9 → 36/12; How-it-works 39/39 → 52/52; Metriken 3rem oben (≤768: 2rem, ≤480: 0) / unten Button-Wrapper 5rem (≤768: 4rem, ≤480: 3rem); Vergleich 45/45 → 60/60; Coach 56/56 → 80/80; Rich Text 30/0 → 40/0; Specs 33/33 → 44/44; FAQ 27/75 → 36/100. Container-Seitenabstand eigener Sections 1.5rem (15px) mobil, 5rem (50px) ≥750 (≤480 Metriken: 1rem), max-width 1200px.

Schriftgrößen (px, da 1rem=10px): H2-Titel eigener Sections `calc(scale*3rem)` = 30px mobil, 40px ≥750 (Metriken-Titel 3rem → 2rem ≤768 → 1.5rem ≤480); Sublines 12.5px; Kartentitel How-it-works 17.5px; Metriken-Grid Titel 16 → 14 → 12px, Text 12 → 11 → 10px; Coach-Karten Titel 16 → 14 → 13px, Text 12 → 11 → **10px** (sehr klein); Specs mobil Titel 11px / Label **9px**.

Was mobil anders ist:
- **Galerie:** Slider mit Peek + Thumbnails + „1 / 10"-Zähler statt Desktop-Thumbnail-Slider links.
- **How it works:** Slides `flex: 0 0 100%`, `scroll-snap-type: x mandatory`, `scroll-snap-align: start`, Scrollbar versteckt. Unter dem Slider runde Nummern-Indikatoren (50×50px mobil, sonst 40×40; inaktiv rgba(255,255,255,.1) + Border .2, aktiv rgba(255,255,255,.9) mit schwarzer Zahl; Label 8.75px, inaktiv opacity .5; gap 3rem). **Desktop ≥750:** 3 Spalten nebeneinander (`flex: 0 0 33.33%`), Indikatoren ausgeblendet. JS: Klick auf Indikator → `scrollTo({left: slide.offsetLeft, behavior:'smooth'})`; Scroll-Ende per 150 ms Debounce → nächstgelegene Slide → aktiv; nur Video der aktiven Slide spielt (muted/loop), andere pausiert. Touch-Richtungserkennung (deltaX > deltaY && > 10px) wird berechnet, aber nicht genutzt. Kein Autoplay der Slides.
- **Metriken:** Kopfbild wechselt auf eigenes Mobil-Bild; Grid 4 → 2 Spalten (gap 30 → 20 → 15px). Modal: `display:flex`, Overlay rgba(0,0,0,.8) + blur 5px, Content weiß Radius 20px, max 720px / 85vh (mobil margin 20px, 80vh); Ein-/Ausblenden 0.3s Fade + SlideUp 50px; Body-Scroll gesperrt (`overflow:hidden`); Schließen per ×, Klick auf Overlay, Escape. Kein Fokus-Trap.
- **Vergleich:** bleibt echte Tabelle (kein Scroll), Spalten 35/21.67 %, Icons 22px, Kopfbild 80px.
- **Coach:** Karten 1-spaltig, Text oben (padding 1.5rem 1.25rem), Bild darunter (min-height 280px, ≤480 240px).
- **Specs:** Desktop: GIF-Kasten `height: 25vh; min-height: 300px`, Specs als Overlay unten mit Verlauf `transparent → rgba(0,0,0,.8)`, flex gap 40px, Icons 24px, Titel 12px/Label 11px. **Mobil ≤768:** GIF volle Breite oben (Radius 10px oben), Specs **unter** dem GIF im schwarzen Block, **Grid 3×2**, gap 20px, Icons 20px, Titel 11px/600, Label 9px, Radius unten 10px.
- **Trust-Badges:** 10px Schrift, column-gap .75rem.
- **Sticky-ATC:** siehe oben (Titel+Preis links, Button rechts, schwebende dunkle Glas-Pille).
- Animationen sonst: Dawn `scroll-trigger animate--slide-in` / `animate--fade-in` (Einflieg-Animationen beim Scrollen), Hover-Zeilen in Tabellen (rgba .02/.03, 0.2s), Story-Galerie Hover `scale(1.05)` 0.3s.

---

## 4. „Our Story" – Inhalt wörtlich

Seitentitel: „Our Story – Gpath". Reihenfolge:

1. **Image-Banner** (`freinds.jpg`, srcset bis 3840w, Höhe „medium", Inhalt mittig, mobil Text unter dem Bild, color-scheme-3 schwarz): H1 **„Our Story"** – „How Gpath was built from the ground up, driven by a true passion for the gym and helping people reach their goals."
2. **Rich Text** H: **„Our Philosophy"** (weiß)
3. **Rich Text** (weiß):
   > Our philosophy is simple: Make lifting smarter for as many gym enthusiasts as possible.
   > We know that devices using VBT principles are priced high not according to hardware costs, but because companies can get away with it. Worse, the data they provide is hard to implement and requires knowledge that only pros and personal trainers can efficiently use.
   > That's why we built Gpath.
   > We're two young gym enthusiasts from Gdańsk who couldn't afford this tech. So we decided to create something for ourselves and for everyone like us. A device that gives you pro-level insights without the pro-level price tag. Data that actually makes sense, not raw numbers that leave you confused. And after time it turned into a company with a team that is motivated and driven to create the best product possible.
   > Fair pricing. Simple data. Built by lifters who use it every day.
4. **Rich Text** (schwarz, color-scheme-3): H **„How it all started?"** – „Our story began in a small Polish town, where two students shared a big dream: to create something meaningful..."
5. **Timeline** (Dawn Multirow = Bild/Text-Reihen, abwechselnd links/rechts, `grid--2-col-tablet`, mobil gestapelt; Jahreszahl als Caption mit Letter-Spacing, Titel h1-Stil):
   | Jahr | Titel | Text | Bild |
   |---|---|---|---|
   | 2023 | First Prototype | Initial prototype with screen monitoring weight block movement created in **Miłosz**'s garage in **Suwałki**, Poland, demonstrating its potential. | prototype.jpg |
   | 2023 | Gym Prototype | Initial experiments at our local gym proved the concept, sparking our decision to create new features and optimimalisations. | GymPrototype.jpg |
   | 2024 | Development | We were getting ready to start engage with the gyms. Upgraded features, enhanced UX/UI but encountered a major obstacle. Realized it would take considerable time to start it by ourselves so... | IMG_0711.jpg |
   | 2024 | First Pivot | We decided that we must make something to bring to every gym since we moved to the larger Polish city Gdansk and didn't know anyone here. | gpath_connection… .jpg |
   | 2024 | Development | We had a great time using it and it brought some excitement to our workout sessions. We made ongoing updates to the system and app we had set up beforehand. At this point, we could also keep track of weight stack machine workouts. | IMG_1548… .jpg |
   | 2025 | Second Pivot | We faced a challenge in tracking our preferred exercise, bench press, prompting us to shift the model towards a more VBT-centric approach rather than only block machines. | DSC08548… .jpg |
   | 2025 | Development | Here we are, building upon our Gpath community, integrating new functionalities, and solving any challenges. With many exciting ideas ahead, we look forward to a promising 2026 for Gpath! | IMG_1707… .jpg |
   (Tippfehler im Original: „optimimalisations", „start engage". Nur ein Name genannt: Miłosz.)
6. **Bildergalerie** H2 **„Photos from the journey"**, Sub „See how Gpath was built." – 12 Fotos (JPG). Grid: 2 Spalten (gap 10px) mobil → 3 Spalten (750–1024, gap 15px) → 4 Spalten ≥1025 (gap 20px, ≥1200 25px), Kacheln 1:1 bzw. ≥1025 **4:5** (min-height 280/320px), Radius 10px, `object-fit: cover`, Hover scale 1.05.
7. Leere App-Section, Newsletter, Footer, Popup (wie Produktseite).
Story-Argumentation: Mission/Feindbild („VBT-Geräte überteuert, Daten unverständlich") → Wir sind wie du (zwei junge Lifter aus Gdańsk) → Werte-Claim „Fair pricing. Simple data. Built by lifters…" → Chronologie mit Pivots (Ehrlichkeit, Garagen-Mythos) → Fotobeweise.

---

## 5. Einschätzung

**Nachbauenswert**
- Klare Verkaufsdramaturgie: Kaufbox oben mit Preis + Sterne + 3 Trust-Badges + UGC-Videos mit harten Zahlen („3000+ Lifters", „2 423 321+ reps tracked"), dann 3-Schritte-Erklärung, Metriken, Kategorie-Vergleich (ohne Wettbewerbernamen – rechtlich unkritisch), Software-Mehrwert, FAQ mit ehrlichen „Not yet"-Antworten.
- Sticky-ATC als **schwebende dunkle Glas-Pille** (Radius 20px, rgba(26,26,26,.8) + blur 10px, Abstand 10/20px vom Rand) – optisch hochwertig, auf hellen und dunklen Sections lesbar. Erscheinen erst, wenn der Haupt-Button weg ist, Ausblenden am Footer. Erst-Animation (Slide + Scale + 2× Schatten-Puls) lenkt Aufmerksamkeit dezent.
- Specs-Block: Desktop-Overlay über Render-GIF, mobil sauberes 3×2-Grid.
- Our-Story: „Underdog gegen überteuerte Profi-Geräte", Timeline mit Pivots + Fotogalerie – glaubwürdig und billig zu produzieren.
- Popup mit 2-Schritt-Opt-in (erst „Ja", dann E-Mail) und direktem Discount-Link.

**Schwächen (beim Nachbau besser machen)**
- Sticky-Logik: pro Scroll-Frame `getBoundingClientRect` + `querySelectorAll` (Schwelle, Footer, alle Sections für Farberkennung) → Layout-Thrashing; besser **zwei IntersectionObserver** (Haupt-Button, Footer) ohne rAF-Loop. Farberkennung ist toter Code.
- Schwelle ignoriert Sticky-Header (Leiste erscheint verspätet); keine Hysterese (bei Grenzposition Flackern möglich, durch Transition kaschiert).
- `aria-hidden="true"` dauerhaft trotz fokussierbarem Button; kein `inert` im versteckten Zustand, kein `prefers-reduced-motion`, keine `safe-area-inset-bottom`.
- Keine echte Preis-Synchronisierung; Streichpreis-Logik kaputt („0,00 zł" im DOM, Compare-at nur im Tracking-JSON).
- CSS-Leaks: globale `.button { font-size:15px !important; padding:12px 30px }`, `.quantity`, `.select__select` aus der Sticky-Section; Review-CSS blendet alles mit `[class*="vote"]` aus.
- Kein `aggregateRating` im Produkt-ld+json trotz 102 Reviews (SEO-Potenzial verschenkt).
- Sehr kleine Schriften mobil (9–11px in Specs, Coach, Metriken) – unter Lesbarkeitsgrenze.
- Metrik-Modal ohne Fokus-Trap/`role="dialog"`-Management; Karussell-Indikatoren sind `div`s ohne Button-Rolle/Tastaturbedienung.
- Text-Inkonsistenzen/Tippfehler (Performance Index unterschiedlich beschrieben, „Add to Cart" vs. „Add to cart", „ProdctPhotoE", „optimimalisations", „Gpath Pin charge via USB C and come…").
