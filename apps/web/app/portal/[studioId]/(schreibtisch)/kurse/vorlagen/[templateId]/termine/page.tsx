import Link from "next/link";
import { listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Abschnitt } from "../../../../../../bausteine/Abschnitt";
import { Zeile, Zeilen } from "../../../../../../bausteine/Zeile";
import { Zustand } from "../../../../../../bausteine/Zustand";
import styles from "../../../../../../portal.module.css";
import { uhrzeit } from "../../../woche";

/**
 * Der Reiter "Termine" einer Kursvorlage (Kursvorlage.dc.html).
 *
 * Vorher stand diese Liste als dritter Abschnitt unter Stammdaten und
 * Foto auf einer Seite; seit Aufgabe 22a ist sie ein eigener Reiter --
 * ein Reiter, ein Bildschirm (Struktur-Spec Abschnitt 1). Rueckweg,
 * Titel, Untertitel und Reiterleiste stehen im layout.tsx darueber.
 *
 * Keine Akzentflaeche: der Reiter legt nichts an. "Termin anlegen" im
 * Leer-Zustand fuehrt auf den Bildschirm, der es tut, und ist dort die
 * Hauptaktion -- hier ist es der Weg dorthin.
 */

/** Designsystem 10: Zeitangaben in der Studio-Zeitzone, nicht der des Servers. */
function datum(iso: string, timeZone: string): string {
  return new Date(iso).toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone,
  });
}

export default async function KursvorlageTerminePage({
  params,
}: {
  params: Promise<{ studioId: string; templateId: string }>;
}) {
  const { studioId, templateId } = await params;
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;

  // Dasselbe Fenster wie die Zahl im Reiter (layout.tsx): jetzt bis in
  // vier Wochen.
  const jetzt = new Date();
  const inVierWochen = new Date(jetzt.getTime() + 28 * 24 * 3_600_000);
  const plan = await listCourseWeek(
    client,
    studioId,
    jetzt.toISOString(),
    inVierWochen.toISOString(),
  );
  const termine = plan.sessions.filter((termin) => termin.templateId === templateId);

  return (
    // Keine Abschnittsnotiz "in den naechsten 4 Wochen": genau das steht
    // schon als Zusatz am Reiter zwei Zeilen darueber, und zweimal
    // derselbe Satz auf einem Bildschirm ist keine zweite Auskunft.
    <Abschnitt titel="Termine">
      {termine.length === 0 ? (
        <Zustand
          art="leer"
          titel="Keine Termine in den nächsten 4 Wochen."
          naechsterSchritt="Aus dieser Vorlage entsteht ein Termin erst, wenn du ihn in den Kalender stellst."
          aktion={
            <Link
              className={styles.secondary}
              href={`${basis}/termin/neu?vorlage=${templateId}`}
            >
              Termin anlegen
            </Link>
          }
        />
      ) : (
        <Zeilen>
          {termine.map((termin) => {
            const abgesagt = termin.status === "cancelled";
            return (
              <Zeile
                key={termin.sessionId}
                titel={
                  <Link
                    href={`${basis}/termin/${termin.sessionId}`}
                    className={abgesagt ? styles.abgesagt : undefined}
                  >
                    {datum(termin.startsAt, plan.timezone)} ·{" "}
                    {uhrzeit(termin.startsAt, plan.timezone)}
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
  );
}
