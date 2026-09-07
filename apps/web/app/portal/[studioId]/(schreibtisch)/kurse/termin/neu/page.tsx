import Link from "next/link";
import { listCourseTemplates } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { terminAnlegenAction } from "../../../../kurse-actions";
import { Seite } from "../../../../../bausteine/Seite";
import { Zustand } from "../../../../../bausteine/Zustand";
import styles from "../../../../../portal.module.css";
import { TerminAnlegenFormular } from "./SerienVorschau";

/**
 * "Termin anlegen" (TerminAnlegen.dc.html).
 *
 * Kein eigenes <main> mehr, in KEINEM der beiden Zweige (Befund 41): die
 * Landmarke traegt (schreibtisch)/layout.tsx fuer alle Kinder. Diese
 * Datei entstand in Phase 4 auf einem eigenen Zweig gegen den Stand von
 * vor Aufgabe 4 und brachte ihre eigene mit -- zwei Hauptbereiche je
 * Route, und die .content-Polsterung lag doppelt.
 *
 * Seite.tsx traegt jetzt einen optionalen Rueckweg (rueckweg-Prop) -- der
 * Grund, warum dieser Bildschirm bisher keinen Seite-Baustein nutzte, ist
 * damit weg.
 *
 * Das Formular selbst steht in SerienVorschau.tsx -- der Absendeknopf
 * traegt die Zahl der Serie, und die entsteht im Browser. Begruendung
 * dort.
 */
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
      <Seite titel="Termin anlegen" rueckweg={{ href: basis, label: "Kurse" }}>
        <Zustand
          art="leer"
          titel="Es gibt noch keine Kursvorlage."
          naechsterSchritt="Ein Termin entsteht aus einer Vorlage."
          aktion={
            <Link className={styles.secondary} href={`${basis}/vorlagen`}>
              Vorlage anlegen
            </Link>
          }
        />
      </Seite>
    );
  }

  const standard = vorlagen.find((v) => v.id === vorgewaehlt) ?? vorlagen[0]!;

  return (
    <Seite titel="Termin anlegen" rueckweg={{ href: basis, label: "Kurse" }}>
      <TerminAnlegenFormular
        aktion={terminAnlegenAction.bind(null, studioId)}
        zeitzone={zeitzone}
        vorlagen={vorlagen.map((vorlage) => ({
          id: vorlage.id,
          name: vorlage.name,
        }))}
        vorgewaehlt={standard.id}
        dauer={standard.defaultDurationMin}
        plaetze={standard.defaultCapacity}
        trainerName={standard.defaultInstructorName ?? ""}
      />
    </Seite>
  );
}
