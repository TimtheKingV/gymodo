import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "../../../../portal.module.css";
import { Reiter } from "../Reiter";
import { AbmeldeKnopf, PasswortAendernFormular } from "../EinstellungenActions";

const rollenLabel: Record<string, string> = {
  owner: "Inhaber",
  trainer: "Trainer",
  member: "Mitglied",
};

export default async function KontoPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();

  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) redirect("/login");

  // memberships_select_own (0001) reicht dafuer -- die eigene Zeile darf
  // jeder lesen, auch ein einfaches Mitglied. Dieser Reiter ist deshalb
  // bewusst nicht auf Personal beschraenkt: das eigene Passwort geht
  // jeden etwas an.
  const { data: mitgliedschaft } = await client
    .from("studio_memberships")
    .select("role, created_at")
    .eq("studio_id", studioId)
    .eq("user_id", user.id)
    .maybeSingle<{ role: string; created_at: string }>();

  const { data: studio } = await client
    .from("studios")
    .select("name")
    .eq("id", studioId)
    .maybeSingle<{ name: string }>();

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Einstellungen</h1>
      <p className={styles.pageLead}>
        Deine E-Mail, dein Passwort und die Sitzung, in der du gerade
        angemeldet bist.
      </p>

      <Reiter studioId={studioId} />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Konto</h2>
        </div>
        <p className={styles.rowTitle}>{user.email}</p>
        {mitgliedschaft && studio ? (
          <p className={styles.rowMeta}>
            {rollenLabel[mitgliedschaft.role] ?? mitgliedschaft.role} von {studio.name}{" "}
            seit{" "}
            {new Intl.DateTimeFormat("de-DE", { dateStyle: "full" }).format(
              new Date(mitgliedschaft.created_at),
            )}
          </p>
        ) : null}
      </section>

      <PasswortAendernFormular />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Abmelden</h2>
        </div>
        <AbmeldeKnopf />
      </section>
    </main>
  );
}
