import Link from "next/link";
import { listCourseTemplates } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../../../../Form";
import { terminAnlegenAction } from "../../../../kurse-actions";
import styles from "../../../../../portal.module.css";
import { SerienVorschau } from "./SerienVorschau";

export default async function TerminAnlegenPage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string }>;
  searchParams: Promise<{ vorlage?: string }>;
}) {
  const { studioId } = await params;
  const { vorlage: vorgewaehlt } = await searchParams;
  const client = await createServerSupabaseClient();
  const vorlagen = await listCourseTemplates(client, studioId);
  const basis = `/portal/${studioId}/kurse`;

  const { data: studio } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle<{ timezone: string }>();
  const zeitzone = studio?.timezone ?? "Europe/Berlin";

  // Ohne Vorlage gibt es nichts anzulegen -- und ein leeres Auswahlfeld
  // waere ein stummer Deaktiviert-Zustand (Portalspec Abschnitt 5).
  if (vorlagen.length === 0) {
    return (
      <main className={styles.content}>
        <p>
          <Link href={basis}>← Kurse</Link>
        </p>
        <h1 className={styles.pageTitle}>Termin anlegen</h1>
        <div className={styles.empty}>
          <p className={styles.emptyTitle}>Es gibt noch keine Kursvorlage.</p>
          <p className={styles.emptyNext}>
            Ein Termin entsteht aus einer Vorlage.{" "}
            <Link href={`${basis}/vorlagen`}>Leg zuerst eine an.</Link>
          </p>
        </div>
      </main>
    );
  }

  const standard = vorlagen.find((v) => v.id === vorgewaehlt) ?? vorlagen[0]!;

  return (
    <main className={styles.content}>
      <p>
        <Link href={basis}>← Kurse</Link>
      </p>
      <h1 className={styles.pageTitle}>Termin anlegen</h1>

      <AktionsFormular
        action={terminAnlegenAction.bind(null, studioId)}
        submitLabel="Termine anlegen"
      >
        <label>
          Vorlage
          <select name="vorlageId" defaultValue={standard.id} required>
            {vorlagen.map((vorlage) => (
              <option key={vorlage.id} value={vorlage.id}>
                {vorlage.name}
              </option>
            ))}
          </select>
        </label>

        <SerienVorschau zeitzone={zeitzone} />

        <Feld
          name="dauer"
          label="Dauer in Minuten"
          type="number"
          defaultValue={String(standard.defaultDurationMin)}
          required
        />
        <Feld
          name="plaetze"
          label="Plätze"
          type="number"
          defaultValue={String(standard.defaultCapacity)}
          required
        />
        <Feld name="raum" label="Raum" />
        <Feld
          name="trainerName"
          label="Trainer (Anzeigename)"
          defaultValue={standard.defaultInstructorName ?? ""}
        />
      </AktionsFormular>
    </main>
  );
}
