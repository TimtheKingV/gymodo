import Link from "next/link";
import { DomainError, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "../../../portal.module.css";
import { nachTagenGruppieren, uhrzeit, wochenFenster } from "./woche";

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
      <main className={styles.content}>
        <h1 className={styles.pageTitle}>Kurse</h1>
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.error}>
              {fehler instanceof DomainError
                ? fehler.message
                : "Der Kursplan liess sich nicht laden."}
            </p>
            <p className={styles.emptyNext}>
              Nichts ist geändert worden. Versuch es gleich noch einmal.
            </p>
          </div>
        </div>
      </main>
    );
  }

  const gruppen = nachTagenGruppieren(plan.sessions, fenster.von, plan.timezone);

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Kurse</h1>

      <nav className={styles.section} aria-label="Woche wählen">
        <Link href={`${basis}?woche=${fenster.vorige}`}>← Vorige Woche</Link>
        <span>{fenster.titel}</span>
        <Link href={`${basis}?woche=${fenster.naechste}`}>Nächste Woche →</Link>
      </nav>

      <div className={styles.section}>
        <Link href={`${basis}/termin/neu`}>Termin anlegen</Link>
        {" · "}
        <Link href={`${basis}/vorlagen`}>Vorlagen verwalten</Link>
      </div>

      {gruppen.map((gruppe) => (
        <section key={gruppe.localDay} className={styles.section}>
          <h2>{gruppe.ueberschrift}</h2>
          {gruppe.sessions.length === 0 ? (
            <p className={styles.absent}>Keine Kurse</p>
          ) : (
            <ul>
              {gruppe.sessions.map((termin) => (
                <li key={termin.sessionId}>
                  <Link href={`${basis}/termin/${termin.sessionId}`}>
                    {uhrzeit(termin.startsAt, plan.timezone)} · {termin.name}
                  </Link>
                  <div className={styles.navItemMeta}>
                    {termin.instructorName ?? "Ohne Trainer"}
                    {termin.room === null ? "" : ` · ${termin.room}`}
                  </div>
                  <div className={styles.navItemMeta}>
                    {termin.status === "cancelled" ? (
                      "abgesagt"
                    ) : (
                      <>
                        {termin.bookedCount} von {termin.capacity}
                        {termin.waitlistCount > 0
                          ? ` · +${termin.waitlistCount} Warteliste`
                          : ""}
                      </>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      ))}
    </main>
  );
}
