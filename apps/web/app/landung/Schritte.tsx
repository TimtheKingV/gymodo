import Image from "next/image";
import styles from "./Schritte.module.css";
import { SchritteIndikatoren } from "./SchritteIndikatoren";

export type Schritt = { titel: string; text: string; bild: { src: string; alt: string } };

/**
 * Mobil ein Scroll-Snap-Slider wie auf Gpaths Produktseite, ab 750 px drei
 * Spalten. Keine eigene Animation: das native Scrollen bringt Impuls und
 * Einrasten mit.
 */
export function Schritte({
  id,
  titel,
  schritte,
  bildmasse,
}: {
  id: string;
  titel: string;
  schritte: readonly Schritt[];
  bildmasse: { width: number; height: number };
}) {
  const ids = schritte.map((_, i) => `${id}-${i + 1}`);
  return (
    <section id={id} className={styles.abschnitt} aria-labelledby={`${id}-titel`}>
      <h2 id={`${id}-titel`} className={styles.titel}>
        {titel}
      </h2>
      <ol className={styles.liste}>
        {schritte.map((s, i) => (
          <li key={s.titel} id={ids[i]} className={styles.schritt}>
            <div className={styles.bildRahmen}>
              <Image
                src={s.bild.src}
                alt={s.bild.alt}
                width={bildmasse.width}
                height={bildmasse.height}
                sizes="(min-width: 750px) 30vw, 80vw"
                className={styles.bildDatei}
              />
            </div>
            <p className={styles.nummer} aria-hidden="true">
              {i + 1}
            </p>
            <h3 className={styles.schrittTitel}>{s.titel}</h3>
            <p className={styles.text}>{s.text}</p>
          </li>
        ))}
      </ol>
      <SchritteIndikatoren ids={ids} titel={schritte.map((s) => s.titel)} />
    </section>
  );
}
