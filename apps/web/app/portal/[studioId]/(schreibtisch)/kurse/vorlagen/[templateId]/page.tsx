import { DomainError, getCourseTemplate } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../../../../Form";
import { vorlageSpeichernAction } from "../../../../kurse-actions";
import { Abschnitt } from "../../../../../bausteine/Abschnitt";
import { Zustand } from "../../../../../bausteine/Zustand";
import styles from "../../../../../portal.module.css";

/**
 * Der Reiter "Stammdaten" einer Kursvorlage (Kursvorlage.dc.html).
 *
 * Er traegt Stammdaten UND Foto -- wie am Modell, wo das Foto zu den
 * Stammdaten gehoert und keinen eigenen Reiter bekommt. Rueckweg, Titel,
 * Untertitel und die Reiterleiste stehen im layout.tsx daneben; kein
 * <main> mehr (Befund 41).
 *
 * Eine Akzentflaeche: "Änderungen speichern".
 *
 * Der Foto-Abschnitt bekommt KEINEN Knopf. Gesamtfahrplan Abschnitt 6:
 * photo_path steht (0035), der Uploadweg nicht -- ein dritter Bucket
 * braeuchte vier Storage-Policies mit voller Testmatrix, und bis dahin
 * "zeigt die Oberflaeche den Zustand ohne Knopf". Das Artboard zeichnet
 * "Foto auswählen" samt Formathinweis; beides bleibt ungebaut. Deaktiviert
 * ist trotzdem nicht stumm (Portalspec Abschnitt 5): daneben steht, was
 * fehlt.
 */
export default async function KursvorlageStammdatenPage({
  params,
}: {
  params: Promise<{ studioId: string; templateId: string }>;
}) {
  const { studioId, templateId } = await params;
  const client = await createServerSupabaseClient();

  let vorlage: Awaited<ReturnType<typeof getCourseTemplate>>;
  try {
    vorlage = await getCourseTemplate(client, studioId, templateId);
  } catch (fehler) {
    // Das Layout darueber liest dieselbe Vorlage und faengt denselben
    // Fehler; es rendert diese Kinder dann gar nicht erst. Der Zweig
    // bleibt als Rueckfallebene stehen -- ohne ihn liefe ein Fehler, den
    // nur dieser Aufruf sieht, in die error.tsx des Schreibtischs und
    // riesse den Kopf mit.
    return (
      <Zustand
        art="fehler"
        titel={
          fehler instanceof DomainError
            ? fehler.message
            : "Diese Kursvorlage liess sich nicht laden."
        }
      />
    );
  }

  return (
    <>
      {/*
        Bewusst kein Abschnitt-Baustein: AktionsFormular bringt sein
        eigenes styles.sectionBody-Polster mit, das zusammen mit
        Abschnitts abschnittRumpf doppelt aufgetragen wuerde -- dieselbe
        Begruendung wie in geraete/page.tsx.
      */}
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Stammdaten</h2>
        </div>
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
          <div className={styles.grid}>
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
          </div>
          <Feld
            name="trainerName"
            label="Standard-Trainer (Anzeigename)"
            defaultValue={vorlage.defaultInstructorName ?? ""}
          />
        </AktionsFormular>
      </section>

      <Abschnitt titel="Foto">
        <div className={styles.mediaRow}>
          <div className={styles.photoEmpty}>Noch kein Foto</div>
          <p className={styles.sectionNote}>
            Kursfotos kommen später — dafür fehlt noch der Ablageort. Die Kursbeschreibung
            trägt bis dahin allein.
          </p>
        </div>
      </Abschnitt>
    </>
  );
}
