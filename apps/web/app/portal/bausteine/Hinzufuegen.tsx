"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./bausteine.module.css";
import portalStyles from "../portal.module.css";

/**
 * Ein Anlege-Formular hinter einem Knopf ueber der Liste (Testnotiz 22.09.,
 * #4 und #10): vorher stand das Formular immer offen unter der Liste und
 * nahm auf dem Telefon mehr Platz ein als das, was schon angelegt war.
 *
 * Ist die Liste noch leer, steht das Formular gleich offen -- dann ist
 * Anlegen das Einzige, was es auf der Seite zu tun gibt, und ein Knopf
 * davor waere ein Klick ohne Gegenwert.
 *
 * Der Zustand ist Client-State und ueberlebt das Revalidieren nach dem
 * Anlegen: wer gerade die erste Einstellung angelegt hat, sieht das
 * Formular weiter offen und kann die zweite eintragen, statt dass es unter
 * ihm zuklappt, nur weil die Liste nicht mehr leer ist.
 *
 * Genau eine Akzentflaeche: zu ist es der Knopf, offen die Absende-Aktion
 * im Formular. "Schließen" ist deshalb nur .secondary.
 */
export function Hinzufuegen({
  knopf,
  titel,
  notiz,
  offen: offenAnfangs = false,
  children,
}: {
  /** Text des Akzentknopfs, z. B. "Gerät hinzufügen". */
  knopf: string;
  /** Ueberschrift der aufgeklappten Karte, z. B. "Modell anlegen". */
  titel: string;
  notiz?: React.ReactNode;
  /** Anfangs offen -- fuer eine leere Liste. */
  offen?: boolean;
  children: React.ReactNode;
}) {
  const [offen, setOffen] = useState(offenAnfangs);
  const karte = useRef<HTMLElement>(null);
  const knopfRef = useRef<HTMLButtonElement>(null);
  const vomNutzer = useRef(false);

  // Fokus folgt dem Klick: aufgeklappt ins erste Feld, zugeklappt zurueck
  // auf den Knopf. Nur nach einer Nutzergeste, nicht beim ersten Rendern --
  // eine Seite, die beim Laden den Fokus ins Formular reisst, oeffnet auf
  // dem Telefon ungefragt die Tastatur.
  useEffect(() => {
    if (!vomNutzer.current) return;
    if (offen) {
      karte.current
        ?.querySelector<HTMLInputElement>("input:not([type=hidden]), textarea")
        ?.focus();
    } else {
      knopfRef.current?.focus();
    }
  }, [offen]);

  function umschalten(neu: boolean) {
    vomNutzer.current = true;
    setOffen(neu);
  }

  if (!offen) {
    return (
      <div className={styles.hinzufuegenLeiste}>
        <button
          ref={knopfRef}
          type="button"
          className={portalStyles.primary}
          aria-expanded={false}
          onClick={() => umschalten(true)}
        >
          + {knopf}
        </button>
      </div>
    );
  }

  return (
    <section ref={karte} className={portalStyles.section}>
      <div className={portalStyles.sectionHead}>
        <h2 className={portalStyles.sectionTitle}>{titel}</h2>
        {notiz ? <span className={portalStyles.sectionNote}>{notiz}</span> : null}
        {offenAnfangs ? null : (
          <button
            type="button"
            className={styles.hinzufuegenSchliessen}
            aria-expanded
            aria-label={`${titel} schließen`}
            onClick={() => umschalten(false)}
          >
            Schließen
          </button>
        )}
      </div>
      {children}
    </section>
  );
}
