import { Rail } from "../Rail";
import { ladeKatalog, railZahlen } from "../catalog";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "../../portal.module.css";

export default async function StudioLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const [katalog, zahlen] = await Promise.all([ladeKatalog(studioId), railZahlen(studioId)]);

  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();

  return (
    <div className={styles.shell}>
      <Rail
        studioId={studioId}
        studioName={katalog.studioName}
        email={user?.email ?? ""}
        zahlen={zahlen}
      />
      <main className={styles.content}>{children}</main>
    </div>
  );
}
