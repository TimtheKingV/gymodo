import { notFound } from "next/navigation";
import { AktionsKnopf } from "../../../../../Form";
import { EinstellungFormular } from "../../../../../EinstellungFormular";
import { parameterAnlegen, parameterLoeschen } from "../../../../../actions";
import { ladeKatalog } from "../../../../catalog";
import { Hinzufuegen } from "../../../../../bausteine/Hinzufuegen";
import { rastenText } from "../../../../rasten";
import styles from "../../../../../portal.module.css";

/**
 * Reiter "Einstellungen" -- Abschnitt 2 der frueheren, einteiligen
 * Modellseite (371 Zeilen). Kein eigenes <h1> und kein <main>: beides
 * traegt das Layout darueber. Auch keine <h2>Einstellungen</h2> mehr --
 * der Reiter heisst schon so, und eine Ueberschrift, die den Reiternamen
 * wiederholt, sagt nichts Zweites.
 *
 * Der erklaerende Satz bleibt und rueckt unter die Reiterleiste. Er steht
 * in .pageLead (--text-muted), nicht in .sectionNote (--text-faint):
 * ohne die fruehere Abschnittsueberschrift ist er der einzige Text, der
 * sagt, wofuer dieser Reiter da ist -- Pflichttext also, und
 * Designsystem 2 verbietet dafuer 3,6 : 1 (Befund 19).
 *
 * Genau eine Akzentflaeche: "Weitere Einstellung hinzufügen" -- oder,
 * aufgeklappt, "Einstellung anlegen" im EinstellungFormular (Hinzufuegen).
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
        Was ein Mitglied am Gerät einstellt und sich merken soll. Unter jeder
        Zeile stehen die Rasten, aus denen es wählen kann — nicht die
        Definition, sondern die Werte selbst.
      </p>

      {/* Ueber der Liste und erst auf Klick offen, sobald es eine
          Einstellung gibt (Testnotiz 22.09., #10). */}
      <Hinzufuegen
        knopf="Weitere Einstellung hinzufügen"
        titel="Einstellung anlegen"
        offen={modell.settingDefinitions.length === 0}
      >
        <EinstellungFormular action={parameterAnlegen.bind(null, studioId, modelId)} />
      </Hinzufuegen>

      <section className={styles.section}>
        {modell.settingDefinitions.length === 0 ? (
          <div className={styles.empty}>
            {/* Der Wortlaut folgt der Halle und TelefonZustaende.dc.html:
                Plural. Der Schreibtisch war hier der Ausreisser. */}
            <p className={styles.emptyTitle}>Noch keine Einstellungen.</p>
            <p className={styles.emptyNext}>
              Trag ein, was am Gerät verstellt wird — Sitz, Lehne, Startwinkel.
            </p>
          </div>
        ) : (
          <ul className={styles.rows} aria-label="Einstellungen am Modell">
            {modell.settingDefinitions.map((parameter) => (
              <li key={parameter.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{parameter.label}</div>
                  {/* Die Rasten, nicht die Definition: "1 · 2 · 3 · 4 ·
                      5 · 6 … · 8 Rasten" statt "1 bis 8 in Schritten von
                      1". Was am Geraet waehlbar ist, war bis hierher nur
                      auszurechnen (Befund 9 der UX-Challenge). */}
                  <div className={styles.rowMeta}>{rastenText(parameter)}</div>
                  <div className={styles.rowMetaFaint}>
                    {parameter.kind === "enum" ? "Auswahl" : "Zahl mit Bereich"}
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

      </section>
    </>
  );
}
