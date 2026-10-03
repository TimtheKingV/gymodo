import { notFound } from "next/navigation";
import {
  MEDIA_URL_TTL_SECONDS,
  VIDEO_BUCKET,
  signMediaUrls,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  uebungAendern,
  uebungAnlegen,
  uebungLoesen,
  uebungVerschieben,
} from "../../../../../actions";
import { Hinzufuegen } from "../../../../../bausteine/Hinzufuegen";
import { ladeKatalog } from "../../../../catalog";
import { ReihenfolgeDialog } from "./ReihenfolgeDialog";
import { UebungFormular } from "./UebungFormular";
import { UebungZeile } from "./UebungZeile";
import styles from "../../../../../portal.module.css";
import eigene from "./uebungen.module.css";

/**
 * Reiter "Übungen" -- Abschnitt 3 der frueheren, einteiligen Modellseite.
 * Kein eigenes <h1>, kein <main>, keine <h2>Übungen</h2>: Rueckweg,
 * Titel und Reitername stehen im Layout darueber.
 *
 * Die Reihenfolge ist keine Kosmetik. Canvas-Notiz `note-uebungen`:
 * "Übung 1 ist am Gerät die Vorauswahl des Mitglieds." Platz 1 traegt
 * seine Bedeutung als Abzeichen an der Zeile.
 *
 * Seit der Testnotiz vom 22.09. (#11, #12):
 *
 * - Umordnen geschieht im Dialog "Reihenfolge ändern" ueber der Liste
 *   (ReihenfolgeDialog.tsx, Ziehen am Griff) statt mit Hoch/Runter an
 *   jeder Karte. uebungVerschieben nimmt ohnehin die FERTIGE Reihenfolge
 *   als Liste von linkIds -- der Dialog schickt sie einmal, bei "Fertig".
 * - Jede Zeile traegt rechts oben einen Stift (UebungZeile.tsx) mit der
 *   Zahl dessen, was noch fehlt. Er klappt genau diese Uebung auf: Name,
 *   Wiederholungen, Video, Entfernen.
 * - "Übung anlegen" steht hinter dem Knopf "Übung hinzufügen" ueber der
 *   Liste; bei leerer Liste gleich offen (Hinzufuegen.tsx).
 *
 * Neu seit dem UX-Schnitt (Befund 6 und 7 der Challenge vom 17. September):
 *
 * 1. Jede Zeile zeigt das Einweisungsvideo als Standbild. Vorher stand
 *    dort "Video 34 s" und sonst nichts -- ob darin die richtige Uebung zu
 *    sehen ist, war ohne Herunterladen nicht zu beantworten. Die URLs
 *    dafuer werden hier signiert und nicht in ladeKatalog: nur dieser
 *    Reiter braucht sie, und der Katalog haengt an jeder Portalseite.
 * 2. "Entfernen" traegt seine danger-Farbe erst, wenn es scharf ist
 *    (AktionsKnopf), und steht nur noch im aufgeklappten Teil einer Zeile.
 *
 * Genau eine Akzentflaeche im Ruhezustand: "Übung hinzufügen". Der
 * Fortschrittsbalken in VideoUpload traegt waehrend eines laufenden
 * Uploads ebenfalls var(--accent) -- Befund 11, entschieden in Aufgabe 21.
 */
export default async function ModellUebungenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const client = await createServerSupabaseClient();
  const videoUrls = await signMediaUrls(
    client,
    VIDEO_BUCKET,
    modell.exercises
      .map((uebung) => uebung.videoStoragePath)
      .filter((pfad): pfad is string => Boolean(pfad)),
    MEDIA_URL_TTL_SECONDS,
  );

  const hatUebungen = modell.exercises.length > 0;

  return (
    <>
      <p className={styles.pageLead}>
        Die erste Übung ist am Gerät die Vorauswahl des Mitglieds. Der Stift an
        einer Übung öffnet sie zum Ergänzen — eine Zahl daran heißt, dass noch
        etwas fehlt.
      </p>

      <Hinzufuegen
        knopf="Übung hinzufügen"
        titel="Übung anlegen"
        notiz="Kommt ans Ende der Liste."
        offen={!hatUebungen}
      >
        <UebungFormular
          studioId={studioId}
          modelId={modelId}
          action={uebungAnlegen.bind(null, studioId, modelId)}
        />
      </Hinzufuegen>

      {modell.exercises.length > 1 ? (
        <div className={eigene.leiste}>
          <ReihenfolgeDialog
            uebungen={modell.exercises.map(({ linkId, name }) => ({ linkId, name }))}
            speichern={uebungVerschieben.bind(null, studioId, modelId)}
          />
        </div>
      ) : null}

      <section className={styles.section}>
        {!hatUebungen ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Übung.</p>
            <p className={styles.emptyNext}>
              Ohne Übung zeigt der Geräte-Screen nur den Namen. Eine reicht zum
              Anfangen.
            </p>
          </div>
        ) : (
          // Benannt, weil auf diesem Bildschirm mehrere Listen stehen --
          // das Band "Noch zu tun" darueber ist auch eine. "Liste mit 3
          // Eintraegen" ist ohne Namen keine Auskunft.
          <ul className={styles.rows} aria-label="Übungen am Modell">
            {modell.exercises.map((uebung, index) => (
              <UebungZeile
                key={uebung.linkId}
                studioId={studioId}
                modelId={modelId}
                uebung={uebung}
                nummer={index + 1}
                videoUrl={
                  uebung.videoStoragePath ? videoUrls.get(uebung.videoStoragePath) : undefined
                }
                aendern={uebungAendern.bind(null, studioId, modelId, uebung.exerciseId)}
                loesen={uebungLoesen.bind(null, studioId, modelId, uebung.linkId)}
              />
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
