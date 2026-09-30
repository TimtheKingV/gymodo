"use client";

import { useEffect, useState } from "react";
import type { Art } from "@/lib/testnotiz/format";
import { DateiKnopf } from "../portal/bausteine/DateiKnopf";
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
  anhaengenMoeglich,
  beiSichern,
  beiVerwerfen,
}: {
  art: Art;
  /** Vorschau des Ausschnitts aus der Freigabe, falls es einen gibt. */
  vorschau: string | null;
  elementzeile: string | null;
  seite: string;
  /** Am Handy: hier haengt der Tester seinen eigenen Screenshot an. */
  anhaengenMoeglich: boolean;
  beiSichern: (notiz: string | null, bild: File | null) => void;
  beiVerwerfen: () => void;
}) {
  const [text, setText] = useState("");
  const [bild, setBild] = useState<File | null>(null);
  const [bildUrl, setBildUrl] = useState<string | null>(null);

  // Dasselbe Muster wie FotoFeld und VideoUpload im Portal: die Objekt-URL
  // gehoert dieser Ansicht und wird mit ihr wieder freigegeben.
  useEffect(() => {
    if (!bild) {
      setBildUrl(null);
      return;
    }
    const url = URL.createObjectURL(bild);
    setBildUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [bild]);

  function sichern() {
    const notiz = text.trim();
    beiSichern(notiz.length > 0 ? notiz : null, bild);
  }

  return (
    <div className={styles.blatt} role="dialog" aria-label={TITEL[art]}>
      <div className={styles.blattTitel}>{TITEL[art]}</div>

      {bildUrl ? (
        <img className={styles.vorschau} src={bildUrl} alt="Angehängtes Bild" />
      ) : vorschau ? (
        <img className={styles.vorschau} src={vorschau} alt="Ausschnitt" />
      ) : null}

      {anhaengenMoeglich ? (
        <DateiKnopf
          label={bild ? "Bild ersetzen" : "Bild anhängen"}
          ariaLabel="Screenshot anhängen"
          accept="image/*"
          onDatei={setBild}
        />
      ) : null}

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
