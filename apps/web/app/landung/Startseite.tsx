import { APP_STORE_URL } from "@/lib/appStore";
import aktion from "./Aktion.module.css";
import { Fragen } from "./Fragen";
import { Fuss } from "./Fuss";
import { Held } from "./Held";
import { Kaufleiste } from "./Kaufleiste";
import { Kopf } from "./Kopf";
import { Laufband } from "./Laufband";
import { OhneMit } from "./OhneMit";
import { Schritte } from "./Schritte";
import styles from "./Startseite.module.css";
import {
  CTA,
  FAKTEN,
  FRAGEN,
  HELD,
  KAUFLEISTE,
  MARKE,
  OHNE_MIT,
  PRODUKTGRENZE,
  SCHRITTE,
  SCHRITTE_TITEL,
  VERLAUF,
} from "./texte";

// Masse der Screenshots aus Aufgabe 9 (750 px breit).
const BILD = { width: 750, height: 1630 };

/**
 * Reihenfolge nach Gpath (Spec 1.1): Problem, Beweis, Problem erlebbar,
 * Muehelosigkeit, Kauf, Zusatznutzen, Einwaende. Flaechen wechseln bg und
 * surface (E2). Ohne Verkauf, ohne Sensor, ohne Studio-Bruecke (Etappe 1).
 */
export function Startseite() {
  return (
    <div className={styles.startseite}>
      <Kopf />
      <main>
        <Held
          titel={HELD.titel}
          vorspann={HELD.vorspann}
          aktion={{ href: APP_STORE_URL, text: HELD.aktion }}
          nebenlink={{ href: "#so-gehts", text: HELD.nebenlink }}
          bild={{ ...HELD.bild, ...BILD }}
        />
        <Laufband eintraege={FAKTEN} />
        <OhneMit titel={OHNE_MIT.titel} marke={MARKE} ohne={OHNE_MIT.ohne} mit={OHNE_MIT.mit} />
        <Schritte id="so-gehts" titel={SCHRITTE_TITEL} schritte={SCHRITTE} bildmasse={BILD} />
        <section id="landung-cta" className={styles.cta} aria-labelledby="landung-cta-titel">
          <h2 id="landung-cta-titel" className={styles.ctaTitel}>
            {CTA.titel}
          </h2>
          <p className={styles.ctaText}>{CTA.text}</p>
          <a href={APP_STORE_URL} className={aktion.hauptaktion}>
            {CTA.aktion}
          </a>
        </section>
        <section className={styles.verlauf} aria-labelledby="verlauf-titel">
          <h2 id="verlauf-titel" className={styles.abschnittTitel}>
            {VERLAUF.titel}
          </h2>
          <ul className={styles.karten}>
            {VERLAUF.karten.map((k) => (
              <li key={k.titel} className={styles.karte}>
                <h3 className={styles.karteTitel}>{k.titel}</h3>
                <p className={styles.karteText}>{k.text}</p>
              </li>
            ))}
          </ul>
        </section>
        <Fragen id="fragen" titel="Fragen" fragen={FRAGEN} />
      </main>
      <Fuss id="landung-fuss" produktgrenze={PRODUKTGRENZE} />
      <Kaufleiste
        anker="held-aktion"
        verdecker={["landung-cta", "landung-fuss"]}
        titel={KAUFLEISTE.titel}
        merkmale={KAUFLEISTE.merkmale}
        aktion={{ href: APP_STORE_URL, text: KAUFLEISTE.aktion }}
      />
    </div>
  );
}
