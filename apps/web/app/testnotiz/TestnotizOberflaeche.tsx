"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Art, Ausschnittsrahmen, ElementAngabe, Rechteck } from "@/lib/testnotiz/format";
import { elementZeile } from "@/lib/testnotiz/markdown";
import { zeitstempel } from "@/lib/testnotiz/zeit";
import { AuswahlOverlay } from "./AuswahlOverlay";
import { NotizBlatt } from "./NotizBlatt";
import { SitzungBlatt } from "./SitzungBlatt";
import { TestnotizKnopf } from "./TestnotizKnopf";
import { TestnotizMenue } from "./TestnotizMenue";
import {
  type Bild,
  aufnehmen,
  freigabeAktiv,
  freigabeAnfordern,
  freigabeBeenden,
  freigeben,
  ganzeSeite,
  schneiden,
} from "./bildschirmfoto";
import { elementAngabe } from "./element";
import { protokollSeit, protokollStarten } from "./protokoll";
import { eintragSichern, gemerkteSitzung, laufzeit, sitzungMerken, sitzungStand } from "./sitzung";
import styles from "./testnotiz.module.css";

type Modus = "ruhe" | "menue" | "ausschnitt" | "element" | "notiz" | "sitzung";

/**
 * Was zwischen Klick und Sichern entsteht. Das Foto entsteht beim Klick auf
 * den Knopf: danach faengt die Oberflaeche jeden Zeiger, die Seite kann sich
 * also nicht mehr aendern -- dieselbe Zusicherung wie in der App.
 */
type Entwurf = {
  zeitpunkt: Date;
  vollbild: Bild;
  art: Art;
  ausschnitt: Bild | null;
  ausschnittsrahmen: Ausschnittsrahmen | null;
  element: ElementAngabe | null;
};

/** Protokollfenster je Eintrag, wie auf iOS. */
const PROTOKOLL_SEKUNDEN = 300;

