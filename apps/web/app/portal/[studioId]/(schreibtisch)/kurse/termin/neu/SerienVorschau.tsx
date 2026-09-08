"use client";

import { useId, useMemo, useState } from "react";
import { MAX_SERIENTERMINE, ortszeitZuInstant, serienTermine } from "@fitretro/domain/serie";
import { AktionsFormular, Feld } from "../../../../../Form";
import { Auswahl } from "../../../../../bausteine/Auswahl";
import { Erlaeuterung } from "../../../../../bausteine/Erlaeuterung";
import { Zeile, Zeilen } from "../../../../../bausteine/Zeile";
import styles from "../../../../../portal.module.css";
import type { ActionResult } from "../../../../../actions";
import { alsOrtszeit, feldZuInstant, tagUndZeit } from "../zeit";

/**
 * Wie viele Termine der Serie ausgeschrieben dastehen, bevor gekuerzt wird.
 *
 * Drei, wie TerminAnlegen.dc.html es zeichnet ("… 11 weitere" unter drei
 * Zeilen). Vorher waren es fuenf -- eine Zahl ohne Herkunft. Drei reicht:
 * die Vorschau soll zeigen, WELCHER Rhythmus entsteht (derselbe Wochentag,
 * dieselbe Uhrzeit), nicht die ganze Serie ersetzen. Wie viele es insgesamt
 * werden, steht im Satz darueber und auf dem Absendeknopf.
 */
const VORSCHAU_ZEILEN = 3;

/**
 * Das ganze Formular von "Termin anlegen" (TerminAnlegen.dc.html).
 *
 * Bis Aufgabe 22b war dies nur die Vorschau, eingehaengt zwischen die
 * Felder der Seite. Jetzt traegt die Komponente das Formular, und der
 * Grund ist eine Zeile Beschriftung: der Absendeknopf heisst "14 Termine
 * anlegen", nicht "Termine anlegen" -- der Knopf sagt, wie viel er
 * anrichtet. Die Zahl entsteht aus den Formularwerten und lebt damit im
 * Browser; die Beschriftung sitzt an AktionsFormular. Der kleinste Weg
 * dorthin ist, den Zustand ueber BEIDE zu heben, statt Form.tsx um einen
 * Rueckkanal zu erweitern -- Form.tsx steht nicht im Umfang dieser
 * Aufgabe, und in Aufgabe 20 ist genau diese Grenze schon einmal gezogen
 * worden.
 *
 * Der Preis ist, dass die Felder daneben (Dauer, Plätze, Raum, Trainer)
 * mit in den Client wandern. Sie tragen nur Vorgabewerte aus der Vorlage,
 * kein Serverwissen -- die Werte kommen als Eigenschaften herein.
 *
 * Gerechnet wird mit derselben Funktion wie auf dem Server -- nicht mit
 * einer zweiten Fassung, die knapp danebenliegt.
 */
