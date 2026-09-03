"use client";

import { useActionState, useId, useState } from "react";
import { useRouter } from "next/navigation";
import { geraetAnlegen } from "../../../actions";
import styles from "../../../halle.module.css";

/**
 * Nummer und Standort -- beides steht nur am Geraet. Die Nummer ist ein
 * Vorschlag: klebt am Geraet schon eine andere, gilt die (Spec 7).
 */
export function GeraetFormular({
  studioId,
  modelId,
  vorschlag,
  standorte,
}: {
  studioId: string;
  modelId: string;
  vorschlag: string;
  standorte: string[];
}) {
  const router = useRouter();
  const [ort, setOrt] = useState("");
  const nummerId = useId();
  const ortId = useId();

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await geraetAnlegen(studioId, modelId, null, formData);
      if (antwort.ok) {
        router.push(
          `/portal/${studioId}/einrichten/geraet/${antwort.machineId}/tag`,
        );
      }
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} style={{ display: "grid", gap: 16 }}>
      <div className={styles.feld}>
        <label className={styles.label} htmlFor={nummerId}>
          Nummer
        </label>
        <input
          id={nummerId}
          name="label"
          required
          defaultValue={vorschlag}
          className={styles.eingabe}
        />
        <span className={styles.notiz}>
          Vorgeschlagen ist die nächste nach der höchsten. Sie steht am Gerät
          und in der App des Mitglieds — nimm die, die schon draufsteht.
        </span>
      </div>

      <div className={styles.feld}>
        <label className={styles.label} htmlFor={ortId}>
          Standort
        </label>
        <input
          id={ortId}
          name="locationNote"
          value={ort}
          placeholder="Rückwand rechts"
          className={styles.eingabe}
          onChange={(ereignis) => setOrt(ereignis.target.value)}
        />
        {standorte.length > 0 ? (
          <div className={styles.chips}>
            {standorte.map((vorhanden) => (
              <button
                key={vorhanden}
                type="button"
                className={vorhanden === ort ? styles.chipAktiv : styles.chip}
                onClick={() => setOrt(vorhanden)}
              >
                {vorhanden}
              </button>
            ))}
          </div>
        ) : null}
      </div>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.haupt} disabled={laeuft}>
        {laeuft ? "Wird angelegt …" : "Weiter zum Tag"}
      </button>
    </form>
  );
}
