import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../../../bausteine/Schrittleiste";
import { Seite } from "../../../../../bausteine/Seite";
import { TagSchritt } from "./TagSchritt";

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
      <Seite
        titel="Tag ankleben"
        vorspann={`${treffer.geraet.label} · ${treffer.modell.name}${
          treffer.geraet.locationNote ? ` · ${treffer.geraet.locationNote}` : ""
        }`}
      >
        <TagSchritt
          studioId={studioId}
          machineId={machineId}
          geraetLabel={treffer.geraet.label}
          geraetHatTag={treffer.geraet.activeTagCount > 0}
        />
      </Seite>
    </>
  );
}
