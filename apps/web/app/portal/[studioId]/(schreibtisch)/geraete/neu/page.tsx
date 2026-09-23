import { modellAnlegen } from "../../../../actions";
import { railZahlen } from "../../../catalog";
import { Seite } from "../../../../bausteine/Seite";
import { Schrittleiste } from "../../../../bausteine/Schrittleiste";
import { Zustand } from "../../../../bausteine/Zustand";
import { ModellAnlegenFormular } from "../ModellAnlegenFormular";
import { ASSISTENT_SCHRITTE } from "../assistent";
import styles from "../../../../portal.module.css";

/**
 * Schritt 1 des Ablaufs "Gerät hinzufügen" (Testnotiz 23.09., #7): nur die
 * Stammdaten, keine Geraeteliste darunter. "Weiter" legt das Modell an und
 * fuehrt in Schritt 2 (Einstellungen) desselben Modells -- ab dort traegt
 * das Modell-Layout die Schrittleiste (ModellRahmen.tsx).
 *
 * Eine statische Route neben [modelId]: Next nimmt "neu" vor dem
 * dynamischen Segment, eine Modell-Id kann nie "neu" heissen (UUID).
 */
export default async function GeraetNeuPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const zahlen = await railZahlen(studioId);

  // Dieselbe Sperre wie auf der Geraeteliste (geraete/page.tsx, dort
  // ausfuehrlich begruendet): Mitglieder sehen den Katalog auf
  // Datenbankebene, die Seite ist die Sperre.
  if (zahlen.mitglieder === null) {
    return (
      <Seite titel="Gerät hinzufügen">
        <Zustand
          art="keinRecht"
          titel="Die Geräteliste ist Trainern und Inhabern vorbehalten."
        />
      </Seite>
    );
  }

  return (
    <Seite
      titel="Gerät hinzufügen"
      vorspann="Erst der Gerätetyp, danach Einstellungen, Übungen und die einzelnen Geräte im Raum."
      rueckweg={{ href: `/portal/${studioId}/geraete`, label: "Geräte" }}
    >
      <div className={styles.ablaufLeiste}>
        <Schrittleiste nummer={1} titel="Stammdaten" von={ASSISTENT_SCHRITTE} />
      </div>
      <section className={styles.section}>
        <ModellAnlegenFormular action={modellAnlegen.bind(null, studioId)} />
      </section>
    </Seite>
  );
}
