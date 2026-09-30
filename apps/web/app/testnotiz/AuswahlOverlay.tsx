"use client";

import { type RefObject, useState } from "react";
import type { Rechteck } from "@/lib/testnotiz/format";
import { zielElement } from "./element";
import styles from "./testnotiz.module.css";

type Punkt = { x: number; y: number };

/**
 * Vollflaechig: ein Rechteck ziehen oder ein Element anklicken.
 *
 * Fuer das Element muss die Oberflaeche zweimal hinsehen: sie faengt den
 * Klick selbst (sonst traefe er die Seite und loeste dort etwas aus), holt
 * sich aber mit `elementsFromPoint` den Stapel darunter und nimmt das
 * oberste Element, das nicht zum Modul gehoert.
 */
export function AuswahlOverlay({
  art,
  wurzel,
  beiRechteck,
  beiElement,
  beiAbbruch,
}: {
  art: "rechteck" | "element";
  wurzel: RefObject<HTMLDivElement | null>;
  beiRechteck: (rahmen: Rechteck) => void;
  beiElement: (element: Element | null) => void;
  beiAbbruch: () => void;
}) {
  const [start, setStart] = useState<Punkt | null>(null);
  const [ende, setEnde] = useState<Punkt | null>(null);
  const [getroffen, setGetroffen] = useState<Element | null>(null);

  const gezogen = start && ende ? rechteckAus(start, ende) : null;
  const umriss = getroffen?.getBoundingClientRect() ?? null;

  function darunter(ereignis: { clientX: number; clientY: number }): Element | null {
    const stapel = document.elementsFromPoint(ereignis.clientX, ereignis.clientY);
    const treffer = stapel.find((knoten) => !wurzel.current?.contains(knoten));
    return treffer ? zielElement(treffer) : null;
  }

  return (
    <div
      className={styles.auswahl}
      onPointerDown={(ereignis) => {
        if (art !== "rechteck") return;
        ereignis.currentTarget.setPointerCapture(ereignis.pointerId);
        const punkt = { x: ereignis.clientX, y: ereignis.clientY };
        setStart(punkt);
        setEnde(punkt);
      }}
      onPointerMove={(ereignis) => {
        if (art === "element") {
          setGetroffen(darunter(ereignis));
          return;
        }
        if (start) setEnde({ x: ereignis.clientX, y: ereignis.clientY });
      }}
      onPointerUp={(ereignis) => {
        if (art === "element") {
          beiElement(darunter(ereignis));
          return;
        }
        const anfang = start;
        setStart(null);
        setEnde(null);
        if (!anfang) return;
        const rahmen = rechteckAus(anfang, { x: ereignis.clientX, y: ereignis.clientY });
        // Ein Klick ohne Zug bricht ab, statt einen Ein-Pixel-Ausschnitt zu sichern.
        if (rahmen.width < 8 || rahmen.height < 8) beiAbbruch();
        else beiRechteck(rahmen);
      }}
    >
      {gezogen ? (
        <div className={styles.rahmen} style={alsStil(gezogen)} />
      ) : art === "element" && umriss ? (
        <>
          <div className={styles.dunkel} />
          <div
            className={styles.elementRahmen}
            style={alsStil({ x: umriss.x, y: umriss.y, width: umriss.width, height: umriss.height })}
          />
        </>
      ) : (
        <div className={styles.dunkel} />
      )}

      <div className={styles.hinweis}>
        {art === "rechteck" ? "Rechteck ziehen" : "Element anklicken"}
      </div>

      <button type="button" className={styles.abbrechen} onClick={beiAbbruch} aria-label="Abbrechen">
        ✕
      </button>
    </div>
  );
}

export function rechteckAus(a: Punkt, b: Punkt): Rechteck {
  return {
    x: Math.min(a.x, b.x),
    y: Math.min(a.y, b.y),
    width: Math.abs(b.x - a.x),
    height: Math.abs(b.y - a.y),
  };
}

function alsStil(rahmen: Rechteck) {
  return {
    left: `${rahmen.x}px`,
    top: `${rahmen.y}px`,
    width: `${rahmen.width}px`,
    height: `${rahmen.height}px`,
  };
}
