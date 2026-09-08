"use client";

import { useActionState, useState } from "react";
import { useRouter } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain/media";
import { modellAnlegen } from "../../actions";
import { Feld } from "../../../../Form";
import { FotoFeld } from "../../../../bausteine/FotoFeld";
import { ModellGewichtRad } from "../../../../bausteine/ModellGewichtRad";
import styles from "../../halle.module.css";
import portalStyles from "../../../../portal.module.css";

/**
 * Bewusst knapp: Foto, Name, Hersteller, Schrittweite, Spanne. Alles Weitere
 * bleibt Schreibtisch (Entscheidung 6).
 *
 * Schrittweite/Minimum/Maximum kommen als Rad (ModellGewichtRad, gross) --
 * ersetzt die vormalige Chip-Reihe fuer die Schrittweite und die getippten
 * Ab/Bis-Felder, gleicher Stil wie bei den Einstellungen.
 *
 * Das Foto kommt ueber capture aus der Systemkamera und nicht aus einem
 * eigenen Sucher: dieselbe Bedienung, vom Betriebssystem gestellt, und
 * getUserMedia bleibt dem Tag-Sucher vorbehalten, wo es keine Alternative
 * gibt. Spec 5 nennt "Foto am Telefon" ausdruecklich vollstaendig vorhanden.
 */
export function ModellNeuFormular({ studioId }: { studioId: string }) {
  const router = useRouter();
  const [hatFoto, setHatFoto] = useState(false);
  const [dateiFehler, setDateiFehler] = useState<string | null>(null);

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await modellAnlegen(studioId, null, formData);
      if (antwort.ok) {
        router.push(
          `/portal/${studioId}/einrichten/modell/${antwort.modelId}/einstellungen`,
        );
      }
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} style={{ display: "grid", gap: 16 }}>
      <FotoFeld
        name="photo"
        gross
        ausloeserText="Foto des Modells auswählen"
        ariaLabel="Foto des Modells"
        hinweis="Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei baugleiche Kabelzüge zeigen dasselbe Bild."
        onDatei={(datei) => {
          if (!datei) {
            setHatFoto(false);
            setDateiFehler(null);
            return;
          }
          if (datei.size > MAX_PHOTO_BYTES) {
            setHatFoto(false);
            setDateiFehler(
              `Das Foto ist ${(datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_PHOTO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
            );
            return;
          }
          setDateiFehler(null);
          setHatFoto(true);
        }}
      />
      {dateiFehler ? (
        <p className={styles.fehler} role="alert">
          {dateiFehler}
        </p>
      ) : null}

      <Feld gross name="name" label="Name" required placeholder="Kabelzug" />
      <Feld
        gross
        name="manufacturer"
        label="Hersteller"
        placeholder="Technogym"
      />

      <ModellGewichtRad gross />
      <p className={styles.notiz}>
        Die Schrittweite kommt von den Platten am Gerät. Sie rastet später das
        Rad des Mitglieds — ein Wert, den das Gerät nicht kann, wird damit
        unmöglich.
      </p>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button
        type="submit"
        className={portalStyles.primaryGross}
        disabled={!hatFoto || laeuft}
      >
        {laeuft ? "Wird angelegt …" : "Weiter zu den Einstellungen"}
      </button>
    </form>
  );
}
