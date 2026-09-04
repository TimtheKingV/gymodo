import Link from "next/link";
import { listCourseTemplates } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../../../Form";
import { vorlageAnlegenAction } from "../../../kurse-actions";
import styles from "../../../../portal.module.css";

export default async function KursvorlagenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const vorlagen = await listCourseTemplates(client, studioId);
  const basis = `/portal/${studioId}/kurse`;

  return (
    <main className={styles.content}>
      <p>
        <Link href={basis}>← Kurse</Link>
      </p>
      <h1 className={styles.pageTitle}>Kursvorlagen</h1>
      <p>
        Eine Vorlage beschreibt den Kurs. Die einzelnen Termine im Kalender entstehen
        daraus — und behalten ihre Werte, auch wenn du die Vorlage später änderst.
      </p>

      <section className={styles.section}>
        <h2>Alle Vorlagen</h2>
        {vorlagen.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Vorlage angelegt.</p>
            <p className={styles.emptyNext}>
              Leg unten die erste an — danach kannst du Termine dafür in den Kalender
              stellen.
            </p>
          </div>
        ) : (
          <ul>
            {vorlagen.map((vorlage) => (
              <li key={vorlage.id}>
                <Link href={`${basis}/vorlagen/${vorlage.id}`}>{vorlage.name}</Link>
                <div className={styles.navItemMeta}>
                  {vorlage.defaultDurationMin} min · {vorlage.defaultCapacity} Plätze
                  {vorlage.defaultInstructorName === null
                    ? ""
                    : ` · Standard: ${vorlage.defaultInstructorName}`}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <h2>Vorlage anlegen</h2>
        <AktionsFormular
          action={vorlageAnlegenAction.bind(null, studioId)}
          submitLabel="Vorlage anlegen"
        >
          <Feld name="name" label="Name" required />
          <Feld name="beschreibung" label="Beschreibung" />
          <Feld name="dauer" label="Dauer in Minuten" type="number" defaultValue="60" required />
          <Feld name="plaetze" label="Plätze" type="number" defaultValue="16" required />
          <Feld name="trainerName" label="Standard-Trainer (Anzeigename)" />
        </AktionsFormular>
      </section>
    </main>
  );
}
