"use client";

import { useState, useTransition } from "react";
import { Auswahl } from "../../../../../bausteine/Auswahl";
import type { ActionResult } from "../../../../../actions";
import styles from "../../../../../portal.module.css";

/** Suche ueber alle Gymtavo-Uebungen, die am Modell noch nicht stehen. */
export function GymtavoAnhaengen({
  angebot,
  anhaengen,
}: {
  angebot: { exerciseId: string; name: string; typName: string }[];
  anhaengen: (exerciseId: string) => Promise<ActionResult>;
}) {
  const [wahl, setWahl] = useState("");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  if (angebot.length === 0) {
    return <p className={styles.hint}>Alle Gymtavo-Übungen stehen schon an diesem Modell.</p>;
  }

  return (
    <div style={{ display: "grid", gap: 12 }}>
      <Auswahl
        value={wahl}
        onChange={setWahl}
        optionen={angebot.map((u) => ({ wert: u.exerciseId, anzeige: `${u.name} · ${u.typName}` }))}
        platzhalter="Übung wählen"
        ariaLabel="Gymtavo-Übung"
        suche="Übung suchen"
      />
      {fehler ? (
        <p className={styles.error} role="alert">
          {fehler}
        </p>
      ) : null}
      <button
        type="button"
        className={styles.secondary}
        disabled={!wahl || laeuft}
        onClick={() =>
          starte(async () => {
            const antwort = await anhaengen(wahl);
            if (antwort.ok) {
              setWahl("");
              setFehler(null);
            } else {
              setFehler(antwort.error);
            }
          })
        }
      >
        {laeuft ? "Wird angehängt …" : "Anhängen"}
      </button>
    </div>
  );
}
