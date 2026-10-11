import { ladeTypen } from "../../../catalog";
import { Schrittleiste } from "../../../../bausteine/Schrittleiste";
import { Seite } from "../../../../bausteine/Seite";
import { typVorlagen } from "../../../../bausteine/typVorlage";
import { ModellNeuFormular } from "./ModellNeuFormular";
import styles from "../../halle.module.css";

export default async function ModellNeuPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const typen = await ladeTypen();

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
        <ModellNeuFormular studioId={studioId} typen={typVorlagen(typen)} />

        <p className={styles.notiz}>
          Ein Foto hilft, das Gerät in der Halle wiederzufinden. Ohne eigenes
          Foto zeigt das Gerät die Zeichnung seines Gymtavo-Typs, wenn es eine
          gibt. Beschreibungen trägst du am Schreibtisch nach, die
          Einstellungen kommen im nächsten Schritt.
        </p>
      </Seite>
    </>
  );
}
