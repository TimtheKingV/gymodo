"use client";

import { useState, useTransition } from "react";
import { tagBinden } from "../../../actions";
import { Auswahl } from "../../../bausteine/Auswahl";
import styles from "../../../portal.module.css";

/**
 * Der Sucher ohne Kamera. Tags kommen als Lieferung und sind vor dem Scan
 * nicht benennbar -- ein Dropdown haette nichts zu listen, weil eine
 * Haldenzeile per RLS unsichtbar ist. Bis der Sucher steht, ist dies der Weg;
 * danach bleibt es der Rueckfallweg fuer eine verweigerte Kamerafreigabe.
 */
export function TagBinden({
  studioId,
  pfad,
  geraete,
}: {
  studioId: string;
  pfad: string;
  geraete: Array<{ id: string; label: string; modell: string }>;
}) {
  const [token, setToken] = useState("");
  const [machineId, setMachineId] = useState("");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  if (geraete.length === 0) {
    return (
      <span className={styles.hint}>
        Kein Gerät in Betrieb, an das ein Tag gehören könnte.
      </span>
    );
  }

  return (
    <div className={styles.field}>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <label className={styles.label} htmlFor="tag-token">
        Token vom Tag
      </label>
      <input
        id="tag-token"
        className={styles.input}
        value={token}
        placeholder="22 Zeichen"
        onChange={(ereignis) => setToken(ereignis.target.value)}
      />
      <Auswahl
        value={machineId}
        onChange={setMachineId}
        ariaLabel="Gerät auswählen"
        platzhalter="Gerät wählen …"
        optionen={geraete.map((geraet) => ({
          wert: geraet.id,
          anzeige: `${geraet.label} — ${geraet.modell}`,
        }))}
      />
      <button
        type="button"
        className={styles.secondary}
        disabled={laeuft || token.trim() === "" || machineId === ""}
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await tagBinden(studioId, pfad, token, machineId);
            if (antwort.ok) setToken("");
            else setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "Wird verbunden …" : "Verbinden"}
      </button>
    </div>
  );
}
