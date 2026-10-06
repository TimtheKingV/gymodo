import Link from "next/link";
import styles from "./Fuss.module.css";

/**
 * Produktgrenze in text-muted (Designsystem 2 und 10, Befund 19) und die
 * Wege fuer Trainer, die frueher die Hauptaktion waren. Die Linknamen
 * unterscheiden sich vom "Anmelden" im Kopf, damit jeder Weg eindeutig
 * benannt ist.
 */
export function Fuss({ id, produktgrenze }: { id: string; produktgrenze: string }) {
  return (
    <footer id={id} className={styles.fuss}>
      <p className={styles.grenze}>{produktgrenze}</p>
      <nav aria-label="Für Trainer und Studios" className={styles.wege}>
        <span>Für Trainer und Studios:</span>
        <Link href="/login">Trainer-Anmeldung</Link>
        <Link href="/registrieren">Konto anlegen</Link>
      </nav>
    </footer>
  );
}
