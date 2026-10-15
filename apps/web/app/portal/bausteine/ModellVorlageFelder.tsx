"use client";

import { useId, useState } from "react";
import type { Category } from "@fitretro/domain/belastung";
import { Feld } from "../Form";
import { Auswahl } from "./Auswahl";
import { GymtavoTypFeld } from "./GymtavoTypFeld";
import { ModellBelastungRad } from "./ModellBelastungRad";
import {
  ANDERER_HERSTELLER,
  herstellerOptionen,
  nameNachVorschlag,
  produkteVon,
  produktName,
  vorlageStart,
} from "./herstellerWahl";
import type { ProduktVorlage, TypVorlage } from "./typVorlage";
import styles from "../portal.module.css";
import wahl from "./ModellVorlageFelder.module.css";

export type VorlageWahl = { typ: TypVorlage | null; produkt: ProduktVorlage | null };

/**
 * Gymtavo-Typ, Hersteller, Herstellermodell, Name und Belastung beider
 * Modellformulare (Schreibtisch und Halle). Reihenfolge wie der Gedanke am
 * Geraet: was ist es, von wem, welches genau (Spec
 * 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 5.2 und 6.5).
 *
 * Name und Belastung sind Vorschlaege: ein Typ- oder Produktwechsel ersetzt
 * nur, was selbst vorgeschlagen war (nameNachVorschlag). Das Rad bekommt
 * Typ und Produkt als `key` -- nur ein Neuaufbau laedt seine Startwerte neu
 * (Kopfkommentar ModellBelastungRad).
 *
 * Es gibt nie zwei Felder "manufacturer": React 19 schickt sonst beide,
 * und die Action liest das erste.
 */
export function ModellVorlageFelder({
  typen,
  gross = false,
  kategorie,
  onVorlage,
}: {
  typen: TypVorlage[];
  gross?: boolean;
  /** Vorher gefragt (geraete/neu); fehlt in der Halle. */
  kategorie?: Category;
  /** Die Halle macht davon die Fotopflicht abhaengig. */
  onVorlage?: (wahl: VorlageWahl) => void;
}) {
  const [typ, setTyp] = useState<TypVorlage | null>(null);
  const [hersteller, setHersteller] = useState("");
  const [produkt, setProdukt] = useState<ProduktVorlage | null>(null);
  const [nichtDabei, setNichtDabei] = useState(false);
  const [name, setName] = useState("");
  const [vorschlag, setVorschlag] = useState<string | null>(null);
  const herstellerId = useId();

  function vorschlagen(neu: string | null) {
    setName((aktuell) => nameNachVorschlag(aktuell, vorschlag, neu));
    setVorschlag(neu);
  }

  function typGewaehlt(typId: string) {
    const neu = typen.find((t) => t.id === typId) ?? null;
    setTyp(neu);
    setHersteller("");
    setProdukt(null);
    setNichtDabei(false);
    vorschlagen(neu?.name ?? null);
    onVorlage?.({ typ: neu, produkt: null });
  }

  function produktGewaehlt(neu: ProduktVorlage | null) {
    setProdukt(neu);
    setNichtDabei(neu === null);
    vorschlagen(neu ? produktName(neu) : (typ?.name ?? null));
    onVorlage?.({ typ, produkt: neu });
  }

  // Ein neuer Hersteller verwirft das Modell des alten, aber nicht den
  // Typ: Name und Rad fallen auf die Typwerte zurueck.
  function herstellerGewaehlt(wert: string) {
    setHersteller(wert);
    setNichtDabei(false);
    if (produkt) {
      setProdukt(null);
      vorschlagen(typ?.name ?? null);
      onVorlage?.({ typ, produkt: null });
    }
  }

  const mitAuswahl = typ !== null && typ.produkte.length > 0;
  const anderer = hersteller === ANDERER_HERSTELLER;
  const modelle = mitAuswahl && hersteller !== "" && !anderer ? produkteVon(typ, hersteller) : [];

  return (
    <>
      <GymtavoTypFeld gross={gross} typen={typen} start={null} onChange={typGewaehlt} />
      {typ ? (
        <p className={styles.hint} role="status">
          {`Werte vom Typ ${typ.name} übernommen – bitte ans Gerät anpassen.`}
        </p>
      ) : null}

      {mitAuswahl ? (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={herstellerId}>
            Hersteller
          </label>
          <Auswahl
            id={herstellerId}
            value={hersteller}
            onChange={herstellerGewaehlt}
            optionen={herstellerOptionen(typ)}
            platzhalter="Hersteller wählen"
            suche="Hersteller suchen"
            gross={gross}
          />
          {hersteller !== "" && !anderer ? <input type="hidden" name="manufacturer" value={hersteller} /> : null}
        </div>
      ) : (
        <Feld gross={gross} name="manufacturer" label="Hersteller" placeholder="Technogym" />
      )}
      {mitAuswahl && anderer ? (
        <Feld gross={gross} name="manufacturer" label="Herstellername" placeholder="Eigenbau" />
      ) : null}

      {modelle.length > 0 ? (
        <fieldset className={wahl.karten}>
          <legend className={styles.label}>Modell</legend>
          {modelle.map((p) => (
            <label key={p.id} className={wahl.karte}>
              <input
                type="radio"
                name="produktWahl"
                value={p.id}
                checked={produkt?.id === p.id}
                onChange={() => produktGewaehlt(p)}
              />
              {p.fotoUrl ?? typ?.fotoUrl ? (
                // Dekorativ (alt=""): der Name steht darunter und benennt das Radio.
                <img className={wahl.bild} src={p.fotoUrl ?? typ?.fotoUrl ?? ""} alt="" />
              ) : null}
              <span className={wahl.titel}>{produktName(p)}</span>
              {!p.fotoUrl && typ?.fotoUrl ? <span className={wahl.symbol}>Symbolbild</span> : null}
            </label>
          ))}
          <label className={wahl.karte}>
            <input
              type="radio"
              name="produktWahl"
              value=""
              checked={nichtDabei}
              onChange={() => produktGewaehlt(null)}
            />
            <span className={wahl.titel}>Mein Modell ist nicht dabei</span>
          </label>
        </fieldset>
      ) : null}
      {produkt ? <input type="hidden" name="catalogProductId" value={produkt.id} /> : null}

      <Feld
        gross={gross}
        name="name"
        label="Name"
        required
        placeholder="Latzug"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      {produkt?.note ? <p className={styles.hint}>{produkt.note}</p> : null}
      <ModellBelastungRad
        key={`${typ?.id ?? "ohne-typ"}:${produkt?.id ?? ""}`}
        gross={gross}
        {...(kategorie ? { kategorie } : {})}
        {...(typ ? { start: vorlageStart(typ, produkt), typCardioWerte: typ.cardioWerte } : {})}
      />
    </>
  );
}
