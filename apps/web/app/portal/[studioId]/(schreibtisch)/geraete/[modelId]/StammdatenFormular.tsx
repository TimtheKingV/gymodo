"use client";

import type { CatalogType } from "@fitretro/domain";
import { MAX_PHOTO_BYTES } from "@fitretro/domain/media";
import { AktionsFormular, Feld } from "../../../../Form";
import { FotoFeld } from "../../../../bausteine/FotoFeld";
import { GymtavoTypFeld } from "../../../../bausteine/GymtavoTypFeld";
import { ModellBelastungRad, type ModellBelastungStart } from "../../../../bausteine/ModellBelastungRad";
import type { ActionResult } from "../../../../actions";
import styles from "../../../../portal.module.css";

/**
 * Kategorie, Belastung, Rastung und Nebenbelastung kommen aus
 * ModellBelastungRad, gleicher Stil wie beim Anlegen und bei den
 * Einstellungen. Eigene Datei, weil das Rad Client-Interaktion braucht --
 * die Seite selbst laedt den Katalog und bleibt Server-Component.
 *
 * Die Bestandswerte gehen als `start` ins Rad -- eine krumme Bestandszahl
 * faellt dabei auf die naechstliegende Zeile, nicht still auf die erste
 * (naechsterIndex() in EinstellungRad.tsx).
 */
export function StammdatenFormular({
  action,
  modell,
  fotoUrl,
  typen,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  modell: {
    name: string;
    manufacturer: string | null;
    catalogModelId: string | null;
  } & ModellBelastungStart;
  fotoUrl: string | undefined;
  /** Leer im Gymtavo-Studio: ein Typ wird keinem Typ zugeordnet. */
  typen: Pick<CatalogType, "id" | "name" | "manufacturer">[];
}) {
  return (
    <AktionsFormular
      action={action}
      submitLabel="Änderungen speichern"
      erfolgText="Gespeichert ✓"
      nurBeiAenderung
    >
      <div className={styles.grid}>
        <Feld name="name" label="Name" required defaultValue={modell.name} />
        <Feld
          name="manufacturer"
          label="Hersteller"
          defaultValue={modell.manufacturer ?? ""}
        />
      </div>
      <GymtavoTypFeld typen={typen} start={modell.catalogModelId} />
      <ModellBelastungRad start={modell} />
      <FotoFeld
        name="photo"
        ariaLabel="Bilddatei"
        alt={`Foto von ${modell.name}`}
        vorhandeneUrl={fotoUrl}
        hinweis={
          <>
            JPEG oder PNG, höchstens {MAX_PHOTO_BYTES / 1024 / 1024} MiB. Ein iPhone wandelt
            HEIC beim Hochladen selbst um. Leer lassen, um das Foto unverändert zu lassen.
          </>
        }
      />
    </AktionsFormular>
  );
}
