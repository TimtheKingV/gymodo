"use client";

import { useId, useState } from "react";
import type { Category, LoadUnit } from "@fitretro/domain/belastung";
import { Auswahl } from "./Auswahl";
import { Rad } from "./EinstellungRad";
import {
  EINHEIT_ANZEIGE,
  KATEGORIE_OPTIONEN,
  belastungMinimum,
  belastungsWerte,
  dezimal,
  einheitenFuer,
  einrasten,
  istEinheit,
  istKategorie,
  maxAb,
} from "./einstellungVorschlaege";
import styles from "../portal.module.css";

export type ModellBelastungStart = {
  category: Category;
  loadUnit: LoadUnit;
  loadMin: number;
  loadMax: number | null;
  loadStep: number;
  secondaryUnit: LoadUnit | null;
  secondaryMin: number | null;
  secondaryMax: number | null;
  secondaryStep: number | null;
};

/**
 * Kategorie, Belastungseinheit, Rastung und optionale Nebenbelastung eines
 * Geraetemodells -- der Nachfolger von ModellGewichtRad (Cardio-Spec
 * Abschnitt 7). Fuer ein Kraftgeraet sieht das Formular aus wie vorher
 * plus zwei Auswahlfelder, die auf Kraft und kg stehen; das Rad zeigt
 * dieselben Werte und Startwerte.
 *
 * Das Rad bekommt die Einheit als `key`: wechselt der Trainer von kg auf
 * km/h, werden Listen UND Startwerte neu geladen (0,5 statt 2,5 als
 * Schritt). Ohne Neuaufbau bliebe das Rad auf einer Zeile stehen, die es
 * in der neuen Liste nicht gibt.
 *
 * Die Nebenbelastung ist zugeklappt, solange sie "keine" ist -- ihr Rad
 * erscheint erst mit einer Einheit. Seine Spalten heissen anders als die
 * des Hauptrads ("Nebenbelastung ab" statt "Minimum"): zwei Raeder mit
 * gleichlautenden Spalten waeren fuer Screenreader und Tests nicht
 * auseinanderzuhalten.
 *
 * Testnotiz 03.10.: Die Kategorie bestimmt die Einheiten (#1) -- Kraft nur
 * kg, ohne Belastungs- und Nebenbelastungsfeld; Cardio alles ausser kg.
 * Beim Anlegen am Schreibtisch ist sie vorher gefragt (`kategorie`), dann
 * steht hier kein Kategoriefeld. Das Rad steht Schritt zuerst (#2), weil
 * der Schritt den Takt des Maximums setzt und man links anfaengt; das
 * Minimum hat keine Spalte mehr, es ist der kleinste Wert ueber null im
 * Takt (belastungMinimum). Die Nebenbelastung behaelt ihr "ab": 0 %
 * Neigung ist ein echter Wert.
 */
