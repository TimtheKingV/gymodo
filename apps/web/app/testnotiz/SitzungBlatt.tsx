"use client";

import { useState } from "react";
import styles from "./testnotiz.module.css";

/**
 * Was die App mit AirDrop loest, loest das Portal mit der Zwischenablage:
 * der Ordner liegt ohnehin schon im Arbeitsverzeichnis, es fehlt nur der
 * Satz, mit dem Claude Code ihn abarbeitet.
 */
export function SitzungBlatt({
  anzahl,
  ordner,
  beiNeueSitzung,
  beiFreigabeBeenden,
  beiFertig,
}: {
  anzahl: number;
  ordner: string | null;
  beiNeueSitzung: () => void;
  beiFreigabeBeenden: () => void;
  beiFertig: () => void;
}) {
  const [kopiert, setKopiert] = useState(false);
  const auftrag = ordner ? `Lies ${ordner}/sitzung.md und arbeite die Einträge ab.` : null;

  return (
    <div className={styles.blatt} role="dialog" aria-label="Sitzung">
      <div className={styles.blattTitel}>Sitzung</div>

      <div>
        {anzahl === 0
          ? "Noch kein Eintrag in dieser Sitzung."
          : anzahl === 1
            ? "1 Eintrag in dieser Sitzung."
            : `${anzahl} Einträge in dieser Sitzung.`}
      </div>

      {auftrag ? (
        <>
          <div className={styles.auftrag}>{auftrag}</div>
          <button
            type="button"
            className={styles.haupt}
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(auftrag);
                setKopiert(true);
              } catch {
                setKopiert(false);
              }
            }}
          >
            {kopiert ? "Auftrag kopiert" : "Auftrag kopieren"}
          </button>
        </>
      ) : null}

      <button type="button" className={styles.zweit} onClick={beiNeueSitzung}>
        Neue Sitzung beginnen
      </button>
      <button type="button" className={styles.zweit} onClick={beiFreigabeBeenden}>
        Bildschirmfreigabe beenden
      </button>
      <button type="button" className={styles.zweit} onClick={beiFertig}>
        Fertig
      </button>
    </div>
  );
}
