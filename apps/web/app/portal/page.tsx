import { redirect } from "next/navigation";
import Link from "next/link";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "./portal.module.css";

/**
 * Einstieg ins Portal. Wer in genau einem Studio Trainer ist -- der
 * Normalfall -- landet direkt dort und sieht diese Seite nie.
 */
export default async function PortalPage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // memberships_select_staff (0030) laesst Mitarbeiter alle Zeilen ihres
  // Studios sehen, nicht nur die eigene -- ohne den user_id-Filter kaeme
  // hier fuer jeden Kollegen eine weitere Zeile desselben Studios zurueck.
  const { data: mitgliedschaften } = await supabase
    .from("studio_memberships")
    .select("role, studios (id, name)")
    .eq("user_id", user.id)
    .in("role", ["trainer", "owner"]);

  const studios = (mitgliedschaften ?? [])
    .map((zeile) => (zeile as unknown as { studios: { id: string; name: string } | null }).studios)
    .filter((studio): studio is { id: string; name: string } => studio !== null);

  if (studios.length === 1) redirect(`/portal/${studios[0]!.id}`);

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Trainerportal</h1>

      {studios.length === 0 ? (
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Du pflegst noch keinen Katalog.</p>
            <p className={styles.emptyNext}>
              Das Portal ist Trainern und Inhabern vorbehalten. Wenn du den
              Gerätekatalog deines Studios pflegen sollst, lass dich dort als
              Trainer eintragen.
            </p>
          </div>
        </div>
      ) : (
        <div className={styles.section}>
          <div className={styles.sectionHead}>
            <h2 className={styles.sectionTitle}>Studio wählen</h2>
          </div>
          <ul className={styles.rows}>
            {studios.map((studio) => (
              <li key={studio.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{studio.name}</div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studio.id}`}>
                    Öffnen
                  </Link>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </main>
  );
}
