import Link from "next/link";
import { GymtavoWordmark } from "../branding/GymtavoWordmark";
import styles from "./Kopf.module.css";

/**
 * Sticky Glas-Pille (Spec 7.2). Etappe 1 ohne Menue: "Fuer Studios" hat bis
 * Etappe 2 kein Ziel, und ein Menue fuer einen einzigen Eintrag waere
 * Mechanik ohne Inhalt. "App laden" steht hier nicht -- als zweite
 * Akzentflaeche neben dem Hero-Knopf verletzte es Spec 4.2.
 */
export function Kopf() {
  return (
    <header className={styles.kopf}>
      <GymtavoWordmark />
      <Link href="/login" className={styles.anmelden}>
        Anmelden
      </Link>
    </header>
  );
}
