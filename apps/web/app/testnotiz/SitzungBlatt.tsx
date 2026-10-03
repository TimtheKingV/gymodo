"use client";

import { useState } from "react";
import styles from "./testnotiz.module.css";

/**
 * Das Ende einer Sitzung: eine Zip, die entpackt genau den Ordner ergibt,
 * den Claude Code liest. Am Handy geht sie ins Share-Sheet (AirDrop, Mail,
 * WhatsApp), am Rechner in den Download-Ordner.
 */
export function SitzungBlatt({
  anzahl,
  ordner,
  bytes,
  beiTeilen,
  beiNeueSitzung,
  beiFreigabeBeenden,
  beiFertig,
  freigabeAktiv,
}: {
  anzahl: number;
  ordner: string | null;
  bytes: number;
  beiTeilen: () => Promise<string | null>;
  beiNeueSitzung: () => void;
  beiFreigabeBeenden: () => void;
  beiFertig: () => void;
  freigabeAktiv: boolean;
}) {
  const [stand, setStand] = useState<"ruhe" | "laeuft" | "fertig">("ruhe");
  const [fehler, setFehler] = useState<string | null>(null);
  const auftrag = ordner ? `Lies apps/web/testnotizen/${ordner}/sitzung.md und arbeite die Einträge ab.` : null;

  async function teilen() {
    setStand("laeuft");
    setFehler(await beiTeilen());
    setStand("fertig");
  }

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

      {/* Ab etwa fuenfzig Megabyte wird der Speicher am Handy eng -- lieber
          jetzt teilen und neu anfangen als beim naechsten Eintrag scheitern. */}
      {bytes > 50_000_000 ? (
        <div className={styles.fehler}>
          {Math.round(bytes / 1_000_000)} MB Bilder — teile die Sitzung und fang eine neue an.
        </div>
      ) : null}

      {fehler ? <div className={styles.fehler}>{fehler}</div> : null}

      {anzahl > 0 ? (
        <>
          <button
            type="button"
            className={styles.haupt}
            disabled={stand === "laeuft"}
            onClick={() => void teilen()}
          >
            {stand === "laeuft" ? "Zip wird gepackt …" : "Sitzung teilen"}
          </button>
          <div className={styles.leise}>
            Die Zip nach <code>apps/web/testnotizen/</code> entpacken, dann in Claude Code:
          </div>
          {auftrag ? <div className={styles.auftrag}>{auftrag}</div> : null}
        </>
      ) : null}

      <button type="button" className={styles.zweit} onClick={beiNeueSitzung}>
        Neue Sitzung beginnen
      </button>
      {freigabeAktiv ? (
        <button type="button" className={styles.zweit} onClick={beiFreigabeBeenden}>
          Bildschirmfreigabe beenden
        </button>
      ) : null}
      <button type="button" className={styles.zweit} onClick={beiFertig}>
        Fertig
      </button>
    </div>
  );
}
