import Link from "next/link";
import { notFound } from "next/navigation";
import { listStudioExercises } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { UebungSheet, UebungVerschieben } from "./UebungSheet";
import styles from "../../../halle.module.css";

/**
 * Schritt 5. Die Uebungen haengen am MODELL, nicht am Geraet -- zwei
 * baugleiche Kabelzuege teilen sie sich. Der Bildschirm sagt das, damit
 * niemand sie zweimal anlegt.
 *
 * Der Akzent liegt auf dem Abschliessen, nicht auf dem Hinzufuegen: sonst
 * betont der Bildschirm das Sammeln und nicht das Fertigwerden.
 */
export default async function UebungenPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  const { modell, geraet } = treffer;
  const client = await createServerSupabaseClient();
  const studioUebungen = await listStudioExercises(client, studioId);

  const schonDran = new Set(modell.exercises.map((uebung) => uebung.exerciseId));
  const waehlbar = studioUebungen.filter((uebung) => !schonDran.has(uebung.id));
  const reihenfolge = modell.exercises.map((uebung) => uebung.linkId);

  return (
    <>
      <Schrittleiste nummer={5} titel="Übungen" />
      <div>
        <h1 className={styles.titel}>Übungen</h1>
        <p className={styles.unterzeile}>
          {geraet.label} · {modell.name}
        </p>
      </div>

      {modell.exercises.length > 0 ? (
        <section className={styles.abschnitt}>
          {modell.exercises.map((uebung, index) => (
            <div key={uebung.linkId} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>
                  {index + 1}. {uebung.name}
                </div>
                <div className={styles.zeileMeta}>
                  {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen
                  {uebung.hasVideo
                    ? ` · Video ${uebung.videoDurationS ?? "?"} s`
                    : " · ohne Video"}
                </div>
              </div>
              <UebungVerschieben
                studioId={studioId}
                machineId={machineId}
                modelId={modell.id}
                linkId={uebung.linkId}
                name={uebung.name}
                reihenfolge={reihenfolge}
              />
            </div>
          ))}
        </section>
      ) : (
        <div className={styles.karte}>
          <div className={styles.karteTitel}>Noch keine Übung</div>
          <p className={styles.notiz}>
            Ohne Übung zeigt das Gerät dem Mitglied nichts zum Trainieren. Nimm
            eine aus dem Studio oder leg eine neue an.
          </p>
        </div>
      )}

      <UebungSheet
        studioId={studioId}
        machineId={machineId}
        modelId={modell.id}
        waehlbar={waehlbar}
      />

      <p className={styles.notiz}>
        Die Reihenfolge zählt: Übung 1 ist am Gerät die Vorauswahl. Übungen
        gehören dem Studio, nicht dem Gerät — dieselbe Übung an zwei Modellen
        behält ihren Namen. Das Einweisungsvideo hängt dagegen am Paar aus
        Modell und Übung.
      </p>

      <Link
        href={`/portal/${studioId}/einrichten/geraet/${machineId}/fertig`}
        className={styles.haupt}
      >
        Einrichtung abschließen
      </Link>
    </>
  );
}
