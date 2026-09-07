import { ladeKatalog, railZahlen } from "../catalog";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { MobileNav } from "../MobileNav";
import { UploadsMarke, UploadsProvider } from "./Uploads";
import styles from "./halle.module.css";

/**
 * Der Gang durch die Halle hat keine feste Rail: er laeuft auf 390 px,
 * einhaendig, neben einem Geraet -- die Schrittleiste bleibt die sichtbare
 * Navigation des Gangs selbst.
 *
 * Das Hamburger-Menu (MobileNav, geteilt mit dem Schreibtisch) haengt eine
 * Ebene darunter: fuer den seltenen Fall, dass jemand mitten im Gang zu
 * Tags oder Leute muss. Das schliesst Befund 45
 * (docs/superpowers/specs/2026-09-03-portal-frontend-design.md) anders, als
 * die fruehere Fassung dieses Kommentars vorschlug -- nicht durch eine
 * zweite sichtbare Leiste ueber der Schrittleiste, sondern durch dieselbe
 * Schublade wie am Schreibtisch, die erst auf Tap erscheint. Dafuer laedt
 * dieses Layout jetzt zusaetzlich railZahlen() und die Nutzer-E-Mail, wie
 * (schreibtisch)/layout.tsx es schon tut.
 */
export default async function HalleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const [katalog, zahlen] = await Promise.all([
    ladeKatalog(studioId),
    railZahlen(studioId),
  ]);

  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();

  return (
    <UploadsProvider studioId={studioId}>
      <div className={styles.seite}>
        <MobileNav
          studioId={studioId}
          studioName={katalog.studioName}
          email={user?.email ?? ""}
          zahlen={zahlen}
          extra={<UploadsMarke studioId={studioId} />}
          nurMobil={false}
        />
        <main className={styles.inhalt}>{children}</main>
      </div>
    </UploadsProvider>
  );
}
