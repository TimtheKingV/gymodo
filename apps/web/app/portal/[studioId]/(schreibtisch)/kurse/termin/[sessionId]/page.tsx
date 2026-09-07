import { notFound } from "next/navigation";
import {
  getCourseTemplate,
  listCourseParticipants,
  listCourseWeek,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../../../Form";
import {
  teilnehmerEntfernenAction,
  terminAbsagenAction,
  terminSpeichernAction,
} from "../../../../kurse-actions";
import { Abschnitt } from "../../../../../bausteine/Abschnitt";
import { Erlaeuterung } from "../../../../../bausteine/Erlaeuterung";
import { Seite } from "../../../../../bausteine/Seite";
import { Zeile, Zeilen } from "../../../../../bausteine/Zeile";
import { Zustand } from "../../../../../bausteine/Zustand";
import styles from "../../../../../portal.module.css";
import { kuerzen } from "../../../leute/leute";
import { uhrzeit } from "../../woche";
import { langesDatum, tagUndZeit } from "../zeit";
import { TerminZeit } from "./TerminZeit";

/**
 * Ein einzelner Kurstermin (Termin.dc.html).
 *
 * Kein eigenes <main> mehr (Befund 41) -- die Landmarke traegt
 * (schreibtisch)/layout.tsx. Seite.tsx traegt den Rueckweg ueber dem Titel
 * jetzt selbst (rueckweg-Prop).
 *
 * Eine Akzentflaeche: "Änderungen speichern". "Abmelden", "Von der Liste
 * nehmen" und "Termin absagen" sind zerstoerend -- das Artboard zeichnet
 * sie mit danger-Umriss auf 40 px --, "Alle anzeigen" ist sekundaer.
 *
 * KEINE Namen. Das Artboard zeigt "M. Wolf" und "L. Bauer";
 * list_course_participants (0037) liefert user_id, E-Mail, Status,
 * Zeitpunkte und Wartelistenposition -- keinen Namen, genau wie
 * StudioMember (Befund 40). Ein Namensfeld waere eine Migration. Hier
 * steht die Adresse.
 *
 * Und nirgends steht, jemand werde benachrichtigt: Benachrichtigungen
 * existieren nicht (Designsystem 11, Struktur-Spec 8), promoted_at liegt
 * bereit, der Rest ist offen. Der Erste der Warteliste rueckt beim
 * Abmelden automatisch nach (0038) -- erfahren tut er es im Portal
 * niemand, und die Oberflaeche verspricht deshalb auch nichts.
 */

/**
 * Der Suchparameter, der die Kuerzung aufklappt -- MIT Namen (Befund 39).
 *
 * Aufgabe 19 hat das Muster als "?alle=1" gebaut, und auf dem Reiter
 * "Mitglieder" trug das: dort gibt es genau eine kuerzbare Liste. Dieser
 * Bildschirm hat zwei, "Angemeldet" und "Warteliste", und ein namenloser
 * Parameter klappte beide zugleich auf. Der Wert benennt seine Liste.
 *
 * Die Warteliste selbst kuerzt nicht: das Artboard kuerzt sie nicht, drei
 * Positionen sind keine Liste, die ueberlaeuft, und was dort verborgen
 * wuerde, sind genau die hinteren Plaetze -- die Auskunft, wegen der man
 * die Liste ueberhaupt aufschlaegt. Der Name des Parameters steht
 * trotzdem schon da, damit die zweite Liste, wenn sie ihn je braucht,
 * ihren eigenen bekommt statt diesen mitzubenutzen.
 */
const ALLE_ANGEMELDET = "angemeldet";

export default async function TerminPage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string; sessionId: string }>;
  searchParams: Promise<{ alle?: string }>;
}) {
  const { studioId, sessionId } = await params;
  const { alle } = await searchParams;
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;
  const pfad = `${basis}/termin/${sessionId}`;

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
  const { sichtbar, weitere } = kuerzen(gebucht, alle === ALLE_ANGEMELDET);

  // "Abweichend von der Vorlage (Standard: Marek T.)." -- der Satz steht
  // nur da, wenn er stimmt, und dafuer muss die Vorlage gelesen werden.
  // Sie kann fehlen (geloescht, oder aus einem fremden Studio); dann gibt
  // es keinen Standard, gegen den etwas abweichen koennte.
  let vorlagenTrainer: string | null = null;
  try {
    vorlagenTrainer = (
      await getCourseTemplate(client, studioId, termin.templateId)
    ).defaultInstructorName;
  } catch {
    vorlagenTrainer = null;
  }
  const trainerWeichtAb =
    vorlagenTrainer !== null && termin.instructorName !== vorlagenTrainer;

  const beginn = new Date(termin.startsAt);
  const ende = new Date(beginn.getTime() + termin.durationMin * 60_000);
  const kopfzeile = [
    `${langesDatum(beginn, plan.timezone)} · ${uhrzeit(termin.startsAt, plan.timezone)}–${uhrzeit(ende.toISOString(), plan.timezone)}`,
    termin.room,
    termin.status === "cancelled" ? "abgesagt" : null,
  ]
    .filter((teil): teil is string => teil !== null)
    .join(" · ");

  return (
    <Seite
      titel={termin.name}
      vorspann={kopfzeile}
      rueckweg={{ href: basis, label: "Kurse" }}
    >
      {/*
        Bewusst kein Abschnitt-Baustein: AktionsFormular bringt sein eigenes
        styles.sectionBody-Polster mit, das zusammen mit abschnittRumpf
        doppelt aufgetragen wuerde -- dieselbe Begruendung wie in
        geraete/page.tsx und im Stammdaten-Reiter der Kursvorlage.
      */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Termin</h2>
        </div>
        <AktionsFormular
          action={terminSpeichernAction.bind(null, studioId, sessionId)}
          submitLabel="Änderungen speichern"
        >
          <TerminZeit startsAt={termin.startsAt} zeitzone={plan.timezone} />
          <div className={styles.grid}>
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
          </div>
          <Feld
            name="trainerName"
            label="Trainer (Anzeigename)"
            defaultValue={termin.instructorName ?? ""}
          />
          {trainerWeichtAb ? (
            <p className={styles.sectionNote}>
              Abweichend von der Vorlage (Standard: {vorlagenTrainer}).
            </p>
          ) : null}
        </AktionsFormular>
      </section>

      <Abschnitt
        titel={`Angemeldet (${gebucht.length} von ${termin.capacity})`}
      >
        {gebucht.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch niemand angemeldet."
            naechsterSchritt="Wer sich anmeldet, steht hier — mit dem Zeitpunkt der Anmeldung."
          />
        ) : (
          <>
            <Zeilen>
              {sichtbar.map((person) => (
                <Zeile
                  key={person.userId}
                  titel={person.email}
                  meta={
                    person.promotedAt === null
                      ? `Angemeldet ${tagUndZeit(new Date(person.bookedAt), plan.timezone)}`
                      : `Nachgerückt ${tagUndZeit(new Date(person.promotedAt), plan.timezone)}`
                  }
                  aktionen={
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
                  }
                />
              ))}
            </Zeilen>
            {weitere > 0 ? (
              // Serverseitig gekuerzt, serverseitig aufgeklappt: ein
              // gewoehnlicher Link, kein Zustand im Browser (Aufgabe 19).
              //
              // Und ein <a>, kein <Link>: der Zielort unterscheidet sich
              // vom aktuellen NUR in der Suchanfrage, und genau dafuer tut
              // Nexts Client-Router im Produktionsbau nichts. Gemessen am
              // 6. September gegen `next start` -- der Router holt die
              // RSC-Nutzlast (200, text/x-component, 14 kB) und aendert die
              // Adresse trotzdem nicht, weder sofort noch nach drei
              // Sekunden; prefetch={false} aendert daran nichts. Im
              // Dev-Server geht derselbe Klick durch, und deshalb ist es
              // keinem Test aufgefallen: lokal laeuft E2E gegen `next dev`,
              // die CI gegen den Bau.
              //
              // Und es braucht den vollen Dateilauf: allein laeuft der Test
              // gruen, in Folge der uebrigen kurse-Tests rot. Dieselbe
              // Kehrseite wie bei Ruling 28 und dem Serientest -- dateiweises
              // Testen versteckt, was erst unter Last aufgeht.
              //
              // Ein volles Dokument zu laden ist hier ohnehin richtig: die
              // Seite traegt keinen Browserzustand, der verlorenginge.
              <div className={styles.rowActions}>
                <span className={styles.absent}>… {weitere} weitere</span>
                <a
                  href={`${pfad}?alle=${ALLE_ANGEMELDET}`}
                  className={styles.secondary}
                >
                  Alle anzeigen
                </a>
              </div>
            ) : null}
          </>
        )}
      </Abschnitt>

      <Abschnitt titel={`Warteliste (${wartend.length})`}>
        {wartend.length === 0 ? (
          <Zustand
            art="leer"
            titel="Niemand wartet."
            naechsterSchritt="Ist der Termin voll, stehen weitere Anmeldungen hier — in der Reihenfolge, in der sie eingegangen sind."
          />
        ) : (
          <Zeilen>
            {wartend.map((person) => (
              <Zeile
                key={person.userId}
                titel={person.email}
                meta={`Position ${person.waitlistPosition}`}
                aktionen={
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
                }
              />
            ))}
          </Zeilen>
        )}
      </Abschnitt>

      <Erlaeuterung>
        Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie
        nicht.
      </Erlaeuterung>

      <Abschnitt titel="Absagen">
        {termin.status === "cancelled" ? (
          <Zustand
            art="leer"
            titel="Dieser Termin ist abgesagt."
            naechsterSchritt="Angemeldete Mitglieder sehen, dass er ausfällt."
          />
        ) : (
          <div className={styles.rowActions}>
            <AktionsKnopf
              aktion={terminAbsagenAction.bind(null, studioId, sessionId)}
              label="Termin absagen"
              bestaetigung="Ja, Termin absagen"
              laufendLabel="Wird abgesagt …"
              art="destructive"
            />
            <span className={styles.sectionNote}>
              Der Termin bleibt sichtbar und wird als abgesagt gekennzeichnet.
              Angemeldete Mitglieder sehen, dass er ausfällt.
            </span>
          </div>
        )}
      </Abschnitt>
    </Seite>
  );
}
