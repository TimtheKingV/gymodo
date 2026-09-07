import { notFound } from "next/navigation";
import { AktionsKnopf } from "../../../../../Form";
import { ParameterFormular } from "../../../../../ParameterFormular";
import { parameterAnlegen, parameterLoeschen } from "../../../../../actions";
import { ladeKatalog } from "../../../../catalog";
import styles from "../../../../../portal.module.css";

/**
 * Reiter "Einstellungen" -- Abschnitt 2 der frueheren, einteiligen
 * Modellseite (371 Zeilen). Kein eigenes <h1> und kein <main>: beides
 * traegt das Layout darueber. Auch keine <h2>Einstellparameter</h2> mehr
 * -- der Reiter heisst schon so, und eine Ueberschrift, die den Reiternamen
 * wiederholt, sagt nichts Zweites.
 *
 * Der erklaerende Satz bleibt und rueckt unter die Reiterleiste. Er steht
 * in .pageLead (--text-muted), nicht in .sectionNote (--text-faint):
 * ohne die fruehere Abschnittsueberschrift ist er der einzige Text, der
 * sagt, wofuer dieser Reiter da ist -- Pflichttext also, und
 * Designsystem 2 verbietet dafuer 3,6 : 1 (Befund 19).
 *
 * Genau eine Akzentflaeche: "Parameter anlegen" im ParameterFormular.
 * Loeschen ist zerstoerend (.destructive), nicht Akzent.
 */
export default async function ModellEinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  return (
    <>
      <p className={styles.pageLead}>
        Was ein Mitglied am Gerät einstellt und sich merken soll.
      </p>

      <section className={styles.section}>
        {modell.settingDefinitions.length === 0 ? (
          <div className={styles.empty}>
            {/* Der Wortlaut folgt der Halle und TelefonZustaende.dc.html:
                Plural. Der Schreibtisch war hier der Ausreisser. */}
            <p className={styles.emptyTitle}>Noch keine Einstellparameter.</p>
            <p className={styles.emptyNext}>
              Trag ein, was am Gerät verstellt wird — Sitz, Lehne, Startwinkel.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.settingDefinitions.map((parameter) => (
              <li key={parameter.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{parameter.label}</div>
                  <div className={styles.rowMeta}>
                    <code>{parameter.key}</code> ·{" "}
                    {parameter.kind === "enum"
                      ? (parameter.allowedValues ?? []).join(" · ")
                      : `${parameter.minValue ?? "?"} bis ${parameter.maxValue ?? "?"}${
                          parameter.stepValue ? ` in Schritten von ${parameter.stepValue}` : ""
                        }${parameter.unit ? ` ${parameter.unit}` : ""}`}
                  </div>
                </div>
                <AktionsKnopf
                  aktion={parameterLoeschen.bind(null, studioId, modelId, parameter.id)}
                  label="Löschen"
                  bestaetigung="Wirklich löschen?"
                  art="destructive"
                />
              </li>
            ))}
          </ul>
        )}

        <ParameterFormular
          action={parameterAnlegen.bind(null, studioId, modelId)}
          modell={modell}
        />
      </section>
    </>
  );
}