export function ModellBelastungRad({
  gross = false,
  start,
  kategorie,
}: {
  gross?: boolean;
  /** Bestandswerte beim Bearbeiten; ohne sie gelten die Kraft-Vorgaben. */
  start?: ModellBelastungStart;
  /** Vorher gefragt (geraete/neu): kein Kategoriefeld, nur diese Einheiten. */
  kategorie?: Category;
}) {
  const startKategorie = start?.category ?? kategorie ?? "kraft";
  const [category, setCategory] = useState<Category>(startKategorie);
  const [loadUnit, setLoadUnit] = useState<LoadUnit>(
    start?.loadUnit ?? einheitenFuer(startKategorie)[0]!,
  );
  const [secondaryUnit, setSecondaryUnit] = useState<LoadUnit | "">(
    start?.secondaryUnit ?? "",
  );
  const kategorieId = useId();
  const einheitId = useId();
  const nebenId = useId();

  // Bestandswerte nur fuer die Einheit, mit der sie gespeichert wurden --
  // nach einem Wechsel gelten die Vorgaben der neuen Einheit.
  const hauptStart =
    start && start.loadUnit === loadUnit
      ? {
          min: dezimal(start.loadMin),
          max: start.loadMax === null ? "" : dezimal(start.loadMax),
          schritt: einrasten(belastungsWerte(loadUnit).schritt, dezimal(start.loadStep)),
        }
      : belastungsWerte(loadUnit).start;
  // Der gewaehlte Schritt bestimmt den Takt von Minimum und Maximum
  // (Testnotiz 23.09., zweite Sitzung, #3). Je Einheit gemerkt: der
  // Schritt von kg gilt nach einem Wechsel auf km/h nicht mehr.
  const [hauptSchritt, setHauptSchritt] = useState({ einheit: loadUnit, wert: hauptStart.schritt });
  const schritt = hauptSchritt.einheit === loadUnit ? hauptSchritt.wert : hauptStart.schritt;
  const haupt = belastungsWerte(loadUnit, schritt);
  const minimum = belastungMinimum(
    schritt,
    start && start.loadUnit === loadUnit ? dezimal(start.loadMin) : undefined,
  );

  // Einheiten der Kategorie; ein Bestandswert ausserhalb bleibt waehlbar,
  // statt beim Oeffnen still auf eine andere Einheit zu springen.
  const einheiten = mitBestand(einheitenFuer(category), start?.loadUnit);
  const nebenEinheiten = mitBestand(
    category === "cardio" ? einheitenFuer("cardio") : [],
    start?.secondaryUnit ?? undefined,
  );
  const zeigeNeben = nebenEinheiten.length > 0 || secondaryUnit !== "";

  function kategorieWaehlen(neu: Category) {
    setCategory(neu);
    const passend = einheitenFuer(neu);
    if (!passend.includes(loadUnit)) setLoadUnit(passend[0]!);
    if (secondaryUnit && neu === "kraft") setSecondaryUnit("");
  }

  const nebenStart =
    secondaryUnit &&
    start &&
    start.secondaryUnit === secondaryUnit &&
    start.secondaryMin !== null &&
    start.secondaryStep !== null
      ? {
          min: dezimal(start.secondaryMin),
          max: start.secondaryMax === null ? "" : dezimal(start.secondaryMax),
          schritt: einrasten(belastungsWerte(secondaryUnit).schritt, dezimal(start.secondaryStep)),
        }
      : secondaryUnit
        ? belastungsWerte(secondaryUnit).start
        : undefined;
  const [nebenSchritt, setNebenSchritt] = useState<{ einheit: LoadUnit | ""; wert: string }>({
    einheit: secondaryUnit,
    wert: nebenStart?.schritt ?? "",
  });
  const neben = secondaryUnit
    ? belastungsWerte(
        secondaryUnit,
        nebenSchritt.einheit === secondaryUnit ? nebenSchritt.wert : nebenStart?.schritt,
      )
    : null;

  return (
    <>
      <div className={styles.grid}>
        {kategorie ? (
          <input type="hidden" name="category" value={category} />
        ) : (
          <div className={styles.field}>
            <label className={styles.label} htmlFor={kategorieId}>
              Kategorie
            </label>
            <Auswahl
              id={kategorieId}
              name="category"
              gross={gross}
              value={category}
              onChange={(wert) => kategorieWaehlen(istKategorie(wert) ? wert : "kraft")}
              optionen={KATEGORIE_OPTIONEN}
            />
          </div>
        )}
        {einheiten.length > 1 ? (
          <div className={styles.field}>
            <label className={styles.label} htmlFor={einheitId}>
              Belastung
            </label>
            <Auswahl
              id={einheitId}
              name="loadUnit"
              gross={gross}
              value={loadUnit}
              onChange={(wert) => setLoadUnit(istEinheit(wert) ? wert : einheiten[0]!)}
              optionen={optionen(einheiten)}
            />
          </div>
        ) : (
          <input type="hidden" name="loadUnit" value={loadUnit} />
        )}
      </div>

      <input type="hidden" name="loadMin" value={minimum} />
      <Rad
        key={loadUnit}
        gross={gross}
        spalten={[
          {
            name: "loadStep",
            label: "Schritt",
            werte: haupt.schritt,
            start: hauptStart.schritt,
            onWahl: (wert) => setHauptSchritt({ einheit: loadUnit, wert }),
          },
          {
            name: "loadMax",
            label: "Maximum",
            werte: maxAb(haupt.max, minimum),
            start: hauptStart.max,
          },
        ]}
      />

      {zeigeNeben ? (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={nebenId}>
            Nebenbelastung
          </label>
          <Auswahl
            id={nebenId}
            name="secondaryUnit"
            gross={gross}
            value={secondaryUnit}
            onChange={(wert) => setSecondaryUnit(istEinheit(wert) ? wert : "")}
            optionen={[{ wert: "", anzeige: "keine" }, ...optionen(nebenEinheiten)]}
          />
          <span className={styles.hint}>
            Ein zweiter Regler, der die Intensität verändert — die Neigung am
            Laufband, die Trittfrequenz am Ergometer. Das Mitglied trägt ihn
            je Satz ein; die Steigerung betrifft nur die Belastung.
          </span>
        </div>
      ) : null}

      {neben && nebenStart ? (
        <Rad
          key={`neben-${secondaryUnit}`}
          gross={gross}
          spalten={[
            {
              name: "secondaryStep",
              label: "Nebenbelastung Schritt",
              werte: neben.schritt,
              start: nebenStart.schritt,
              onWahl: (wert) => setNebenSchritt({ einheit: secondaryUnit, wert }),
            },
            {
              name: "secondaryMin",
              label: "Nebenbelastung ab",
              werte: neben.min,
              start: nebenStart.min,
            },
            {
              name: "secondaryMax",
              label: "Nebenbelastung bis",
              werte: neben.max,
              start: nebenStart.max,
            },
          ]}
        />
      ) : null}
    </>
  );
}

function mitBestand(liste: LoadUnit[], bestand: LoadUnit | undefined): LoadUnit[] {
  return bestand && !liste.includes(bestand) ? [...liste, bestand] : liste;
}

function optionen(einheiten: LoadUnit[]) {
  return einheiten.map((wert) => ({ wert, anzeige: EINHEIT_ANZEIGE[wert] }));
}
