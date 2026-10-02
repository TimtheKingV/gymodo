# Prompt: Landingpage-Referenz getgpath.com analysieren (für gymodo)

> Diesen Text als Startnachricht in eine neue Session kopieren.

---

## Kontext

Wir bauen die Landingpage von **gymodo** neu (Monorepo, Web-App in `apps/web`, Next.js 15 + React 19 + Supabase, CSS Modules; aktuelle Startseite: `apps/web/app/page.tsx` mit `apps/web/app/einstieg/landeseite.module.css`). Die heutige Seite ist sehr schlicht, richtet sich nur an Trainer und schickt Mitglieder weg („im Web gibt es nichts für dich zu tun“).

Als Referenz dient **https://getgpath.com** – ein Workout-Tracker-Gadget („Gpath Pin“) mit App und KI-Coach, ähnlich dem Sensor, den wir bauen wollen. Die Seite gefällt uns vor allem **auf dem Handy**.

### Geplante Struktur bei uns
- **`/` – Endnutzer:** App (und später Sensor) im Stil von Gpath, mobil zuerst, mit einer Kaufleiste, die beim Hochscrollen unten einfährt.
- **`/studios` – Studios (B2B):** Studiomodul mit NFC-Tags am Gerät buchen, Login/Registrierung, Kontakt.
- Zwei Geschäftsmodelle, die sich stützen sollen: Studios mit Tags bringen Mitglieder in die App, App-Nutzer fragen ihr Studio nach gymodo.

### Entscheidung: kein Shopify – alles selbst mit Stripe
- Wir bauen die Seite **selbst in Next.js**, kein Shopify, kein Theme.
- **Bezahlung über Stripe:**
  - Studiomodul (B2B-Abo) → **Stripe Billing** (Abos, Rechnungen, Kundenportal), angebunden an Supabase.
  - Sensor (physisch, zunächst kleine Stückzahl / Vorbestellung) → **gehosteter Stripe Checkout** mit Lieferadresse und Stripe Tax. **Kein selbst gebautes Zahlformular.** Die Kaufleiste führt direkt zu Stripe Checkout (wie Gpath direkt zur Shopify-Kasse springt).
  - Bestellungen, Mails, Versand bauen wir selbst schlank nach Bedarf; Shopify (ggf. headless) erst, wenn Versand/Retouren/Marketing-Apps wirklich nötig werden.
- Hinweis: Digitale Abos, die *in* der iOS-App verkauft werden, unterliegen den App-Store-Regeln (In-App-Kauf). Sensor und B2B-Studiomodul sind nicht betroffen.
- Achtung Widerspruch: Im Fuß unserer Seite steht „gymodo misst nichts“ – mit Sensor muss das angepasst werden.

---

## Was wir über getgpath.com schon wissen (Stand 02.10.2026)

Ermittelt aus HTML/CSS/JS der Startseite und von `/products/gpath-pin`.

### Technik
- Shopify, Theme „Gpath 4.3 BackToWorkPromo“ auf Basis von **Dawn 15.4.0**, `theme_store_id: null` → hochgeladene, stark umgebaute Kopie, Theme-Nr. 73 (viele Iterationen).
- Von Dawn nur Gerüst, Header, Footer, Newsletter, FAQ-Akkordeon, Warenkorb. **Alle Inhaltsbereiche selbst gebaut.**
- Schrift **Poppins**, Akzentblau `#4a4cff`, violett-blaue Verläufe auf Schwarz.

### Startseite – Reihenfolge der Bereiche (Section-IDs)
1. Announcement-Bar
2. Header: schwebende Pillen-Navigation (54 px hoch, max. 72 rem breit, `rgba(255,255,255,.86)` + leichter Blur, immer sticky; der Hero liegt per negativem Margin darunter)
3. `custom_hero` – Vollbild-Hero, Höhe per JS beim Laden auf `window.innerHeight` fixiert (nicht `dvh`, damit iOS beim Ein-/Ausklappen der Adressleiste nicht ruckelt); Video nur auf Mobil (≤ 989 px), nur wenn sichtbar (IntersectionObserver), respektiert `prefers-reduced-motion`
4. `stats_loop_slider` – Zahlen-Laufband
5. `workout_clarity` – Schalter **„Without Gpath / With Gpath“**: ohne = chaotisch herumfliegende Pillen mit Warn-Badges, mit = aufgeräumter, durchlaufender Feed
6. `how_it_works_carousel` – „So funktioniert's“-Karussell
7. `get_gpath_cta` – Kauf-CTA
8. `pros_use_it` – Social Proof („Profis nutzen es“)
9. `gpath_coach` – KI-Coach mit Video als Vollbild-Overlay (blendet Header und Kaufleiste aus)
10. `checkout_gpath` – Kaufblock
11. `collapsible_content` – FAQ
12. Newsletter, Footer

