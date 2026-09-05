import Link from "next/link";
import { DomainError, getCourseTemplate, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Zustand } from "../../../../../bausteine/Zustand";
import { VorlageReiter } from "./VorlageReiter";
import styles from "../../../../../portal.module.css";

/**
 * Kopf und Reiterleiste beider Kursvorlagen-Reiter (Kursvorlage.dc.html).
 *
 * Der Fliesstext des Artboards verraet die Reiter nicht, das Markup schon:
 * zwei Stueck, "Stammdaten" und "Termine (16)" mit dem Zusatz "in den
 * naechsten 4 Wochen" unter der Beschriftung. Vorher standen alle drei
 * Abschnitte -- Stammdaten, Foto, Termine -- untereinander auf einer
 * Seite. Das Foto bekommt keinen eigenen Reiter: es gehoert zu den
 * Stammdaten, wie am Modell (geraete/[modelId]).
 *
 * Kein <main> hier (Befund 41) -- das traegt (schreibtisch)/layout.tsx
 * bereits fuer alle Kinder.
 */
export default async function KursvorlageLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string; templateId: string }>;
}) {
  const { studioId, templateId } = await params;
  const client = await createServerSupabaseClient();
  const basis = `/portal/${studioId}/kurse`;

  let vorlage: Awaited<ReturnType<typeof getCourseTemplate>>;
  try {
    vorlage = await getCourseTemplate(client, studioId, templateId);
  } catch (fehler) {
    // Eine geloeschte Vorlage und die eines fremden Studios antworten
    // gleich (courses.ts) -- die Seite darf beide auch gleich
    // beantworten, aber sie muss sagen, was gilt: es gibt einen Weg
    // zurueck. Der Zweig steht seit Aufgabe 22a hier statt in page.tsx,
    // weil der Kopf mit dem Rueckweg jetzt dem Layout gehoert. Ohne
    // {children} bleiben beide Reiter-Seiten ungerendert -- ein
    // Fehlerbild, keine zwei.
    return (
      <>
        <p>
          <Link href={`${basis}/vorlagen`} className={styles.rueckweg}>
            ← Kursvorlagen
          </Link>
        </p>
        <h1 className={styles.pageTitle}>Kursvorlage</h1>
        <Zustand
          art="fehler"
          titel={
            fehler instanceof DomainError
              ? fehler.message
              : "Diese Kursvorlage liess sich nicht laden."
          }
          naechsterSchritt={
            <>
              Vielleicht wurde sie entfernt. Unter <em>Kursvorlagen</em> stehen alle, die
              es noch gibt.
            </>
          }
        />
      </>
    );
  }

  // Die Zahl im Reiter. Der Termine-Reiter selbst liest dieselbe Woche
  // noch einmal -- ein Layout kann seinen Kindern nichts uebergeben, und
  // ein zweiter Aufruf ist billiger als ein Kontext-Client-Rand um eine
  // Zahl (dasselbe Muster wie ladeKatalog in geraete/[modelId]).
  const jetzt = new Date();
  const inVierWochen = new Date(jetzt.getTime() + 28 * 24 * 3_600_000);
  const plan = await listCourseWeek(
    client,
    studioId,
    jetzt.toISOString(),
    inVierWochen.toISOString(),
  );
  const termine = plan.sessions.filter((termin) => termin.templateId === templateId).length;

  const untertitel = [
    vorlage.description,
    `${vorlage.defaultDurationMin} min`,
    `${vorlage.defaultCapacity} Plätze`,
    vorlage.defaultInstructorName === null
      ? null
      : `Standard: ${vorlage.defaultInstructorName}`,
  ]
    .filter((teil): teil is string => teil !== null && teil !== "")
    .join(" · ");

  return (
    <>
      <p>
        <Link href={`${basis}/vorlagen`} className={styles.rueckweg}>
          ← Kursvorlagen
        </Link>
      </p>
      <h1 className={styles.pageTitle}>{vorlage.name}</h1>
      <p className={styles.pageLead}>{untertitel}</p>
      <VorlageReiter studioId={studioId} templateId={templateId} termine={termine} />
      {children}
    </>
  );
}
