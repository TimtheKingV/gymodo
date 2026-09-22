import { notFound } from "next/navigation";
import { formatVolumeRange } from "@fitretro/domain/belastung";
import {
  MEDIA_URL_TTL_SECONDS,
  VIDEO_BUCKET,
  signMediaUrls,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
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
 * bleibt deshalb vollstaendig -- Hoch, Runter, Entfernen -- und Platz 1
 * traegt seine Bedeutung jetzt als Abzeichen an der Zeile statt nur als
 * Satz im Vorspann darueber.
 *
 * uebungVerschieben nimmt die FERTIGE Reihenfolge als Liste von linkIds
 * entgegen, nicht "dieses Element eins hoch". Jede Zeile rechnet ihre
 * beiden Ziel-Reihenfolgen deshalb hier aus; am Rand ist der Knopf
 * abgeschaltet statt folgenlos -- ein Druck, der eine Server-Aktion
 * ausloest, die Liste laedt und nichts aendert, ist schlechter als einer,
 * der gar nicht erst geht.
 *
 * Neu seit dem UX-Schnitt (Befund 6 und 7 der Challenge vom 17. September):
 *
 * 1. Jede Zeile zeigt das Einweisungsvideo als Standbild. Vorher stand
 *    dort "Video 34 s" und sonst nichts -- ob darin die richtige Uebung zu
 *    sehen ist, war ohne Herunterladen nicht zu beantworten. Die URLs
 *    dafuer werden hier signiert und nicht in ladeKatalog: nur dieser
 *    Reiter braucht sie, und der Katalog haengt an jeder Portalseite.
 * 2. "Entfernen" traegt seine danger-Farbe erst, wenn es scharf ist
 *    (AktionsKnopf). Bei sechs Uebungen standen vorher sechs rote Umrisse
 *    gleichmaessig verteilt in der Karte -- die auffaelligste Farbe des
 *    Bildschirms gehoerte dem Loeschen, nicht der Hauptaktion.
 *
 * Genau eine Akzentflaeche: "Übung anlegen" in der Karte darunter. Der
 * Fortschrittsbalken in VideoUpload traegt waehrend eines laufenden
 * Uploads ebenfalls var(--accent) -- Befund 11, entschieden in Aufgabe 21,
 * nicht hier; im Ruhezustand rendert er nicht.
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

  const reihenfolge = modell.exercises.map((eintrag) => eintrag.linkId);

  return (
    <>
      <p className={styles.pageLead}>
        Die erste Übung ist am Gerät die Vorauswahl des Mitglieds — &bdquo;Hoch&ldquo;
        schiebt eine Übung nach vorn, &bdquo;Runter&ldquo; nach hinten.
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
          // Benannt, weil auf diesem Bildschirm mehrere Listen stehen --
          // das Band "Noch zu tun" darueber ist auch eine. "Liste mit 3
          // Eintraegen" ist ohne Namen keine Auskunft.
          <ul className={styles.rows} aria-label="Übungen am Modell">
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
                  <div className={styles.zeileMitBild}>
                    <VideoUpload
                      studioId={studioId}
                      modelId={modelId}
                      linkId={uebung.linkId}
                      hatVideo={uebung.hasVideo}
                      videoUrl={
                        uebung.videoStoragePath
                          ? videoUrls.get(uebung.videoStoragePath)
                          : undefined
                      }
                      knapp
                    />
                    <div className={styles.rowMain}>
                      <div className={styles.rowTitle}>
                        {index + 1}. {uebung.name}
                      </div>
                      <div className={styles.rowMeta}>
                        {formatVolumeRange(uebung.targetMin, uebung.targetMax, uebung.volumeKind)} ·{" "}
                        {uebung.hasVideo ? (
                          `Video ${uebung.videoDurationS} s`
                        ) : (
                          <span className={styles.absent}>ohne Video</span>
                        )}
                      </div>
                      {index === 0 ? (
                        <div className={styles.rowMarke}>
                          <span className={styles.badge}>Vorauswahl am Gerät</span>
                        </div>
                      ) : null}
                    </div>
                  </div>
                  <div className={styles.rowActions}>
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, hoch)}
                      label="Hoch"
                      deaktiviert={index === 0}
                    />
                    <AktionsKnopf
                      aktion={uebungVerschieben.bind(null, studioId, modelId, runter)}
                      label="Runter"
                      deaktiviert={index === reihenfolge.length - 1}
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
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Übung anlegen</h2>
          <span className={styles.sectionNote}>
            Kommt ans Ende der Liste. Die Reihenfolge änderst du oben.
          </span>
        </div>
        <UebungFormular
          studioId={studioId}
          modelId={modelId}
          action={uebungAnlegen.bind(null, studioId, modelId)}
        />
      </section>
    </>
  );
}
