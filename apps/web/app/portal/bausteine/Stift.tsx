import Link from "next/link";
import styles from "./bausteine.module.css";

/**
 * Der kleine Stift oben rechts an einer Karte (Testnotiz 22.09., #1 und
 * #12): ersetzt den breiten Textknopf "Bearbeiten", der auf dem Telefon
 * die halbe Zeile belegte. Der Name der Zeile steht im aria-label -- eine
 * Liste aus lauter gleichen Stiften sagt einem Screenreader sonst nicht,
 * welche Zeile gemeint ist.
 *
 * `offen` zaehlt, was an diesem Eintrag noch fehlt (z. B. das Video einer
 * Uebung). Die Zahl steht als kleine Marke am Stift und im aria-label.
 */
export function StiftIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z" />
    </svg>
  );
}

function Marke({ offen }: { offen: number }) {
  return offen > 0 ? (
    <span className={styles.stiftMarke} aria-hidden="true">
      {offen}
    </span>
  ) : null;
}

function beschriftung(label: string, offen: number): string {
  if (offen === 0) return label;
  return `${label} (${offen} ${offen === 1 ? "Punkt offen" : "Punkte offen"})`;
}

export function StiftLink({
  href,
  label,
  offen = 0,
}: {
  href: string;
  label: string;
  offen?: number;
}) {
  return (
    <Link href={href} className={styles.stift} aria-label={beschriftung(label, offen)}>
      <StiftIcon />
      <Marke offen={offen} />
    </Link>
  );
}

export function StiftKnopf({
  label,
  offen = 0,
  gedrueckt,
  onClick,
  controls,
}: {
  label: string;
  offen?: number;
  gedrueckt: boolean;
  onClick: () => void;
  controls?: string;
}) {
  return (
    <button
      type="button"
      className={gedrueckt ? styles.stiftAktiv : styles.stift}
      aria-label={beschriftung(label, offen)}
      aria-expanded={gedrueckt}
      aria-controls={controls}
      onClick={onClick}
    >
      <StiftIcon />
      <Marke offen={offen} />
    </button>
  );
}
