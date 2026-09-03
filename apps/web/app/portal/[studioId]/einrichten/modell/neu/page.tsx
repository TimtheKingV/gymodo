import Link from "next/link";
import { Schrittleiste } from "../../Schrittleiste";
import { ModellNeuFormular } from "./ModellNeuFormular";
import styles from "../../halle.module.css";

export default async function ModellNeuPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;

  return (
    <>
      <Schrittleiste nummer={1} titel="Modell" />
      <div>
        <Link
          href={`/portal/${studioId}/einrichten/modell`}
          className={styles.zurueck}
        >
          ← Modell wählen
        </Link>
        <h1 className={styles.titel}>Neues Modell</h1>
      </div>

      <ModellNeuFormular studioId={studioId} />

      <p className={styles.notiz}>
        Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand
        vor dem falschen Gerät merkt, dass er falsch steht. Beschreibungen
        trägst du am Schreibtisch nach, die Einstellparameter kommen im
        nächsten Schritt.
      </p>
    </>
  );
}
