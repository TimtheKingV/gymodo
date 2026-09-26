import Link from "next/link";
import { DomainError, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Seite } from "../../../bausteine/Seite";
import { Zeile, Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import styles from "../../../portal.module.css";
import { AnsichtUmschalter, Blaettern, Monatsraster, Wochenstreifen } from "./Kalender";
import {
  kalenderTage,
  monatsFenster,
  nachTagenGruppieren,
  ortszeitAlsDatum,
  uhrzeit,
  wochenFenster,
} from "./woche";

/**
 * Der Kursplan einer Woche (Kurse.dc.html).
 *
 * Kein eigenes <main> mehr (Befund 41): die Landmarke traegt
 * (schreibtisch)/layout.tsx fuer alle Kinder. Diese Datei entstand in
 * Phase 4 auf einem eigenen Zweig gegen den Stand von vor Aufgabe 4 und
 * brachte ihre eigene mit -- zwei Hauptbereiche je Route, und die
 * .content-Polsterung lag doppelt: der Kursplan stand 40 px weiter innen
 * als jede andere Seite des Portals.
 *
 * Eine Akzentflaeche, "Termin anlegen". "Vorige Woche", "Naechste Woche"
 * und "Vorlagen verwalten" sind Nebenaktionen und tragen .secondary --
 * das Artboard zeichnet die letzte als blassen 13-px-Textlink unter der
 * Leiste, aber genau das ist Befund 37: globals.css nimmt jedem Link
 * Farbe und Unterstreichung, und im Fliesstext bleibt dann null
 * Unterschied zum Text daneben. Als Pille ist sie das, was sie ist.
 *
 * Testnotiz 25.09., #1: oben ein Umschalter Woche | Monat, in der Woche
 * ein Streifen wie in der App (Kalender.tsx), im Monat ein Raster, aus dem
 * ein Tipp in die Woche des Tages fuehrt. Die Ansicht steht in der Adresse
 * (?ansicht=monat&monat=2026-09), wie die Woche auch.
 */
export default async function KursePage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string }>;
  searchParams: Promise<{ woche?: string; ansicht?: string; monat?: string }>;
}) {
  const { studioId } = await params;
  const { woche, ansicht: ansichtParam, monat } = await searchParams;
  const ansicht = ansichtParam === "monat" ? "monat" : "woche";
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;

  // Die Zeitzone kommt aus der Antwort von course_week, aber das Fenster
  // muss vorher feststehen. Deshalb erst das Studio lesen -- studios_select
  // gibt jedem Mitglied seine Zeile.
  const { data: studio } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle<{ timezone: string }>();
  const zeitzone = studio?.timezone ?? "Europe/Berlin";

  const fenster = wochenFenster(woche, zeitzone);
  const monatFenster = monatsFenster(ansicht === "monat" ? monat : fenster.monat, zeitzone);
  // Das Fenster der Abfrage: im Monat das ganze Raster, sonst die Woche.
  // Dieselbe course_week-Abfrage, nur breiter.
  const abfrage = ansicht === "monat" ? monatFenster : fenster;

  let plan: Awaited<ReturnType<typeof listCourseWeek>>;
  try {
    plan = await listCourseWeek(client, studioId, abfrage.von, abfrage.bis);
  } catch (fehler) {
    return (
      <Seite titel="Kurse">
        <Zustand
          art="fehler"
          titel={
            fehler instanceof DomainError
              ? fehler.message
              : "Der Kursplan liess sich nicht laden."
          }
          naechsterSchritt="Nichts ist geändert worden. Versuch es gleich noch einmal."
        />
      </Seite>
    );
  }

  const gruppen = nachTagenGruppieren(plan.sessions, fenster.von, plan.timezone);
  const heute = ortszeitAlsDatum(new Date(), plan.timezone);
  // Aus der Woche in den Monat ihres Donnerstags, aus dem Monat in dessen
  // erste Woche -- der Umschalter verliert den Ort nicht.
  const wocheHref =
    ansicht === "monat" ? `${basis}?woche=${monatFenster.monat}-01` : `${basis}?woche=${fenster.montag}`;
  const monatHref = `${basis}?ansicht=monat&monat=${monatFenster.monat}`;

  return (
    <Seite titel="Kurse">
      <div className={styles.wochenleiste}>
        <AnsichtUmschalter ansicht={ansicht} wocheHref={wocheHref} monatHref={monatHref} />
        <div className={styles.rowActions}>
          <Link className={styles.secondary} href={`${basis}/vorlagen`}>
            Vorlagen verwalten
          </Link>
          <Link className={styles.primary} href={`${basis}/termin/neu`}>
            Termin anlegen
          </Link>
        </div>
      </div>

      {ansicht === "monat" ? (
        <>
          <nav className={styles.wochenwahl} aria-label="Monat wählen">
            <Blaettern
              href={`${basis}?ansicht=monat&monat=${monatFenster.vorige}`}
              label="Voriger Monat"
              richtung="zurueck"
            />
            <span className={styles.wochenTitel}>{monatFenster.titel}</span>
            <Blaettern
              href={`${basis}?ansicht=monat&monat=${monatFenster.naechste}`}
              label="Nächster Monat"
              richtung="vor"
            />
          </nav>
          <Monatsraster
            basis={basis}
            tage={kalenderTage(
              monatFenster.erster,
              monatFenster.tage,
              heute,
              plan.sessions,
              monatFenster.monat,
            )}
          />
        </>
      ) : (
        <>
          <nav className={styles.wochenwahl} aria-label="Woche wählen">
            {/* <a>, kein <Link> -- dritter Fall derselben Sache, nachgezogen
                am 17. September. Nexts Client-Router laesst einen Wechsel,
                der nur den Suchparameter aendert, im Produktionsbau ins
                Leere laufen: das Termindetail musste am 6. September
                wechseln, die Mitgliederliste heute frueher, und im CI-Lauf
                35269314873 blieb hier der Kursplan nach einem Klick auf
                "Vorige Woche" auf derselben Woche stehen.

                Das ist kein Testproblem: wer im Studio auf die Vorwoche
                klickt und dieselbe Woche sieht, klickt noch einmal. Ein
                volles Dokument zu laden ist hier ohnehin richtig -- die
                Seite traegt keinen Browserzustand, der verlorenginge, und
                die Woche steht in der Adresse.

                Seit der Testnotiz 25.09. (#1) Pfeile statt Textpillen, wie
                in der App; der Name steht im aria-label (Kalender.tsx). */}
            <Blaettern
              href={`${basis}?woche=${fenster.vorige}`}
              label="Vorige Woche"
              richtung="zurueck"
            />
            <span className={styles.wochenTitel}>{fenster.titel}</span>
            <Blaettern
              href={`${basis}?woche=${fenster.naechste}`}
              label="Nächste Woche"
              richtung="vor"
            />
          </nav>
          <Wochenstreifen
            tage={kalenderTage(fenster.montag, 7, heute, plan.sessions)}
          />
        </>
      )}

      {ansicht === "monat" ? null : gruppen.map((gruppe) => (
        <Abschnitt key={gruppe.localDay} id={`tag-${gruppe.localDay}`} titel={gruppe.ueberschrift}>
          {gruppe.sessions.length === 0 ? (
            // Kein Zustand-Baustein: ein Tag ohne Kurse ist keine leere
            // Liste, die einen naechsten Schritt braucht, sondern eine
            // Tatsache -- so zeichnet es auch das Artboard, als eine
            // blasse Zeile in der Karte des Tages.
            <p className={styles.absent}>Keine Kurse</p>
          ) : (
            <Zeilen>
              {gruppe.sessions.map((termin) => {
                const abgesagt = termin.status === "cancelled";
                return (
                  <Zeile
                    key={termin.sessionId}
                    titel={
                      <Link
                        href={`${basis}/termin/${termin.sessionId}`}
                        className={abgesagt ? styles.abgesagt : undefined}
                      >
                        {uhrzeit(termin.startsAt, plan.timezone)} · {termin.name}
                      </Link>
                    }
                    meta={
                      <span className={abgesagt ? styles.abgesagt : undefined}>
                        {termin.instructorName ?? "Ohne Trainer"}
                        {termin.room === null ? "" : ` · ${termin.room}`}
                      </span>
                    }
                    aktionen={
                      abgesagt ? (
                        <span className={`${styles.badge} ${styles.badgeRevoked}`}>abgesagt</span>
                      ) : (
                        <div className={styles.belegung}>
                          <div className={styles.belegungZahl}>
                            {termin.bookedCount} von {termin.capacity}
                          </div>
                          {termin.waitlistCount > 0 ? (
                            <div className={styles.belegungZusatz}>
                              +{termin.waitlistCount} Warteliste
                            </div>
                          ) : null}
                        </div>
                      )
                    }
                  />
                );
              })}
            </Zeilen>
          )}
        </Abschnitt>
      ))}
    </Seite>
  );
}
