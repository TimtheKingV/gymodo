"use client";

import { useState } from "react";
import type { Art } from "@/lib/testnotiz/format";
import styles from "./testnotiz.module.css";

const TITEL: Record<Art, string> = {
  crop: "Ausschnitt",
  element: "Element",
  note: "Notiz",
};

export function NotizBlatt({
  art,
  vorschau,
  elementzeile,
  seite,
  beiSichern,
  beiVerwerfen,
}: {
  art: Art;
  vorschau: string | null;
  elementzeile: string | null;
  seite: string;
  beiSichern: (notiz: string | null) => void;
  beiVerwerfen: () => void;
}) {
  const [text, setText] = useState("");

  function sichern() {
    const notiz = text.trim();
    beiSichern(notiz.length > 0 ? notiz : null);
  }

  return (
    <div className={styles.blatt} role="dialog" aria-label={TITEL[art]}>
      <div className={styles.blattTitel}>{TITEL[art]}</div>

      {vorschau ? <img className={styles.vorschau} src={vorschau} alt="Ausschnitt" /> : null}
      {art === "element" ? (
        <div className={styles.leise}>{elementzeile ?? "Kein Element unter dem Zeiger"}</div>
      ) : null}
      <div className={styles.leise}>{seite}</div>

      <textarea
        className={styles.feld}
        placeholder="Was stimmt hier nicht?"
        value={text}
        autoFocus
        onChange={(ereignis) => setText(ereignis.target.value)}
        onKeyDown={(ereignis) => {
          if (ereignis.key === "Enter" && (ereignis.metaKey || ereignis.ctrlKey)) {
            ereignis.preventDefault();
            sichern();
          }
        }}
      />

      <div className={styles.knoepfe}>
        <button type="button" className={styles.haupt} onClick={sichern}>
          Sichern
        </button>
        <button type="button" className={styles.zweit} onClick={beiVerwerfen}>
          Verwerfen
        </button>
      </div>
    </div>
  );
}
