import Link from "next/link";
import { notFound } from "next/navigation";
import { naechsteGeraeteNummer } from "@fitretro/domain";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { GeraetFormular } from "./GeraetFormular";
import styles from "../../../halle.module.css";

export default async function GeraetPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const alleGeraete = katalog.models.flatMap((eintrag) => eintrag.machines);

  // Der Vorschlag zaehlt ueber das ganze Studio, nicht nur ueber dieses
  // Modell: die Nummer klebt am Geraet und muss in der Halle eindeutig sein.
  // Stillgelegte zaehlen mit -- ihr Aufkleber haengt weiter dort.
  const vorschlag = naechsteGeraeteNummer(
    alleGeraete.map((geraet) => geraet.label),
  );

  const standorte = [
    ...new Set(
      alleGeraete
        .map((geraet) => geraet.locationNote)
        .filter((ort): ort is string => Boolean(ort)),
    ),
  ].sort((a, b) => a.localeCompare(b, "de"));

  return (
    <>
      <Schrittleiste nummer={3} titel="Gerät" />
      <div>
        <Link
          href={`/portal/${studioId}/einrichten/modell/${modelId}/einstellungen`}
          className={styles.zurueck}
        >
          ← Einstellungen
        </Link>
        <h1 className={styles.titel}>Dieses Gerät</h1>
        <p className={styles.unterzeile}>
          {modell.name}
          {modell.manufacturer ? ` · ${modell.manufacturer}` : ""}
        </p>
      </div>

      <GeraetFormular
        studioId={studioId}
        modelId={modelId}
        vorschlag={vorschlag}
        standorte={standorte}
      />

      <p className={styles.notiz}>
        Ein Gerät verschwindet später nicht mehr. Es wird stillgelegt, einzeln,
        mit Namen — die Zuordnungshistorie bleibt.
      </p>
    </>
  );
}
