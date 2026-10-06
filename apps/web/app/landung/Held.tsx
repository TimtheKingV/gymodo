import Image from "next/image";
import aktion from "./Aktion.module.css";
import styles from "./Held.module.css";
import { HeldVideo } from "./HeldVideo";

type Props = {
  titel: string;
  vorspann: string;
  aktion: { href: string; text: string };
  nebenlink: { href: string; text: string };
  bild: { src: string; alt: string; width: number; height: number };
  video?: { src: string; poster: string };
};

/**
 * Text oben, Bild in der Mitte, Knopf unten -- mobil die Gpath-Anordnung
 * (Spec 2). Keine Einblendanimation: die erste Ansicht steht sofort.
 */
export function Held({ titel, vorspann, aktion: haupt, nebenlink, bild, video }: Props) {
  return (
    <section className={styles.held} aria-labelledby="held-titel">
      <div className={styles.text}>
        <h1 id="held-titel" className={styles.titel}>
          {titel}
        </h1>
        <p className={styles.vorspann}>{vorspann}</p>
      </div>
      <div className={styles.bild}>
        <Image
          src={bild.src}
          alt={bild.alt}
          width={bild.width}
          height={bild.height}
          priority
          sizes="(min-width: 990px) 40vw, 90vw"
          className={styles.bildDatei}
        />
        {video ? <HeldVideo src={video.src} poster={video.poster} /> : null}
      </div>
      <div className={styles.aktionen}>
        <a id="held-aktion" href={haupt.href} className={`${aktion.hauptaktion} ${styles.knopf}`}>
          {haupt.text}
        </a>
        <a href={nebenlink.href} className={styles.nebenlink}>
          {nebenlink.text}
        </a>
      </div>
    </section>
  );
}
