"use client";

import { useActionState, useId, useState } from "react";
import { useRouter } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain/media";
import { modellAnlegen } from "../../actions";
import styles from "../../halle.module.css";

const SCHRITTE = ["1,25", "2,5", "5"];

/**
 * Bewusst knapp: Foto, Name, Hersteller, Schrittweite, Spanne. Alles Weitere
 * bleibt Schreibtisch (Entscheidung 6).
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
  const [schritt, setSchritt] = useState("2,5");
  const fotoId = useId();

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
      <div className={styles.feld}>
        <label className={styles.label} htmlFor={fotoId}>
          Foto des Modells
        </label>
        <input
          id={fotoId}
          name="photo"
          type="file"
          accept="image/jpeg,image/png"
          capture="environment"
          className={styles.eingabe}
          onChange={(ereignis) => {
            const datei = ereignis.target.files?.[0];
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
        <span className={styles.notiz}>
          Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei
          baugleiche Kabelzüge zeigen dasselbe Bild.
        </span>
        {dateiFehler ? (
          <p className={styles.fehler} role="alert">
            {dateiFehler}
          </p>
        ) : null}
      </div>

      <Feld name="name" label="Name" required placeholder="Kabelzug" />
      <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />

      <div className={styles.feld}>
        <span className={styles.label}>Gewichtsschritt</span>
        <div className={styles.chips}>
          {SCHRITTE.map((wert) => (
            <button
              key={wert}
              type="button"
              className={wert === schritt ? styles.chipAktiv : styles.chip}
              aria-pressed={wert === schritt}
              onClick={() => setSchritt(wert)}
            >
              {wert} kg
            </button>
          ))}
        </div>
        <input type="hidden" name="weightStepKg" value={schritt} />
        <span className={styles.notiz}>
          Die Schrittweite kommt von den Platten am Gerät. Sie rastet später das
          Rad des Mitglieds — ein Wert, den das Gerät nicht kann, wird damit
          unmöglich.
        </span>
      </div>

      <div style={{ display: "flex", gap: 12 }}>
        <div style={{ flex: 1 }}>
          <Feld name="minWeightKg" label="Ab" inputMode="decimal" placeholder="5" />
        </div>
        <div style={{ flex: 1 }}>
          <Feld
            name="maxWeightKg"
            label="Bis"
            inputMode="decimal"
            placeholder="100"
          />
        </div>
      </div>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.haupt} disabled={!hatFoto || laeuft}>
        {laeuft ? "Wird angelegt …" : "Weiter zu den Einstellungen"}
      </button>
    </form>
  );
}

function Feld({
  name,
  label,
  ...rest
}: {
  name: string;
  label: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
    </div>
  );
}
