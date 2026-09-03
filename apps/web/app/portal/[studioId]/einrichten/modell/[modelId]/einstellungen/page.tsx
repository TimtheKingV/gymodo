import Link from "next/link";
import { notFound } from "next/navigation";
import type { CatalogSettingDefinition } from "@fitretro/domain";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import {
  FotoNachreichen,
  ParameterLoeschen,
  ParameterSheet,
} from "./ParameterSheet";
import styles from "../../../halle.module.css";

/**
 * Schritt 2. Foto und Parameter stehen in einer Karte, weil sie dasselbe
 * teilen: beide haengen am Modell, nicht am Geraet (Entscheidung 9). Der
 * zweite baugleiche Kabelzug laeuft hier mit einem Tap durch.
 *
 * Der Akzent gehoert dem Weiterkommen, nicht dem Hinzufuegen -- sonst betont
 * der Bildschirm das Sammeln und nicht das Fertigwerden.
 */
export default async function EinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const basis = `/portal/${studioId}/einrichten`;

  return (
    <>
      <Schrittleiste nummer={2} titel="Einstellungen" />
      <div>
        <Link href={`${basis}/modell`} className={styles.zurueck}>
          ← Modell
        </Link>
        <h1 className={styles.titel}>Was lässt sich einstellen?</h1>
        <p className={styles.unterzeile}>
          {modell.name}
          {modell.manufacturer ? ` · ${modell.manufacturer}` : ""}
        </p>
      </div>

      <p className={styles.notiz}>
        Zähl die Rasten einmal ab. Beides gilt für alle {modell.name} im Studio
        — das Mitglied wählt daraus später seine eigenen Werte.
      </p>

      <section className={styles.abschnitt}>
        <div className={styles.abschnittKopf}>
          <h2 className={styles.label}>Am Modell</h2>
          <span className={styles.zeileMeta}>
            {modell.settingDefinitions.length} Parameter
          </span>
        </div>

        <div className={styles.zeile}>
          <div style={{ minWidth: 0 }}>
            <div className={styles.zeileHaupt}>
              Foto · {modell.photoPath === null ? "Fehlt" : "Steht"}
            </div>
            <div
              className={
                modell.photoPath === null
                  ? styles.zeileMetaFaint
                  : styles.zeileMeta
              }
            >
              {modell.photoPath === null
                ? "Nach dem Scan sähe ein Mitglied nur den Namen und wüsste nicht, ob es richtig steht."
                : "Bestätigt dem Mitglied in einer Sekunde, dass es am richtigen Gerät steht."}
            </div>
          </div>
          <FotoNachreichen
            studioId={studioId}
            modelId={modelId}
            hatFoto={modell.photoPath !== null}
          />
        </div>

        {modell.settingDefinitions.map((parameter) => (
          <div key={parameter.id} className={styles.zeile}>
            <div style={{ minWidth: 0 }}>
              <div className={styles.zeileHaupt}>{parameter.label}</div>
              <div className={styles.zeileMeta}>{parameterMeta(parameter)}</div>
            </div>
            <ParameterLoeschen
              studioId={studioId}
              modelId={modelId}
              settingId={parameter.id}
            />
          </div>
        ))}

        {modell.settingDefinitions.length === 0 ? (
          <div className={styles.zeile}>
            <div className={styles.zeileMetaFaint}>
              Noch keine Einstellparameter. Das Gerät ist trotzdem vollständig
              nutzbar — das Mitglied hat nur nichts einzustellen.
            </div>
          </div>
        ) : null}
      </section>

      <ParameterSheet studioId={studioId} modelId={modelId} />

      <Link href={`${basis}/modell/${modelId}/geraet`} className={styles.haupt}>
        Weiter zum Gerät
      </Link>

      <p className={styles.notiz}>
        Überspringen geht: ein Gerät ohne Einstellparameter ist vollständig
        nutzbar. Nachtragen lässt es sich jederzeit — nur nicht mehr mit den
        Rasten vor Augen.
      </p>
    </>
  );
}

/**
 * Was ein Parameter dem Trainer sagt. Ausserhalb der Komponente, weil er
 * ueber nichts schliesst -- und weil `typeof modell` in einer Typposition
 * den deklarierten Typ nimmt, nicht den durch notFound() verengten.
 */
function parameterMeta(parameter: CatalogSettingDefinition): string {
  if (parameter.kind === "enum") {
    return `Auswahl · ${(parameter.allowedValues ?? []).join(", ")}`;
  }
  const spanne =
    parameter.minValue !== null && parameter.maxValue !== null
      ? `${parameter.minValue} – ${parameter.maxValue}`
      : "ohne Spanne";
  const schritt =
    parameter.stepValue !== null ? ` · Schritt ${parameter.stepValue}` : "";
  const einheit = parameter.unit ? ` ${parameter.unit}` : "";
  return `Zahl · ${spanne}${schritt}${einheit}`;
}