export function TestnotizOberflaeche({ angemeldet }: { angemeldet: boolean }) {
  const [an, setAn] = useState(false);
  const [modus, setModus] = useState<Modus>("ruhe");
  const [entwurf, setEntwurf] = useState<Entwurf | null>(null);
  const [anzahl, setAnzahl] = useState(0);
  const [ordner, setOrdner] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const [pfad, setPfad] = useState("");
  const wurzel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Playwright steuert denselben Dev-Server. Der Knopf laege dort ueber der
    // Seite und finge Klicks, die einem Test gehoeren.
    if (navigator.webdriver) return;
    setAn(true);
    protokollStarten();

    const gemerkt = gemerkteSitzung();
    if (!gemerkt) return;
    let abgemeldet = false;
    void sitzungStand(gemerkt).then((stand) => {
      if (abgemeldet) return;
      if (stand) {
        setAnzahl(stand.anzahl);
        setOrdner(stand.ordner);
      } else {
        sitzungMerken(null);
      }
    });
    return () => {
      abgemeldet = true;
    };
  }, []);

  const verwerfen = useCallback(() => {
    setEntwurf((vorher) => {
      freigeben(vorher?.vollbild, vorher?.ausschnitt);
      return null;
    });
    setModus("ruhe");
  }, []);

  useEffect(() => {
    if (modus === "ruhe") return;

    const beiTaste = (ereignis: KeyboardEvent) => {
      if (ereignis.key === "Escape") verwerfen();
    };
    // Solange die Oberflaeche faengt, soll die Seite darunter auch nicht
    // scrollen -- das Foto ist schon gemacht.
    const halten = (ereignis: Event) => ereignis.preventDefault();

    window.addEventListener("keydown", beiTaste);
    const knoten = wurzel.current;
    knoten?.addEventListener("wheel", halten, { passive: false });
    knoten?.addEventListener("touchmove", halten, { passive: false });
    return () => {
      window.removeEventListener("keydown", beiTaste);
      knoten?.removeEventListener("wheel", halten);
      knoten?.removeEventListener("touchmove", halten);
    };
  }, [modus, verwerfen]);

  async function knopfGeklickt() {
    setPfad(window.location.pathname);
    setModus("menue");
    setLaeuft(true);
    try {
      // Bis hierher darf nichts warten: `getDisplayMedia` verlangt beim
      // ersten Mal die Geste, die diesen Klick ausgeloest hat.
      if (!freigabeAktiv()) await freigabeAnfordern();
      const vollbild = await aufnehmen(wurzel.current);
      setEntwurf({
        zeitpunkt: new Date(),
        vollbild,
        art: "note",
        ausschnitt: null,
        ausschnittsrahmen: null,
        element: null,
      });
      setFehler(null);
    } catch (grund) {
      setFehler(`Kein Bild: ${meldung(grund)}`);
    } finally {
      setLaeuft(false);
    }
  }

  async function ausschnittGewaehlt(rahmen: Rechteck) {
    if (!entwurf) return verwerfen();
    const geschnitten = await schneiden(entwurf.vollbild, rahmen);
    if (!geschnitten) return verwerfen();
    setEntwurf({
      ...entwurf,
      art: "crop",
      ausschnitt: geschnitten.bild,
      ausschnittsrahmen: geschnitten.rahmen,
    });
    setModus("notiz");
  }

  function elementGewaehlt(element: Element | null) {
    if (!entwurf) return verwerfen();
    setEntwurf({ ...entwurf, art: "element", element: element ? elementAngabe(element) : null });
    setModus("notiz");
  }

  /**
   * Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll nicht
   * auf PNG-Kodierung und Dateisystem warten.
   */
  async function sichern(notiz: string | null) {
    const aktuell = entwurf;
    setEntwurf(null);
    setModus("ruhe");
    if (!aktuell) return;

    try {
      const stand = await eintragSichern(
        {
          id: crypto.randomUUID().toUpperCase(),
          createdAt: zeitstempel(aktuell.zeitpunkt),
          kind: aktuell.art,
          cropRect: aktuell.ausschnittsrahmen,
          element: aktuell.element,
          note: notiz,
          runtime: laufzeit(angemeldet),
          log: protokollSeit(PROTOKOLL_SEKUNDEN, aktuell.zeitpunkt),
        },
        aktuell.vollbild,
        aktuell.ausschnitt,
        {},
      );
      setAnzahl(stand.anzahl);
      setOrdner(stand.ordner);
      // Erst ein gelungener Eintrag loescht die alte Meldung -- sonst naehme
      // der naechste Klick sie weg, bevor das Menue sie zeigt.
      setFehler(null);
    } catch (grund) {
      setFehler(`Nicht gesichert: ${meldung(grund)}`);
    } finally {
      freigeben(aktuell.vollbild, aktuell.ausschnitt);
    }
  }

  if (!an) return null;

  return (
    <div
      ref={wurzel}
      className={modus === "ruhe" ? styles.wurzel : `${styles.wurzel} ${styles.fangend}`}
    >
      {modus === "ruhe" ? <TestnotizKnopf anzahl={anzahl} beiKlick={knopfGeklickt} /> : null}

      {modus === "menue" ? (
        <TestnotizMenue
          titel={pfad || "Testnotiz"}
          anzahl={anzahl}
          fehler={fehler}
          bereit={entwurf !== null}
          laeuft={laeuft}
          beiAusschnitt={() => setModus("ausschnitt")}
          beiSeite={() => void ausschnittGewaehlt(ganzeSeite())}
          beiElement={() => setModus("element")}
          beiNotiz={() => setModus("notiz")}
          beiSitzung={() => setModus("sitzung")}
          beiFreigabe={() => void knopfGeklickt()}
          beiSchliessen={verwerfen}
        />
      ) : null}

      {modus === "ausschnitt" || modus === "element" ? (
        <AuswahlOverlay
          art={modus === "ausschnitt" ? "rechteck" : "element"}
          wurzel={wurzel}
          beiRechteck={(rahmen) => void ausschnittGewaehlt(rahmen)}
          beiElement={elementGewaehlt}
          beiAbbruch={verwerfen}
        />
      ) : null}

      {modus === "notiz" && entwurf ? (
        <NotizBlatt
          art={entwurf.art}
          vorschau={entwurf.ausschnitt?.url ?? null}
          elementzeile={entwurf.element ? elementZeile(entwurf.element) : null}
          seite={pfad}
          beiSichern={(notiz) => void sichern(notiz)}
          beiVerwerfen={verwerfen}
        />
      ) : null}

      {modus === "sitzung" ? (
        <>
          <div className={styles.schleier} onClick={verwerfen} />
          <SitzungBlatt
            anzahl={anzahl}
            ordner={ordner}
            beiNeueSitzung={() => {
              sitzungMerken(null);
              setAnzahl(0);
              setOrdner(null);
            }}
            beiFreigabeBeenden={() => {
              freigabeBeenden();
              verwerfen();
            }}
            beiFertig={verwerfen}
          />
        </>
      ) : null}
    </div>
  );
}

function meldung(grund: unknown): string {
  if (grund instanceof DOMException && grund.name === "NotAllowedError") {
    return "Freigabe abgelehnt.";
  }
  return grund instanceof Error ? grund.message : String(grund);
}
