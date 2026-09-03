import Link from "next/link";
import { getCourseTemplate, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../../../../Form";
import { vorlageSpeichernAction } from "../../../../kurse-actions";
import styles from "../../../../../portal.module.css";
import { uhrzeit } from "../../woche";

export default async function KursvorlagePage({
  params,
}: {
  params: Promise<{ studioId: string; templateId: string }>;
}) {
  const { studioId, templateId } = await params;
  const client = await createServerSupabaseClient();
  const vorlage = await getCourseTemplate(client, studioId, templateId);
  const basis = `/portal/${studioId}/kurse`;

  // Die Termine der naechsten vier Wochen, wie im Artboard.
  const jetzt = new Date();
  const inVierWochen = new Date(jetzt.getTime() + 28 * 24 * 3_600_000);
  const plan = await listCourseWeek(
    client,
    studioId,
    jetzt.toISOString(),
    inVierWochen.toISOString(),
  );
  const termine = plan.sessions.filter((s) => s.templateId === templateId);

  return (
    <main className={styles.content}>
      <p>
        <Link href={`${basis}/vorlagen`}>← Kursvorlagen</Link>
      </p>
      <h1 className={styles.pageTitle}>{vorlage.name}</h1>

      <section className={styles.section}>
        <h2>Stammdaten</h2>
        <AktionsFormular
          action={vorlageSpeichernAction.bind(null, studioId, templateId)}
          submitLabel="Änderungen speichern"
        >
          <Feld name="name" label="Name" defaultValue={vorlage.name} required />
          <Feld
            name="beschreibung"
            label="Beschreibung"
            defaultValue={vorlage.description ?? ""}
          />
          <Feld
            name="dauer"
            label="Dauer in Minuten"
            type="number"
            defaultValue={String(vorlage.defaultDurationMin)}
            required
          />
          <Feld
            name="plaetze"
            label="Plätze"
            type="number"
            defaultValue={String(vorlage.defaultCapacity)}
            required
          />
          <Feld
            name="trainerName"
            label="Standard-Trainer (Anzeigename)"
            defaultValue={vorlage.defaultInstructorName ?? ""}
          />
        </AktionsFormular>
      </section>

      <section className={styles.section}>
        <h2>Foto</h2>
        {/* Deaktiviert, aber nicht stumm (Portalspec Abschnitt 5): daneben
            steht, was fehlt. Kein Knopf, der nichts tut. */}
        <p className={styles.absent}>Noch kein Foto</p>
        <p className={styles.emptyNext}>
          Kursfotos kommen später — dafür fehlt noch der Ablageort. Die Kursbeschreibung
          trägt bis dahin allein.
        </p>
      </section>

      <section className={styles.section}>
        <h2>Termine ({termine.length}) in den nächsten 4 Wochen</h2>
        {termine.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Keine Termine in den nächsten 4 Wochen.</p>
            <p className={styles.emptyNext}>
              <Link href={`${basis}/termin/neu?vorlage=${templateId}`}>
                Termin anlegen
              </Link>
            </p>
          </div>
        ) : (
          <ul>
            {termine.map((termin) => (
              <li key={termin.sessionId}>
                <Link href={`${basis}/termin/${termin.sessionId}`}>
                  {termin.localDay} · {uhrzeit(termin.startsAt, plan.timezone)}
                  {termin.status === "cancelled" ? " · abgesagt" : ""}
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
    </main>
  );
}
