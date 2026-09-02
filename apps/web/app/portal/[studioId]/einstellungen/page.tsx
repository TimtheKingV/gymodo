import { DomainError, getStudioSettings } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../Form";
import { studioSpeichern } from "../../actions";
import styles from "../../portal.module.css";
import { Reiter } from "./Reiter";
import { BeitrittscodeKarte } from "./EinstellungenActions";

export default async function EinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const pfad = `/portal/${studioId}/einstellungen`;

  let einstellungen: Awaited<ReturnType<typeof getStudioSettings>>;
  try {
    einstellungen = await getStudioSettings(client, studioId);
  } catch (fehler) {
    // Wie in leute/page.tsx: das Layout prueft nur Mitgliedschaft, nicht
    // Rolle -- diese Seite muss sich selbst sperren, sonst laedt sie
    // darunter den echten Beitrittscode.
    if (fehler instanceof DomainError && fehler.code === "unauthorized") {
      return (
        <main className={styles.content}>
          <h1 className={styles.pageTitle}>Einstellungen</h1>
          <div className={styles.section}>
            <div className={styles.empty}>
              <p className={styles.emptyTitle}>
                Diese Seite ist Trainern und Inhabern vorbehalten.
              </p>
              <p className={styles.emptyNext}>
                Frag jemanden mit Trainerrolle, wenn sich etwas ändern soll.
              </p>
            </div>
          </div>
        </main>
      );
    }
    throw fehler;
  }

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Einstellungen</h1>
      <p className={styles.pageLead}>
        Stammdaten des Studios, die Regel für Kurse und der Code, mit dem
        Mitglieder beitreten.
      </p>

      <Reiter studioId={studioId} />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Stammdaten</h2>
        </div>
        <AktionsFormular
          action={studioSpeichern.bind(null, studioId, pfad)}
          submitLabel="Änderungen speichern"
        >
          <div className={styles.grid}>
            <Feld
              name="name"
              label="Name"
              required
              defaultValue={einstellungen.name}
            />
            <Feld
              name="timezone"
              label="Zeitzone"
              required
              defaultValue={einstellungen.timezone}
              hint="Zum Beispiel Europe/Berlin. Sie bestimmt, wann ein Kurstermin beginnt."
            />
            <Feld
              name="cancellationDeadlineHours"
              label="Stornofrist"
              required
              inputMode="numeric"
              defaultValue={String(einstellungen.cancellationDeadlineHours)}
              hint="Stunden vor Beginn. Bis wann sich ein Mitglied abmelden kann. Das ist eure Regel, keine Vorgabe von gymodo. 0 heißt: bis zum Beginn."
            />
          </div>
        </AktionsFormular>
      </section>

      <BeitrittscodeKarte
        studioId={studioId}
        pfad={pfad}
        code={einstellungen.joinCode}
        active={einstellungen.joinCodeActive}
      />
    </main>
  );
}
