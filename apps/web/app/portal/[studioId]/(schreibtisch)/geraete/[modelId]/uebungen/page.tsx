import { notFound } from "next/navigation";
import { AktionsKnopf } from "../../../../../Form";
import { VideoUpload } from "../../../../../VideoUpload";
import { uebungAnlegen, uebungLoesen, uebungVerschieben } from "../../../../../actions";
import { ladeKatalog } from "../../../../catalog";
import { UebungFormular } from "./UebungFormular";
import styles from "../../../../../portal.module.css";

/**
 * Reiter "Übungen" -- Abschnitt 3 der frueheren, einteiligen Modellseite.
 * Kein eigenes <h1>, kein <main>, keine <h2>Übungen</h2>: Rueckweg,
 * Titel und Reitername stehen im Layout darueber.
 *
 * Die Reihenfolge ist keine Kosmetik. Canvas-Notiz `note-uebungen`:
 * "Übung 1 ist am Gerät die Vorauswahl des Mitglieds." Der Umordnen-Weg
 * bleibt deshalb vollstaendig -- Hoch, Runter, Entfernen -- und jede Zeile
 * traegt ihre Nummer sichtbar, weil genau die Nummer die Vorauswahl ist.
 *
 * uebungVerschieben nimmt die FERTIGE Reihenfolge als Liste von linkIds
 * entgegen, nicht "dieses Element eins hoch". Jede Zeile rechnet ihre
 * beiden Ziel-Reihenfolgen deshalb hier aus; am Rand (erste Zeile "Hoch",
 * letzte "Runter") bleibt die Liste unveraendert und der Druck folgenlos.
 *
 * Genau eine Akzentflaeche: "Übung anlegen". Hoch und Runter sind
 * Nebenaktionen, Entfernen ist zerstoerend. Der Fortschrittsbalken in
 * VideoUpload traegt waehrend eines laufenden Uploads ebenfalls
 * var(--accent) -- Befund 11, entschieden in Aufgabe 21, nicht hier; im
 * Ruhezustand rendert er nicht.
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

  const reihenfolge = modell.exercises.map((eintrag) => eintrag.linkId);

  return (
    <>
      <p className={styles.pageLead}>
        Die Reihenfolge bestimmt, was am Gerät zuerst vorgeschlagen wird —
        "Hoch" schiebt eine Übung nach vorn, "Runter" nach hinten.
      </p>

      <section className={styles.section}>
        {modell.exercises.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Übung.</p>
            <p className={styles.emptyNext}>
              Ohne Übung zeigt der Geräte-Screen nur den Namen. Eine reicht zum
              Anfangen.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.exercises.map((uebung, index) => {
              const hoch = [...reihenfolge];
              if (index > 0) {
                [hoch[index - 1], hoch[index]] = [hoch[index]!, hoch[index - 1]!];
              }
              const runter = [...reihenfolge];
              if (index < reihenfolge.length - 1) {
                [runter[index], runter[index + 1]] = [runter[index + 1]!, runter[index]!];
              }

              return (
                <li key={uebung.linkId} className={styles.row}>
                  <div className={styles.rowMain}>
                    <div className={styles.rowTitle}>
                      {index + 1}. {uebung.name}
                    </div>
                    <div className={styles.rowMeta}>
                      {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen ·{" "}
                      {uebung.hasVideo ? (
                        `Video ${uebung.videoDurationS} s`
                      ) : (
                        <span className={styles.absent}>ohne Video</span>
                      )}
                    </div>
                    <VideoUpload
                      studioId={studioId}
                      modelId={modelId}
                      linkId={uebung.linkId}
                      hatVideo={uebung.hasVideo}
                    />
                  </div>
                  <div className={styles.rowActions}>
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, hoch)}
                      label="Hoch"
                    />
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, runter)}
                      label="Runter"
                    />
                    <AktionsKnopf
                      aktion={uebungLoesen.bind(null, studioId, modelId, uebung.linkId)}
                      label="Entfernen"
                      bestaetigung="Wirklich entfernen?"
                      art="destructive"
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        <UebungFormular
          studioId={studioId}
          modelId={modelId}
          action={uebungAnlegen.bind(null, studioId, modelId)}
        />
      </section>
    </>
  );
}
