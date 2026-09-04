import Link from "next/link";
import { notFound } from "next/navigation";
import { listCourseParticipants, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../../../Form";
import {
  teilnehmerEntfernenAction,
  terminAbsagenAction,
  terminSpeichernAction,
} from "../../../../kurse-actions";
import styles from "../../../../../portal.module.css";
import { uhrzeit } from "../../woche";

export default async function TerminPage({
  params,
}: {
  params: Promise<{ studioId: string; sessionId: string }>;
}) {
  const { studioId, sessionId } = await params;
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;

  // course_week ist der einzige Lesepfad, der die Belegung als Zahl
  // liefert -- deshalb auch hier, mit einem engen Fenster um den Termin.
  // Die Startzeit dafuer kommt aus der Tabelle; course_sessions_select
  // gibt sie jedem Mitglied des Studios.
  const { data: zeile } = await client
    .from("course_sessions")
    .select("starts_at")
    .eq("id", sessionId)
    .maybeSingle<{ starts_at: string }>();
  if (!zeile) notFound();

  const mitte = new Date(zeile.starts_at).getTime();
  const plan = await listCourseWeek(
    client,
    studioId,
    new Date(mitte - 1000).toISOString(),
    new Date(mitte + 1000).toISOString(),
  );
  const termin = plan.sessions.find((s) => s.sessionId === sessionId);
  if (!termin) notFound();

  const teilnehmer = await listCourseParticipants(client, sessionId);
  const gebucht = teilnehmer.filter((t) => t.status === "booked");
  const wartend = teilnehmer.filter((t) => t.status === "waitlisted");

  const zeitpunkt = (iso: string) =>
    new Date(iso).toLocaleString("de-DE", { timeZone: plan.timezone });

  return (
    <main className={styles.content}>
      <p>
        <Link href={basis}>← Kurse</Link>
      </p>
      <h1 className={styles.pageTitle}>{termin.name}</h1>
      <p>
        {termin.localDay} · {uhrzeit(termin.startsAt, plan.timezone)}
        {termin.room === null ? "" : ` · ${termin.room}`}
        {termin.status === "cancelled" ? " · abgesagt" : ""}
      </p>

      <section className={styles.section}>
        <h2>Termin</h2>
        <AktionsFormular
          action={terminSpeichernAction.bind(null, studioId, sessionId)}
          submitLabel="Änderungen speichern"
        >
          <Feld
            name="startsAt"
            label="Beginn"
            defaultValue={termin.startsAt}
            hint="ISO 8601 mit Zonenangabe, etwa 2026-11-05T17:00:00.000Z. Ein Datumsfeld bekommt dieser Bildschirm in Phase 5."
            required
          />
          <Feld
            name="dauer"
            label="Dauer in Minuten"
            type="number"
            defaultValue={String(termin.durationMin)}
            required
          />
          <Feld
            name="plaetze"
            label="Plätze"
            type="number"
            defaultValue={String(termin.capacity)}
            required
          />
          <Feld name="raum" label="Raum" defaultValue={termin.room ?? ""} />
          <Feld
            name="trainerName"
            label="Trainer (Anzeigename)"
            defaultValue={termin.instructorName ?? ""}
          />
        </AktionsFormular>
      </section>

      <section className={styles.section}>
        <h2>
          Angemeldet ({gebucht.length} von {termin.capacity})
        </h2>
        {gebucht.length === 0 ? (
          <p className={styles.absent}>Noch niemand angemeldet.</p>
        ) : (
          <ul>
            {gebucht.map((person) => (
              <li key={person.userId}>
                <span>{person.email}</span>
                <span className={styles.navItemMeta}>
                  {person.promotedAt === null
                    ? `Angemeldet ${zeitpunkt(person.bookedAt)}`
                    : `Nachgerückt ${zeitpunkt(person.promotedAt)}`}
                </span>
                <AktionsKnopf
                  aktion={teilnehmerEntfernenAction.bind(
                    null,
                    studioId,
                    sessionId,
                    person.userId,
                  )}
                  label="Abmelden"
                  bestaetigung="Wirklich abmelden?"
                  laufendLabel="Wird abgemeldet …"
                  art="destructive"
                />
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <h2>Warteliste ({wartend.length})</h2>
        {wartend.length === 0 ? (
          <p className={styles.absent}>Niemand wartet.</p>
        ) : (
          <ul>
            {wartend.map((person) => (
              <li key={person.userId}>
                <span>{person.email}</span>
                <span className={styles.navItemMeta}>
                  Position {person.waitlistPosition}
                </span>
                <AktionsKnopf
                  aktion={teilnehmerEntfernenAction.bind(
                    null,
                    studioId,
                    sessionId,
                    person.userId,
                  )}
                  label="Von der Liste nehmen"
                  bestaetigung="Wirklich von der Liste nehmen?"
                  laufendLabel="Wird entfernt …"
                  art="destructive"
                />
              </li>
            ))}
          </ul>
        )}
        <p className={styles.emptyNext}>
          Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie nicht.
        </p>
      </section>

      <section className={styles.section}>
        <h2>Absagen</h2>
        {termin.status === "cancelled" ? (
          <p className={styles.absent}>
            Dieser Termin ist abgesagt. Angemeldete Mitglieder sehen, dass er ausfällt.
          </p>
        ) : (
          <>
            <p>
              Der Termin bleibt sichtbar und wird als abgesagt gekennzeichnet.
              Angemeldete Mitglieder sehen, dass er ausfällt.
            </p>
            <AktionsKnopf
              aktion={terminAbsagenAction.bind(null, studioId, sessionId)}
              label="Termin absagen"
              bestaetigung="Ja, Termin absagen"
              laufendLabel="Wird abgesagt …"
              art="destructive"
            />
          </>
        )}
      </section>
    </main>
  );
}
