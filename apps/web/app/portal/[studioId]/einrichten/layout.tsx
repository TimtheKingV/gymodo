import Link from "next/link";
import { ladeKatalog } from "../catalog";
import styles from "./halle.module.css";

/**
 * Der Gang durch die Halle hat keine Rail: er laeuft auf 390 px, einhaendig,
 * neben einem Geraet. Die Chipnavigation der Artboards gehoert zur
 * Telefonfassung des ganzen Portals und kommt mit Phase 5 -- hier steht nur
 * der Weg zurueck an den Schreibtisch.
 */
export default async function HalleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);

  return (
    <div className={styles.seite}>
      <header className={styles.kopf}>
        <span className={styles.studio}>{katalog.studioName}</span>
        <Link href={`/portal/${studioId}`} className={styles.zurueck}>
          Schreibtisch
        </Link>
      </header>
      <main className={styles.inhalt}>{children}</main>
    </div>
  );
}
