import type { Kalendertag } from "./woche";
import styles from "./kalender.module.css";

/**
 * Die Kalenderleiste des Kursplans (Testnotiz 25.09., #1): "eine
 * Wocheneinstellung wie in der App", dazu der Wechsel zwischen Woche und
 * Monat.
 *
 * Der Wochenstreifen folgt KurseWochenView.swift: sieben Zellen mit
 * Buchstabe und Tagesnummer, heute mit Ring, ein Punkt an Tagen mit
 * Kursen. Anders als in der App filtert ein Tipp nicht -- das Portal zeigt
 * die Woche ohnehin ganz, der Tipp springt zum Abschnitt des Tages.
 *
 * Alles hier sind <a>, kein <Link>: jeder Wechsel aendert nur den
 * Suchparameter, und genau den laesst Nexts Client-Router im
 * Produktionsbau ins Leere laufen (ausfuehrlich in page.tsx). Die Anker
 * im Streifen bleiben ohnehin im Dokument.
 */

function beschriftung(tag: Kalendertag): string {
  if (tag.kurse === 0) return tag.name;
  return `${tag.name} · ${tag.kurse} ${tag.kurse === 1 ? "Kurs" : "Kurse"}`;
}

export function AnsichtUmschalter({
  ansicht,
  wocheHref,
  monatHref,
}: {
  ansicht: "woche" | "monat";
  wocheHref: string;
  monatHref: string;
}) {
  return (
    <nav className={styles.umschalter} aria-label="Ansicht">
      <a
        href={wocheHref}
        className={ansicht === "woche" ? styles.umschalterAktiv : styles.umschalterEintrag}
        aria-current={ansicht === "woche" ? "page" : undefined}
      >
        Woche
      </a>
      <a
        href={monatHref}
        className={ansicht === "monat" ? styles.umschalterAktiv : styles.umschalterEintrag}
        aria-current={ansicht === "monat" ? "page" : undefined}
      >
        Monat
      </a>
    </nav>
  );
}

/** Pfeil zurueck/vor -- das sichtbare Zeichen ist ein Pfeil, der Name steht
    im aria-label ("Vorige Woche"), damit Screenreader und Tests ihn finden. */
export function Blaettern({ href, label, richtung }: { href: string; label: string; richtung: "zurueck" | "vor" }) {
  return (
    <a href={href} className={styles.pfeil} aria-label={label}>
      <span aria-hidden="true">{richtung === "zurueck" ? "‹" : "›"}</span>
    </a>
  );
}

export function Wochenstreifen({ tage }: { tage: Kalendertag[] }) {
  return (
    <ol className={styles.streifen} aria-label="Tage der Woche">
      {tage.map((tag) => (
        <li key={tag.iso}>
          <a
            href={`#tag-${tag.iso}`}
            className={tag.istHeute ? styles.zelleHeute : styles.zelle}
            aria-label={beschriftung(tag)}
            aria-current={tag.istHeute ? "date" : undefined}
          >
            <span className={styles.buchstabe} aria-hidden="true">
              {tag.buchstabe}
            </span>
            <span className={styles.nummer} aria-hidden="true">
              {tag.nummer}
            </span>
            <span className={tag.kurse > 0 ? styles.punkt : styles.punktLeer} aria-hidden="true" />
          </a>
        </li>
      ))}
    </ol>
  );
}

const KOPF = ["M", "D", "M", "D", "F", "S", "S"];

export function Monatsraster({ tage, basis }: { tage: Kalendertag[]; basis: string }) {
  return (
    <div className={styles.monat}>
      <div className={styles.monatKopf} aria-hidden="true">
        {KOPF.map((buchstabe, index) => (
          <span key={index}>{buchstabe}</span>
        ))}
      </div>
      <ol className={styles.monatRaster} aria-label="Tage des Monats">
        {tage.map((tag) => (
          <li key={tag.iso}>
            <a
              href={`${basis}?woche=${tag.iso}#tag-${tag.iso}`}
              className={[
                styles.monatZelle,
                tag.istHeute ? styles.monatHeute : "",
                tag.imMonat ? "" : styles.monatAussen,
              ].join(" ")}
              aria-label={beschriftung(tag)}
              aria-current={tag.istHeute ? "date" : undefined}
            >
              <span className={styles.monatNummer} aria-hidden="true">
                {tag.nummer}
              </span>
              {tag.kurse > 0 ? (
                <span className={styles.monatAnzahl} aria-hidden="true">
                  {tag.kurse} {tag.kurse === 1 ? "Kurs" : "Kurse"}
                </span>
              ) : null}
            </a>
          </li>
        ))}
      </ol>
    </div>
  );
}