export function TerminAnlegenFormular({
  aktion,
  zeitzone,
  vorlagen,
  vorgewaehlt,
  dauer,
  plaetze,
  trainerName,
}: {
  aktion: (vorher: unknown, formular: FormData) => Promise<ActionResult>;
  zeitzone: string;
  vorlagen: { id: string; name: string }[];
  vorgewaehlt: string;
  dauer: number;
  plaetze: number;
  trainerName: string;
}) {
  const vorlageId = useId();
  const [vorlage, setVorlage] = useState(vorgewaehlt);
  const [datum, setDatum] = useState("");
  const [uhrzeit, setUhrzeit] = useState("");
  const [bis, setBis] = useState("");

  const termine = useMemo(() => {
    const start = feldZuInstant(datum, uhrzeit, zeitzone);
    if (start === null) return [];
    if (bis === "") return [start];
    // Mittag in der Zone des Studios: serienTermine vergleicht auf den
    // Ortstag, und die Mittagslage haelt genug Abstand zu beiden
    // Tagesgrenzen.
    const bisTeile = alsOrtszeit(bis, 12, 0);
    if (bisTeile === null) return [start];
    return serienTermine(start, ortszeitZuInstant(bisTeile, zeitzone), zeitzone);
  }, [datum, uhrzeit, bis, zeitzone]);

  // Der Knopf traegt die Zahl der Serie. Solange kein Datum steht, gibt es
  // keine Zahl -- und eine erfundene ("0 Termine anlegen") waere schlechter
  // als keine.
  const absendeLabel =
    termine.length === 0
      ? "Termine anlegen"
      : termine.length === 1
        ? "1 Termin anlegen"
        : `${termine.length} Termine anlegen`;

  return (
    <div className={styles.seitenformular}>
      <AktionsFormular action={aktion} submitLabel={absendeLabel}>
        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <h2 className={styles.sectionTitle}>Termin</h2>
          </div>
          <div className={styles.sectionBody}>
            <div className={styles.field}>
              <label className={styles.label} htmlFor={vorlageId}>
                Vorlage
              </label>
              <Auswahl
                id={vorlageId}
                name="vorlageId"
                value={vorlage}
                onChange={setVorlage}
                optionen={vorlagen.map((eintrag) => ({
                  wert: eintrag.id,
                  anzeige: eintrag.name,
                }))}
              />
            </div>

            <div className={styles.grid}>
              <Feld
                name="datumLokal"
                label="Datum"
                type="date"
                value={datum}
                onChange={(e) => setDatum(e.target.value)}
                required
              />
              <Feld
                name="uhrzeitLokal"
                label="Uhrzeit"
                type="time"
                value={uhrzeit}
                onChange={(e) => setUhrzeit(e.target.value)}
                required
              />
            </div>
            {/* Der Server bekommt den Zeitpunkt mit Zonenangabe, nicht die
                nackte Wandzeit aus den Feldern. */}
            <input
              type="hidden"
              name="startsAt"
              value={termine.length > 0 ? termine[0]!.toISOString() : ""}
            />

            <div className={styles.grid}>
              <Feld
                name="dauer"
                label="Dauer in Minuten"
                type="number"
                defaultValue={String(dauer)}
                required
              />
              <Feld
                name="plaetze"
                label="Plätze"
                type="number"
                defaultValue={String(plaetze)}
                required
              />
            </div>
            <div className={styles.grid}>
              <Feld name="raum" label="Raum" />
              <Feld
                name="trainerName"
                label="Trainer (Anzeigename)"
                defaultValue={trainerName}
              />
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <h2 className={styles.sectionTitle}>Wiederholen</h2>
          </div>
          <div className={styles.sectionBody}>
            {/* Kein Feld "Wiederholung" mit der einen Wahl "Wöchentlich":
                serie.ts kennt genau diesen Rhythmus, und eine Auswahl mit
                einem Eintrag verspricht eine Wahl, die es nicht gibt. Das
                Artboard zeichnet sie; sie waere heute eine Attrappe. */}
            <div className={styles.grid}>
              <Feld
                name="wiederholungBisLokal"
                label="Wöchentlich wiederholen bis"
                type="date"
                value={bis}
                onChange={(e) => setBis(e.target.value)}
              />
            </div>
            <p className={styles.sectionNote}>
              Leer lassen für einen einzelnen Termin.
            </p>
            <input
              type="hidden"
              name="wiederholungBis"
              value={
                bis === "" || termine.length === 0
                  ? ""
                  : termine[termine.length - 1]!.toISOString()
              }
            />
          </div>
        </section>

        {termine.length > 0 ? (
          <p className={styles.sectionNote}>
            {termine.length === 1
              ? "Dieser eine Termin wird angelegt."
              : `Diese ${termine.length} Termine werden angelegt.`}{" "}
            Jeder ist danach einzeln änderbar und absagbar.
          </p>
        ) : null}

        {termine.length > 0 ? (
          <section className={styles.section}>
            <Zeilen>
              {termine.slice(0, VORSCHAU_ZEILEN).map((termin) => (
                <Zeile key={termin.toISOString()} titel={tagUndZeit(termin, zeitzone)} />
              ))}
              {termine.length > VORSCHAU_ZEILEN ? (
                <Zeile
                  titel={
                    <span className={styles.absent}>
                      … {termine.length - VORSCHAU_ZEILEN} weitere
                    </span>
                  }
                />
              ) : null}
            </Zeilen>
          </section>
        ) : null}

        {termine.length > 0 ? (
          <Erlaeuterung>
            Änderst du die Vorlage später, bleiben diese {termine.length}{" "}
            {termine.length === 1 ? "Termin" : "Termine"} unverändert — sie behalten
            ihre eigenen Werte.
          </Erlaeuterung>
        ) : null}

        {termine.length === MAX_SERIENTERMINE ? (
          <p className={styles.warning}>
            Mehr als {MAX_SERIENTERMINE} Termine legt das Portal auf einmal nicht an.
            Wähle ein früheres Enddatum.
          </p>
        ) : null}
      </AktionsFormular>
    </div>
  );
}
