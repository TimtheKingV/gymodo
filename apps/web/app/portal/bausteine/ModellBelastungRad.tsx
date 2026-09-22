"use client";

import { useId, useState } from "react";
import type { Category, LoadUnit } from "@fitretro/domain/belastung";
import { Auswahl } from "./Auswahl";
import { Rad } from "./EinstellungRad";
import {
  EINHEIT_OPTIONEN,
  KATEGORIE_OPTIONEN,
  NEBENBELASTUNG_OPTIONEN,
  belastungsWerte,
  dezimal,
  istEinheit,
  istKategorie,
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
 */
export function ModellBelastungRad({
  gross = false,
  start,
}: {
  gross?: boolean;
  /** Bestandswerte beim Bearbeiten; ohne sie gelten die Kraft-Vorgaben. */
  start?: ModellBelastungStart;
}) {
  const [category, setCategory] = useState<Category>(start?.category ?? "kraft");
  const [loadUnit, setLoadUnit] = useState<LoadUnit>(start?.loadUnit ?? "kg");
  const [secondaryUnit, setSecondaryUnit] = useState<LoadUnit | "">(
    start?.secondaryUnit ?? "",
  );
  const kategorieId = useId();
  const einheitId = useId();
  const nebenId = useId();

  const haupt = belastungsWerte(loadUnit);
  // Bestandswerte nur fuer die Einheit, mit der sie gespeichert wurden --
  // nach einem Wechsel gelten die Vorgaben der neuen Einheit.
  const hauptStart =
    start && start.loadUnit === loadUnit
      ? {
          min: dezimal(start.loadMin),
          max: start.loadMax === null ? "" : dezimal(start.loadMax),
          schritt: dezimal(start.loadStep),
        }
      : haupt.start;

  const neben = secondaryUnit ? belastungsWerte(secondaryUnit) : null;
  const nebenStart =
    neben &&
    start &&
    start.secondaryUnit === secondaryUnit &&
    start.secondaryMin !== null &&
    start.secondaryStep !== null
      ? {
          min: dezimal(start.secondaryMin),
          max: start.secondaryMax === null ? "" : dezimal(start.secondaryMax),
          schritt: dezimal(start.secondaryStep),
        }
      : neben?.start;

  return (
    <>
      <div className={styles.grid}>
        <div className={styles.field}>
          <label className={styles.label} htmlFor={kategorieId}>
            Kategorie
          </label>
          <Auswahl
            id={kategorieId}
            name="category"
            gross={gross}
            value={category}
            onChange={(wert) => setCategory(istKategorie(wert) ? wert : "kraft")}
            optionen={KATEGORIE_OPTIONEN}
          />
        </div>
        <div className={styles.field}>
          <label className={styles.label} htmlFor={einheitId}>
            Belastung
          </label>
          <Auswahl
            id={einheitId}
            name="loadUnit"
            gross={gross}
            value={loadUnit}
            onChange={(wert) => setLoadUnit(istEinheit(wert) ? wert : "kg")}
            optionen={EINHEIT_OPTIONEN}
          />
        </div>
      </div>

      <Rad
        key={loadUnit}
        gross={gross}
        spalten={[
          { name: "loadMin", label: "Minimum", werte: haupt.min, start: hauptStart.min },
          { name: "loadMax", label: "Maximum", werte: haupt.max, start: hauptStart.max },
          { name: "loadStep", label: "Schritt", werte: haupt.schritt, start: hauptStart.schritt },
        ]}
      />

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
          optionen={NEBENBELASTUNG_OPTIONEN}
        />
        <span className={styles.hint}>
          Ein zweiter Regler, der die Intensität verändert — die Neigung am
          Laufband, die Trittfrequenz am Ergometer. Das Mitglied trägt ihn
          je Satz ein; die Steigerung betrifft nur die Belastung.
        </span>
      </div>

      {neben && nebenStart ? (
        <Rad
          key={`neben-${secondaryUnit}`}
          gross={gross}
          spalten={[
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
            {
              name: "secondaryStep",
              label: "Nebenbelastung Schritt",
              werte: neben.schritt,
              start: nebenStart.schritt,
            },
          ]}
        />
      ) : null}
    </>
  );
}
