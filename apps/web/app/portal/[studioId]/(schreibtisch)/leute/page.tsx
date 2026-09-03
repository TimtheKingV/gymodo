import Link from "next/link";
import { DomainError, listStudioMembers } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "../../../portal.module.css";
import { MitgliedZeile } from "./LeuteActions";

export default async function LeutePage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const pfad = `/portal/${studioId}/leute`;

  let mitglieder: Awaited<ReturnType<typeof listStudioMembers>> = [];
  let fehler: string | null = null;
  try {
    mitglieder = await listStudioMembers(client, studioId);
  } catch (e) {
    // requireStudioStaff (in listStudioMembers) meldet ein einfaches
    // Mitglied mit "unauthorized" -- der Layout prueft nur Mitgliedschaft,
    // nicht Rolle, also muss diese Seite sich selbst sperren. Ohne diesen
    // fruehen Return liefe die Seite als "Liste liess sich nicht laden"
    // weiter, statt klarzustellen, dass die Seite Trainern vorbehalten ist.
    if (e instanceof DomainError && e.code === "unauthorized") {
      return (
        <main className={styles.content}>
          <h1 className={styles.pageTitle}>Leute</h1>
          <div className={styles.section}>
            <div className={styles.empty}>
              <p className={styles.emptyTitle}>
                Diese Seite ist Trainern und Inhabern vorbehalten.
              </p>
            </div>
          </div>
        </main>
      );
    }
    fehler = e instanceof DomainError ? e.message : "Die Liste liess sich nicht laden.";
  }

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Leute</h1>

      <p className={styles.sectionNote}>
        Mitglieder treten über den Studio-Code bei —{" "}
        <Link href={`/portal/${studioId}/einstellungen`}>Einstellungen</Link>
      </p>

      <div className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Mitglieder und Mitarbeiter</h2>
        </div>
        {fehler ? (
          <p className={styles.error}>{fehler}</p>
        ) : mitglieder.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch niemand ist beigetreten.</p>
            <p className={styles.emptyNext}>
              Gib den Beitrittscode weiter, dann erscheint die Person hier.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {mitglieder.map((person) => (
              <MitgliedZeile key={person.userId} studioId={studioId} pfad={pfad} person={person} />
            ))}
          </ul>
        )}
      </div>
    </main>
  );
}
