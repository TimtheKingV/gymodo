import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { TagSchritt } from "./TagSchritt";
import styles from "../../../halle.module.css";

export default async function TagPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  return (
    <>
      <Schrittleiste nummer={4} titel="Tag" />
      <div>
        <h1 className={styles.titel}>Tag ankleben</h1>
        <p className={styles.unterzeile}>
          {treffer.geraet.label} · {treffer.modell.name}
          {treffer.geraet.locationNote ? ` · ${treffer.geraet.locationNote}` : ""}
        </p>
      </div>

      <TagSchritt
        studioId={studioId}
        machineId={machineId}
        geraetLabel={treffer.geraet.label}
        geraetHatTag={treffer.geraet.activeTagCount > 0}
      />
    </>
  );
}