### Produktseite `/products/gpath-pin`
Bereiche: main (Produkt), features_phone, gpath_coach_section, comparison_chart, rich_text, Custom-Section, section_gif_specs, parameter_list (Specs), collapsible_content (FAQ), **sticky_atc**, Newsletter, Footer.

### Die Kaufleiste beim Hochscrollen (`#md-sticky-atc`, nur Produktseite)
- **Erscheint**, sobald man am Haupt-Kaufbutton vorbeigescrollt ist.
- **Runterscrollen → verschwindet, Hochscrollen → kommt wieder** (Schwelle: Scroll-Änderung > 4 px). Knapp unterhalb der Schwelle (< 24 px) bleibt sie sichtbar.
- Ausgeblendet, sobald der Footer sichtbar ist.
- Scroll-Handler über `requestAnimationFrame` gedrosselt; Schwelle wird bei `resize`/`load` neu berechnet.
- Optik: `position: fixed; bottom: 1.2rem; left/right: 1.2rem; max-width: 42rem` (Desktop 44rem / 1.6rem), dunkles Glas `rgba(28,28,30,.72)`, Einblenden `translateY(110%) → 0`, 350 ms `cubic-bezier(.4,0,.2,1)`, beim ersten Mal eigene Slide-up-Animation (450 ms).
- Inhalt: Produktname, drei Merkmale mit Icons („Auto Tracking“, „Gpath Coach“, „Available on iOS and Android“), Produktbild, Button mit durchgestrichenem Altpreis + Sale-Preis + „Shop Sale“. Formular mit `return_to=/checkout` → **direkt zur Kasse**, ohne Warenkorb.
- Preis wird mit dem Hauptpreis der Seite synchron gehalten.

### Shopify-Apps (nur zur Info – bei uns per Stripe/eigenem Code oder später)
Junip (Reviews), UpPromote + Secomapp (Affiliate), Triple Whale + Stape (Tracking/serverseitiges GTM), Essential A/B Testing, AfterSell (Upsell nach Kauf), Shopify Forms.

---

## Aufgabe für diese Session

1. **Seite erneut analysieren** – Startseite, `/products/gpath-pin`, `/pages/our-story` und weitere verlinkte Seiten:
   - **Inhalte:** alle Überschriften, Claims, Fließtexte, Zahlen im Stats-Slider, Schritte im „How it works“, FAQ-Fragen, Social-Proof-Elemente, Preise/Angebote, CTA-Texte. Tonalität und Argumentationsreihenfolge (Problem → Lösung → Beweis → Kauf) herausarbeiten.
   - **Aufbau mobil:** Abstände, Schriftgrößen, Bildformate, welche Bereiche auf dem Handy anders aussehen.
   - **Animationen/Interaktionen:** Clarity-Schalter, Karussell, Stats-Loop, Video-Overlay, Kaufleiste – mit konkreten Werten (Dauer, Kurven, Schwellen).
2. **Übertragen auf gymodo:** pro Gpath-Bereich vorschlagen, was das Pendant bei uns wäre – getrennt für `/` (Endnutzer) und `/studios` (Studios). Inhalte als Platzhalter-Entwurf auf Deutsch.
3. **Technischer Plan** für den Nachbau in `apps/web` (Next.js, CSS Modules, keine neuen schweren Abhängigkeiten), inkl. Kaufleiste als wiederverwendbare Komponente und Stripe-Anbindung (Checkout für Sensor, Billing für Studiomodul) – erst Plan, noch nichts umsetzen.

### Technische Hinweise zur Analyse
- Abrufen mit `curl -sSL -A "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" <url>`; Section-Inhalte stehen im HTML (`id="shopify-section-…"`), Section-CSS/JS jeweils inline.
- Theme-Assets liegen unter `https://getgpath.com/cdn/shop/t/73/assets/<datei>` (Nummer kann sich ändern; aktuelle steht im HTML in `Shopify.theme`).
- Für echte Screenshots: Playwright mit Chromium unter `/opt/pw-browsers`. In der Cloud-Umgebung scheiterte das an `ERR_CERT_AUTHORITY_INVALID` (Proxy-CA) – Hinweise in `/root/.ccr/README.md` prüfen, TLS-Prüfung **nicht** abschalten. Sonst aus dem Quelltext analysieren.
- Preise erscheinen je nach Standort in anderer Währung (wir bekamen PLN/zł).
