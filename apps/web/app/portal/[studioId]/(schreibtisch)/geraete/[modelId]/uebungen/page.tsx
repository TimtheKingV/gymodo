import { notFound } from "next/navigation";
import {
  MEDIA_URL_TTL_SECONDS,
  VIDEO_BUCKET,
  signMediaUrls,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  gymtavoUebungLoesen,
  gymtavoUebungVerknuepfen,
  uebungAendern,
  uebungAnlegen,
  uebungLoesen,
  uebungVerschieben,
} from "../../../../../actions";
import { Abschnitt } from "../../../../../bausteine/Abschnitt";
import { Hinzufuegen } from "../../../../../bausteine/Hinzufuegen";
import { ladeKatalog, ladeTypen } from "../../../../catalog";
import { anhaengbareUebungen, eigeneUebungen, gymtavoZeilen } from "./gymtavo";
import { GymtavoAnhaengen } from "./GymtavoAnhaengen";
import { GymtavoZeile } from "./GymtavoZeile";
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
 * Seit Etappe 5 (Nachtrag 10.1) zwei Teile: oben die Gymtavo-Uebungen des
 * zugeordneten Typs und angehaengte anderer Typen, schreibgeschuetzt mit
 * eigenem Video; darunter die eigenen wie bisher. Der Reihenfolge-Dialog
 * ordnet nur die eigenen -- die App zeigt Gymtavo-Uebungen ohnehin danach.
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

  // Im Gymtavo-Studio ist jede Uebung eine eigene; es gibt keinen Typ ueber
  // dem Typ.
  const typen = katalog.isCatalog ? [] : await ladeTypen();
  const eigen = katalog.isCatalog ? modell.exercises : eigeneUebungen(modell.exercises);
  const gymtavo = katalog.isCatalog ? [] : gymtavoZeilen(modell, typen);
  const angebot = anhaengbareUebungen(modell, typen);

  const client = await createServerSupabaseClient();
  const videoUrls = await signMediaUrls(
    client,
    VIDEO_BUCKET,
    [
      ...eigen.map((uebung) => uebung.videoStoragePath),
      ...gymtavo.flatMap((zeile) => [
        zeile.eigenesVideo?.storagePath,
        zeile.katalogVideo?.storagePath,
      ]),
    ].filter((pfad): pfad is string => Boolean(pfad)),
    MEDIA_URL_TTL_SECONDS,
  );

  const hatUebungen = eigen.length > 0;

  return (
    <>
      <p className={styles.pageLead}>
        Die erste Übung ist am Gerät die Vorauswahl des Mitglieds. Der Stift an
        einer Übung öffnet sie zum Ergänzen — eine Zahl daran heißt, dass noch
        etwas fehlt.
      </p>

      {typen.length > 0 || gymtavo.length > 0 ? (
        <Abschnitt
          titel="Gymtavo-Übungen"
          notiz={
            modell.catalogModelId === null
              ? "Ohne Gymtavo-Typ stehen hier nur angehängte Übungen."
              : "Kommen mit dem Gymtavo-Typ. Name und Wiederholungen pflegt Gymtavo."
          }
        >
          <Hinzufuegen neben knopf="Gymtavo-Übung anhängen" titel="Gymtavo-Übung anhängen">
            <GymtavoAnhaengen
              angebot={angebot}
              anhaengen={gymtavoUebungVerknuepfen.bind(null, studioId, modelId)}
            />
          </Hinzufuegen>
          {gymtavo.length > 0 ? (
            <ul className={styles.rows} aria-label="Gymtavo-Übungen am Modell">
              {gymtavo.map((zeile) => (
                <GymtavoZeile
                  key={zeile.exerciseId}
                  studioId={studioId}
                  modelId={modelId}
                  zeile={zeile}
                  eigeneVideoUrl={
                    zeile.eigenesVideo ? videoUrls.get(zeile.eigenesVideo.storagePath) : undefined
                  }
                  katalogVideoUrl={
                    zeile.katalogVideo ? videoUrls.get(zeile.katalogVideo.storagePath) : undefined
                  }
                  verknuepfen={gymtavoUebungVerknuepfen.bind(
                    null,
                    studioId,
                    modelId,
                    zeile.exerciseId,
                  )}
                  loesen={
                    zeile.herkunft === "angehaengt" && zeile.linkId
                      ? gymtavoUebungLoesen.bind(null, studioId, modelId, zeile.linkId)
                      : null
                  }
                />
              ))}
            </ul>
          ) : null}
        </Abschnitt>
      ) : null}

      <Abschnitt titel="Eigene Übungen">
        <Hinzufuegen
          knopf="Übung hinzufügen"
          titel="Übung anlegen"
          notiz="Kommt ans Ende der Liste."
          offen={!hatUebungen && gymtavo.length === 0}
        >
          <UebungFormular
            studioId={studioId}
            modelId={modelId}
            action={uebungAnlegen.bind(null, studioId, modelId)}
          />
        </Hinzufuegen>

        {eigen.length > 1 ? (
          <div className={eigene.leiste}>
            <ReihenfolgeDialog
              uebungen={eigen.map(({ linkId, name }) => ({ linkId, name }))}
              speichern={uebungVerschieben.bind(null, studioId, modelId)}
            />
          </div>
        ) : null}

        <section className={styles.section}>
          {!hatUebungen ? (
            <div className={styles.empty}>
              <p className={styles.emptyTitle}>Noch keine Übung.</p>
              <p className={styles.emptyNext}>
                {gymtavo.length > 0
                  ? "Die Gymtavo-Übungen oben reichen zum Anfangen."
                  : "Ohne Übung zeigt der Geräte-Screen nur den Namen. Eine reicht zum Anfangen."}
              </p>
            </div>
          ) : (
            // Benannt, weil auf diesem Bildschirm mehrere Listen stehen --
            // das Band "Noch zu tun" darueber ist auch eine. "Liste mit 3
            // Eintraegen" ist ohne Namen keine Auskunft.
            <ul className={styles.rows} aria-label="Übungen am Modell">
              {eigen.map((uebung, index) => (
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
      </Abschnitt>
    </>
  );
}
