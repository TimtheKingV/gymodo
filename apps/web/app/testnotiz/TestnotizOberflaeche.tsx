"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type {
  Art,
  Ausschnittsrahmen,
  ElementAngabe,
  Rechteck,
  Screen,
} from "@/lib/testnotiz/format";
import { elementZeile } from "@/lib/testnotiz/markdown";
import { screenBauen } from "@/lib/testnotiz/seitendatei";
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
  freigabeMoeglich,
  freigeben,
  ganzeSeite,
  schneiden,
} from "./bildschirmfoto";
import { elementAngabe } from "./element";
import { protokollSeit, protokollStarten } from "./protokoll";
import { routenkarte } from "./routen";
import {
  type GespeicherterEintrag,
  type Sitzungsstand,
  anzahlLesen,
  eintragAnhaengen,
  eintraegeLesen,
  groesse,
  sitzungAnlegen,
  sitzungLesen,
  sitzungVerwerfen,
} from "./speicher";
import { laufzeit, sitzungAnlegenDaten } from "./sitzung";
import { sitzungBuendeln, weitergeben } from "./teilen";
import styles from "./testnotiz.module.css";

type Modus = "ruhe" | "menue" | "ausschnitt" | "element" | "notiz" | "sitzung";

/**
 * Was zwischen Klick und Sichern entsteht. Am Rechner ist das Foto beim
 * Klick auf den Knopf schon gemacht -- danach faengt die Oberflaeche jeden
 * Zeiger, die Seite kann sich also nicht mehr aendern. Am Handy gibt es
 * keine Freigabe; dort bleibt `vollbild` leer, bis der Tester im Notizblatt
 * seinen eigenen Screenshot anhaengt.
 */
type Entwurf = {
  zeitpunkt: Date;
  vollbild: Bild | null;
  art: Art;
  ausschnitt: Bild | null;
  ausschnittsrahmen: Ausschnittsrahmen | null;
  element: ElementAngabe | null;
  screen: Screen | null;
};

/** Protokollfenster je Eintrag, wie auf iOS. */
const PROTOKOLL_SEKUNDEN = 300;

