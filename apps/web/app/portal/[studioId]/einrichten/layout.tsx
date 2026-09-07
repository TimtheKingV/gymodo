import Link from "next/link";
import { ladeKatalog } from "../catalog";
import { UploadsMarke, UploadsProvider } from "./Uploads";
import styles from "./halle.module.css";

/**
 * Der Gang durch die Halle hat keine Rail: er laeuft auf 390 px, einhaendig,
 * neben einem Geraet. Hier steht nur der Weg zurueck an den Schreibtisch.
 *
 * Die frühere Fassung dieses Kommentars sagte, die Chipnavigation der
 * Artboards "kommt mit Phase 5". Sie ist gekommen -- aber fuer den
 * SCHREIBTISCH: portal.module.css legt unter @media (max-width: 900px) die
 * Rail flach und macht aus ihren Gruppen eine seitlich scrollende Reihe.
 * Die Halle liegt ausserhalb dieser Schale und hat sie deshalb nicht.
 *
 * Ob sie sie bekommen soll, ist offen und steht als Befund 45 in
 * docs/superpowers/specs/2026-09-03-portal-frontend-design.md. Kurz: zwoelf
 * Artboards zeichnen sie, aber der Gang ist einhaendig und hat mit der
 * Schrittleiste bereits eine Navigation. Zwei uebereinander auf 390 px sind
 * schlechter als eine.
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
    <UploadsProvider studioId={studioId}>
      <div className={styles.seite}>
        <header className={styles.kopf}>
          <span className={styles.studio}>{katalog.studioName}</span>
          <span style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <UploadsMarke studioId={studioId} />
            <Link href={`/portal/${studioId}`} className={styles.zurueck}>
              Schreibtisch
            </Link>
          </span>
        </header>
        <main className={styles.inhalt}>{children}</main>
      </div>
    </UploadsProvider>
  );
}
