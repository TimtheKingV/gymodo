import { Schrittleiste } from "../../../../bausteine/Schrittleiste";
import { Seite } from "../../../../bausteine/Seite";
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
      <Seite
        titel="Neues Modell"
        rueckweg={{
          href: `/portal/${studioId}/einrichten/modell`,
          label: "Modell wählen",
        }}
      >
        <ModellNeuFormular studioId={studioId} />

        <p className={styles.notiz}>
          Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum
          jemand vor dem falschen Gerät merkt, dass er falsch steht.
          Beschreibungen trägst du am Schreibtisch nach, die Einstellungen
          kommen im nächsten Schritt.
        </p>
      </Seite>
    </>
  );
}