export function TestnotizOberflaeche({ angemeldet }: { angemeldet: boolean }) {
  const [an, setAn] = useState(false);
  const [modus, setModus] = useState<Modus>("ruhe");
  const [entwurf, setEntwurf] = useState<Entwurf | null>(null);
  const [anzahl, setAnzahl] = useState(0);
  const [bytes, setBytes] = useState(0);
  const [ordner, setOrdner] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const [pfad, setPfad] = useState("");
  const wurzel = useRef<HTMLDivElement>(null);

  const freigabe = freigabeMoeglich();

  useEffect(() => {
    // Playwright steuert denselben Server. Der Knopf laege dort ueber der
    // Seite und finge Klicks, die einem Test gehoeren.
    if (navigator.webdriver) return;
    setAn(true);
    protokollStarten();

    let abgemeldet = false;
    void (async () => {
      try {
        const stand = await sitzungLesen();
        if (abgemeldet || !stand) return;
        setOrdner(stand.id);
        setAnzahl(await anzahlLesen());
      } catch (grund) {
        if (!abgemeldet) setFehler(`Sitzung nicht lesbar: ${meldung(grund)}`);
      }
    })();
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

  function entwurfAnlegen(vollbild: Bild | null): Entwurf {
    return {
      zeitpunkt: new Date(),
      vollbild,
      art: "note",
      ausschnitt: null,
      ausschnittsrahmen: null,
      element: null,
      screen: screenBauen(routenkarte(), {
        pfad: window.location.pathname,
        suche: window.location.search,
      }),
    };
  }

  async function knopfGeklickt() {
    setPfad(window.location.pathname);
    setModus("menue");

    if (!freigabe) {
      // Am Handy gibt es nichts aufzunehmen; der Entwurf steht sofort.
      setEntwurf(entwurfAnlegen(null));
      return;
    }

    setLaeuft(true);
    try {
      // Bis hierher darf nichts warten: `getDisplayMedia` verlangt beim
      // ersten Mal die Geste, die diesen Klick ausgeloest hat.
      if (!freigabeAktiv()) await freigabeAnfordern();
      setEntwurf(entwurfAnlegen(await aufnehmen(wurzel.current)));
      setFehler(null);
    } catch (grund) {
      setFehler(`Kein Bild: ${meldung(grund)}`);
    } finally {
      setLaeuft(false);
    }
  }

  async function ausschnittGewaehlt(rahmen: Rechteck) {
    if (!entwurf?.vollbild) return verwerfen();
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
   * auf PNG-Kodierung und Datenbank warten.
   */
  async function sichern(notiz: string | null, angehaengt: File | null) {
    const aktuell = entwurf;
    setEntwurf(null);
    setModus("ruhe");
    if (!aktuell) return;

    try {
      const stand = await sitzungSichern();
      const gespeichert: Omit<GespeicherterEintrag, "index"> = {
        entwurf: {
          id: crypto.randomUUID().toUpperCase(),
          createdAt: zeitstempel(aktuell.zeitpunkt),
          kind: aktuell.art,
          cropRect: aktuell.ausschnittsrahmen,
          element: aktuell.element,
          note: notiz,
          runtime: laufzeit(angemeldet),
          log: protokollSeit(PROTOKOLL_SEKUNDEN, aktuell.zeitpunkt),
        },
        screen: aktuell.screen,
        voll: angehaengt ?? aktuell.vollbild?.blob ?? null,
        ausschnitt: aktuell.ausschnitt?.blob ?? null,
      };
      await eintragAnhaengen(gespeichert);
      setOrdner(stand.id);
      setAnzahl(await anzahlLesen());
      // Erst ein gelungener Eintrag loescht die alte Meldung -- sonst naehme
      // der naechste Klick sie weg, bevor das Menue sie zeigt.
      setFehler(null);
    } catch (grund) {
      setFehler(`Nicht gesichert: ${meldung(grund)}`);
    } finally {
      freigeben(aktuell.vollbild, aktuell.ausschnitt);
    }
  }

  async function sitzungSichern(): Promise<Sitzungsstand> {
    const vorhanden = await sitzungLesen();
    if (vorhanden) return vorhanden;
    const neu = sitzungAnlegenDaten(new Date());
    await sitzungAnlegen(neu);
    return neu;
  }

  async function sitzungOeffnen() {
    setModus("sitzung");
    try {
      const eintraege = await eintraegeLesen();
      setBytes(groesse(eintraege));
      setAnzahl(eintraege.length);
    } catch {
      setBytes(0);
    }
  }

  /** Gibt die Fehlermeldung zurueck, oder null, wenn es geklappt hat. */
  async function teilen(): Promise<string | null> {
    try {
      const stand = await sitzungLesen();
      if (!stand) return "Keine Sitzung zum Teilen.";
      const buendel = await sitzungBuendeln(stand, await eintraegeLesen());
      await weitergeben(buendel);
      return null;
    } catch (grund) {
      return `Nicht geteilt: ${meldung(grund)}`;
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
          freigabe={freigabe}
          beiAusschnitt={() => setModus("ausschnitt")}
          beiSeite={() => void ausschnittGewaehlt(ganzeSeite())}
          beiElement={() => setModus("element")}
          beiNotiz={() => setModus("notiz")}
          beiSitzung={() => void sitzungOeffnen()}
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
          anhaengenMoeglich={entwurf.vollbild === null}
          beiSichern={(notiz, bild) => void sichern(notiz, bild)}
          beiVerwerfen={verwerfen}
        />
      ) : null}

      {modus === "sitzung" ? (
        <>
          <div className={styles.schleier} onClick={verwerfen} />
          <SitzungBlatt
            anzahl={anzahl}
            ordner={ordner}
            bytes={bytes}
            freigabeAktiv={freigabeAktiv()}
            beiTeilen={teilen}
            beiNeueSitzung={() => {
              void sitzungVerwerfen().then(() => {
                setAnzahl(0);
                setBytes(0);
                setOrdner(null);
              });
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
