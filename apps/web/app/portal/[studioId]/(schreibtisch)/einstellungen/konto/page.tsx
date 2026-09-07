import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Reiter } from "../../../../bausteine/Reiter";
import { Seite } from "../../../../bausteine/Seite";
import styles from "../../../../portal.module.css";
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

  const basis = `/portal/${studioId}/einstellungen`;

  return (
    <Seite
      titel="Einstellungen"
      vorspann="Deine E-Mail, dein Passwort und die Sitzung, in der du gerade angemeldet bist."
    >
      {/* `aktiv` steht hier fest: diese Route ist der Konto-Reiter. Kein
          usePathname, kein Client-Rand -- die Seite weiss von sich, welche
          sie ist. */}
      <Reiter
        name="Einstellungen"
        eintraege={[
          { href: basis, label: "Studio", aktiv: false },
          { href: `${basis}/konto`, label: "Konto", aktiv: true },
        ]}
      />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Konto</h2>
        </div>
        <div className={styles.sectionBody}>
          <div className={styles.field}>
            <span className={styles.label}>E-Mail</span>
            <p className={styles.rowTitle}>{user.email}</p>
            {mitgliedschaft && studio ? (
              <p className={styles.rowMeta}>
                {rollenLabel[mitgliedschaft.role] ?? mitgliedschaft.role} von{" "}
                {studio.name} seit{" "}
                {/* Wochentag abgekuerzt ("Do., 6. August 2026"), wie
                    EinstellungenKonto.dc.html es zeichnet: der Wochentag
                    ordnet das Datum ein, das ausgeschriebene
                    "Donnerstag" schiebt dafuer die Zeile ueber die
                    Kartenbreite. */}
                {new Intl.DateTimeFormat("de-DE", {
                  weekday: "short",
                  day: "numeric",
                  month: "long",
                  year: "numeric",
                }).format(new Date(mitgliedschaft.created_at))}
              </p>
            ) : null}
          </div>
        </div>
      </section>

      <PasswortAendernFormular />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Abmelden</h2>
        </div>
        <div className={styles.sectionBody}>
          <AbmeldeKnopf />
        </div>
      </section>
    </Seite>
  );
}
