"use client";

import { useState, useTransition } from "react";
import { tagZuweisen } from "../../actions";
import styles from "../../portal.module.css";

/**
 * Einen vorraetigen Tag einem Geraet zuweisen. Erst damit wird er aktiv --
 * der Check-Constraint aus 0008 laesst 'active' ohne Geraet gar nicht zu.
 */
export function TagZuweisen({
  studioId,
  pfad,
  tagId,
  geraete,
}: {
  studioId: string;
  pfad: string;
  tagId: string;
  geraete: Array<{ id: string; label: string; modell: string }>;
}) {
  const [machineId, setMachineId] = useState("");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  if (geraete.length === 0) {
    return (
      <span className={styles.hint}>
        Kein Gerät in Betrieb, dem er zugewiesen werden könnte.
      </span>
    );
  }

  return (
    <span className={styles.rowActions}>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <select
        id={`ziel-${tagId}`}
        className={styles.select}
        value={machineId}
        aria-label="Gerät auswählen"
        onChange={(ereignis) => setMachineId(ereignis.target.value)}
      >
        <option value="">Gerät wählen …</option>
        {geraete.map((geraet) => (
          <option key={geraet.id} value={geraet.id}>
            {geraet.label} — {geraet.modell}
          </option>
        ))}
      </select>
      <button
        type="button"
        className={styles.secondary}
        disabled={laeuft || machineId === ""}
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await tagZuweisen(studioId, pfad, tagId, machineId);
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "Wird zugewiesen …" : "Zuweisen"}
      </button>
    </span>
  );
}
