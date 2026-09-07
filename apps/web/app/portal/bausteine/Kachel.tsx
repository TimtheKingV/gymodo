import styles from "./bausteine.module.css";

/**
 * Eine Kennzahl des Ueberblicks: Zahl gross, Beschriftung darunter.
 *
 * Bewusst ohne Balken und ohne Ziel (portal.module.css .kacheln) -- der
 * Ueberblick sagt, OB das Studio benutzt wird, nicht wie weit es von
 * irgendwas entfernt ist.
 */
export function Kachel({
  zahl,
  label,
}: {
  zahl: React.ReactNode;
  label: string;
}) {
  return (
    <div className={styles.kachel}>
      <div className={styles.kachelZahl}>{zahl}</div>
      <div className={styles.kachelLabel}>{label}</div>
    </div>
  );
}

/**
 * Der Umschlag: das Grid um beliebig viele `Kachel`n.
 */
export function Kacheln({ children }: { children: React.ReactNode }) {
  return <div className={styles.kacheln}>{children}</div>;
}
