import Link from "next/link";
import { listCourseTemplates, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../../../Form";
import { vorlageAnlegenAction } from "../../../kurse-actions";
import { Abschnitt } from "../../../../bausteine/Abschnitt";
import { Seite } from "../../../../bausteine/Seite";
import { Zeile, Zeilen } from "../../../../bausteine/Zeile";
import { Zustand } from "../../../../bausteine/Zustand";
import styles from "../../../../portal.module.css";

/**
 * Die Vorlagenliste (Kursvorlagen.dc.html).
 *
 * Kein eigenes <main> mehr (Befund 41) -- die Landmarke traegt
 * (schreibtisch)/layout.tsx.
 *
 * Eine Akzentflaeche: der Absendeknopf "Vorlage anlegen". Das Artboard
 * setzt dieselbe Flaeche als Link in den Kopf des Abschnitts "Alle
 * Vorlagen" und meint damit einen eigenen Anlegen-Bildschirm; den gibt es
 * nicht, und er waere eine neue Route samt Aktion, nicht Gestaltung.
 * Gezaehlt bleibt es eine Flaeche.
 */

/** "16 Termine in den naechsten 4 Wochen", so wie das Artboard es sagt. */
function termineText(anzahl: number): string {
  if (anzahl === 0) return "keine Termine in den nächsten 4 Wochen";
  if (anzahl === 1) return "1 Termin in den nächsten 4 Wochen";
  return `${anzahl} Termine in den nächsten 4 Wochen`;
}

export default async function KursvorlagenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;

  // Die Termine der naechsten vier Wochen, wie im Artboard -- eine
  // Wochenabfrage ueber das ganze Fenster, danach je Vorlage gezaehlt.
  // course_week ist der einzige Lesepfad auf Termine (courses.ts); eine
  // zweite Abfrage je Zeile waere N+1.
  const jetzt = new Date();
  const inVierWochen = new Date(jetzt.getTime() + 28 * 24 * 3_600_000);
  const [vorlagen, plan] = await Promise.all([
    listCourseTemplates(client, studioId),
    listCourseWeek(client, studioId, jetzt.toISOString(), inVierWochen.toISOString()),
  ]);

  const termineJeVorlage = new Map<string, number>();
  for (const termin of plan.sessions) {
    termineJeVorlage.set(termin.templateId, (termineJeVorlage.get(termin.templateId) ?? 0) + 1);
  }

  return (
    <>
      <p>
        <Link href={basis} className={styles.rueckweg}>
          ← Kurse
        </Link>
      </p>
      <Seite
        titel="Kursvorlagen"
        vorspann="Eine Vorlage beschreibt den Kurs. Die einzelnen Termine im Kalender entstehen daraus — und behalten ihre Werte, auch wenn du die Vorlage später änderst."
      >
        <Abschnitt titel="Alle Vorlagen">
          {vorlagen.length === 0 ? (
            <Zustand
              art="leer"
              titel="Noch keine Vorlage angelegt."
              naechsterSchritt="Leg unten die erste an — danach kannst du Termine dafür in den Kalender stellen."
            />
          ) : (
            <Zeilen>
              {vorlagen.map((vorlage) => (
                <Zeile
                  key={vorlage.id}
                  titel={vorlage.name}
                  meta={
                    <>
                      {vorlage.defaultDurationMin} min · {vorlage.defaultCapacity} Plätze
                      {vorlage.defaultInstructorName === null
                        ? ""
                        : ` · Standard: ${vorlage.defaultInstructorName}`}
                      {` · ${termineText(termineJeVorlage.get(vorlage.id) ?? 0)}`}
                    </>
                  }
                  aktionen={
                    <Link
                      className={styles.secondary}
                      href={`${basis}/vorlagen/${vorlage.id}`}
                    >
                      Öffnen
                    </Link>
                  }
                />
              ))}
            </Zeilen>
          )}
        </Abschnitt>

        {/*
          Bewusst kein Abschnitt-Baustein: AktionsFormular bringt sein
          eigenes styles.sectionBody-Polster mit, das zusammen mit
          Abschnitts abschnittRumpf doppelt aufgetragen wuerde -- dieselbe
          Begruendung wie in geraete/page.tsx.
        */}
        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <h2 className={styles.sectionTitle}>Vorlage anlegen</h2>
          </div>
          <AktionsFormular
            action={vorlageAnlegenAction.bind(null, studioId)}
            submitLabel="Vorlage anlegen"
          >
            <Feld name="name" label="Name" required />
            <Feld name="beschreibung" label="Beschreibung" />
            <div className={styles.grid}>
              <Feld
                name="dauer"
                label="Dauer in Minuten"
                type="number"
                defaultValue="60"
                required
              />
              <Feld name="plaetze" label="Plätze" type="number" defaultValue="16" required />
            </div>
            <Feld name="trainerName" label="Standard-Trainer (Anzeigename)" />
          </AktionsFormular>
        </section>
      </Seite>
    </>
  );
}
