import { exemplarAnlegen, modellAnlegen } from "../../../../actions";
import { ladeKatalog, railZahlen } from "../../../catalog";
import { Seite } from "../../../../bausteine/Seite";
import { Schrittleiste } from "../../../../bausteine/Schrittleiste";
import { Zustand } from "../../../../bausteine/Zustand";
import { ExemplarFormular } from "../ExemplarFormular";
import { ModellAnlegenFormular } from "../ModellAnlegenFormular";
import { ASSISTENT_SCHRITTE, neuAnsicht } from "../assistent";
import styles from "../../../../portal.module.css";

/**
 * Schritt 1 des Ablaufs "Gerät hinzufügen" (Testnotiz 23.09., #7): nur die
 * Stammdaten, keine Geraeteliste darunter. "Weiter" legt das Modell an und
 * fuehrt in Schritt 2 (Einstellungen) desselben Modells -- ab dort traegt
 * das Modell-Layout die Schrittleiste (ModellRahmen.tsx).
 *
 * Davor seit der Testnotiz 25.09. (#7) eine Frage: neuer Geraetetyp oder
 * ein weiteres Geraet eines vorhandenen? Das zweite braucht nur Nummer und
 * Standort -- alles andere haengt am Modell und gilt fuer jedes Geraet
 * dieses Typs (ExemplarFormular.tsx). Die Wahl steht in der Adresse
 * (?art=typ / ?art=exemplar), und die Links sind <a>, kein <Link>: ein
 * Wechsel nur des Suchparameters laeuft mit Nexts Client-Router im
 * Produktionsbau ins Leere (ausfuehrlich in kurse/page.tsx).
 *
 * Eine statische Route neben [modelId]: Next nimmt "neu" vor dem
 * dynamischen Segment, eine Modell-Id kann nie "neu" heissen (UUID).
 */
export default async function GeraetNeuPage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string }>;
  searchParams: Promise<{ art?: string }>;
}) {
  const { studioId } = await params;
  const { art } = await searchParams;
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

  const katalog = await ladeKatalog(studioId);
  const ansicht = neuAnsicht(art, katalog.models.length);
  const basis = `/portal/${studioId}/geraete/neu`;
  // Immer zur Geraeteliste, auch aus ?art=... heraus: zurueck zur Frage
  // hiesse nur den Suchparameter wechseln, und genau das schluckt <Link>
  // (siehe oben). Wer anders waehlen will, waehlt dort neu.
  const rueckweg = { href: `/portal/${studioId}/geraete`, label: "Geräte" };

  if (ansicht === "frage") {
    return (
      <Seite
        titel="Gerät hinzufügen"
        vorspann="Hast du dieses Gerät schon einmal angelegt?"
        rueckweg={rueckweg}
      >
        <ul className={styles.wahlListe}>
          <li>
            <a className={styles.wahl} href={`${basis}?art=exemplar`}>
              <span className={styles.wahlTitel}>Ja, ein weiteres Gerät dieses Typs</span>
              <span className={styles.wahlText}>
                Typ aus der Liste wählen und nur die Nummer eintragen. Einstellungen,
                Übungen und Videos übernimmt es vom vorhandenen Gerät.
              </span>
            </a>
          </li>
          <li>
            <a className={styles.wahl} href={`${basis}?art=typ`}>
              <span className={styles.wahlTitel}>Nein, ein neuer Gerätetyp</span>
              <span className={styles.wahlText}>
                Stammdaten, Einstellungen, Übungen und die einzelnen Geräte, Schritt für
                Schritt.
              </span>
            </a>
          </li>
        </ul>
      </Seite>
    );
  }

  if (ansicht === "exemplar") {
    return (
      <Seite
        titel="Weiteres Gerät"
        vorspann="Alles außer Nummer und Standort gilt für jedes Gerät dieses Typs."
        rueckweg={rueckweg}
      >
        <section className={styles.section}>
          <ExemplarFormular
            action={exemplarAnlegen.bind(null, studioId)}
            typen={katalog.models.map((modell) => ({
              id: modell.id,
              name: modell.name,
              geraete: modell.machines.map((geraet) => geraet.label),
            }))}
          />
        </section>
      </Seite>
    );
  }

  return (
    <Seite
      titel="Gerät hinzufügen"
      vorspann="Erst der Gerätetyp, danach Einstellungen, Übungen und die einzelnen Geräte im Raum."
      rueckweg={rueckweg}
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
