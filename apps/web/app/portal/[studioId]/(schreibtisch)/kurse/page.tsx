import Link from "next/link";
import { DomainError, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Seite } from "../../../bausteine/Seite";
import { Zeile, Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import styles from "../../../portal.module.css";
import { nachTagenGruppieren, uhrzeit, wochenFenster } from "./woche";

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
 */
export default async function KursePage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string }>;
  searchParams: Promise<{ woche?: string }>;
}) {
  const { studioId } = await params;
  const { woche } = await searchParams;
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

  let plan: Awaited<ReturnType<typeof listCourseWeek>>;
  try {
    plan = await listCourseWeek(client, studioId, fenster.von, fenster.bis);
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

  return (
    <Seite titel="Kurse">
      <div className={styles.wochenleiste}>
        <nav className={styles.wochenwahl} aria-label="Woche wählen">
          <Link className={styles.secondary} href={`${basis}?woche=${fenster.vorige}`}>
            ← Vorige Woche
          </Link>
          <span className={styles.wochenTitel}>{fenster.titel}</span>
          <Link className={styles.secondary} href={`${basis}?woche=${fenster.naechste}`}>
            Nächste Woche →
          </Link>
        </nav>
        <div className={styles.rowActions}>
          <Link className={styles.secondary} href={`${basis}/vorlagen`}>
            Vorlagen verwalten
          </Link>
          <Link className={styles.primary} href={`${basis}/termin/neu`}>
            Termin anlegen
          </Link>
        </div>
      </div>

      {gruppen.map((gruppe) => (
        <Abschnitt key={gruppe.localDay} titel={gruppe.ueberschrift}>
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
