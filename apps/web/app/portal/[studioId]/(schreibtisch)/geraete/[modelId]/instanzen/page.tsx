import Link from "next/link";
import { notFound } from "next/navigation";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../../../Form";
import { geraetAnlegen, geraetStilllegen, geraetWiederInBetrieb } from "../../../../../actions";
import { ladeKatalog } from "../../../../catalog";
import styles from "../../../../../portal.module.css";

/**
 * Reiter "Einzelne Geräte" -- Abschnitt 4 der frueheren, einteiligen
 * Modellseite. Kein eigenes <h1>, kein <main>, keine
 * <h2>Geräte im Raum</h2>: Rueckweg, Titel und Reitername stehen im
 * Layout darueber, und der Reiter heisst schon "Einzelne Geräte".
 *
 * Der erklaerende Satz steht in .pageLead (--text-muted), nicht in
 * .sectionNote (--text-faint): er ist der einzige Text, der sagt, warum
 * ein Geraet ohne Tag ein halbes Geraet ist -- Pflichttext also, und
 * Designsystem 2 verbietet dafuer 3,6 : 1 (Befund 19).
 *
 * Zwei Stellen weichen bewusst vom Artboard ab:
 *
 * 1. Das Artboard zeichnet ein Zahlenfeld "Anzahl im Studio" mit einem
 *    Knopf "Geräte anlegen", der die fehlenden Geraete in einem Zug
 *    erzeugt. Das geht nicht ohne Nummernschema in der Datenbank:
 *    machines.label ist not null mit check(length(trim(label)) > 0)
 *    (Migration 0007), und Phase 5 macht keine Migration. Hier steht
 *    deshalb das Formular des Codes -- Bezeichnung und Standort, ein
 *    Geraet je Absenden.
 * 2. Das Artboard vergisst das Stilllegen (Befund 7). Die Spec verlangt
 *    es; die Zeile traegt beide Aktionen. Nachgezogen wird das Artboard.
 *
 * Die Zustandszeile folgt dagegen dem Artboard: "erreichbar" statt
 * "1 aktiver Tag". Dasselbe Wort benutzt erreichbarkeit() in catalog.ts
 * fuer die Modellliste ("1 Gerät, 1 erreichbar") -- und anders als
 * "1 aktiver Tag" unterscheidet es sich von "kein aktiver Tag" nicht nur
 * im Praefix, sondern im Wort.
 *
 * Genau eine Akzentflaeche: "Gerät anlegen". Tag scannen/ersetzen und
 * Wieder in Betrieb sind Nebenaktionen, Stilllegen ist zerstoerend.
 */
export default async function ModellInstanzenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  // Der Pfad, den geraetStilllegen und geraetWiederInBetrieb revalidieren.
  // Er zeigt auf die Stammdaten-Route, nicht auf /instanzen, und die beiden
  // rufen fuehreAus ohne dritten Parameter auf -- also als "page", nicht als
  // "layout" wie geraetAnlegen. Das ist folgenlos: gemessen frischt Next den
  // ganzen angezeigten Baum auf, sobald eine Aktion ueberhaupt eine
  // Revalidierung meldet (alle Routen hier sind ueber Cookies dynamisch).
  // Einheitlich ist es trotzdem nicht, und der Kommentar sagt es lieber,
  // als eine Ordnung zu behaupten, die im Code nicht steht.
  const pfad = `/portal/${studioId}/geraete/${modelId}`;

  return (
    <>
      <p className={styles.pageLead}>
        Ohne aktiven Tag findet ein Mitglied das Gerät nicht.
      </p>

      <section className={styles.section}>
        {modell.machines.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Gerät angelegt.</p>
            <p className={styles.emptyNext}>
              Ein Modell beschreibt den Typ. Für jedes Gerät im Raum brauchst du
              eine eigene Instanz mit eigener Bezeichnung.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {modell.machines.map((geraet) => {
              // Erreichbar heisst: in Betrieb UND mit aktivem Tag -- genau
              // die Rechnung aus erreichbarkeit() in catalog.ts, die auf
              // /geraete "1 Gerät, 1 erreichbar" schreibt. Ein stillgelegtes
              // Geraet mit klebendem Tag ist deshalb nicht erreichbar.
              const zustand =
                geraet.activeTagCount === 0 ? (
                  <span className={styles.absent}>kein aktiver Tag</span>
                ) : geraet.status === "active" ? (
                  // assignTag sperrt den bisherigen Tag nicht (catalog.ts),
                  // zwei aktive Tags an einem Geraet sind also moeglich --
                  // und dann ist die Zahl die Auskunft, nicht das Wort.
                  `erreichbar${geraet.activeTagCount > 1 ? ` · ${geraet.activeTagCount} aktive Tags` : ""}`
                ) : (
                  <span className={styles.absent}>nicht erreichbar</span>
                );

              return (
                <li key={geraet.id} className={styles.row}>
                  <div className={styles.rowMain}>
                    <div className={styles.rowTitle}>
                      {geraet.label}{" "}
                      {geraet.status === "inactive" ? (
                        <span className={styles.badge}>stillgelegt</span>
                      ) : null}
                    </div>
                    <div className={styles.rowMeta}>
                      {geraet.locationNote ?? (
                        <span className={styles.absent}>ohne Standortangabe</span>
                      )}
                      {" · "}
                      {zustand}
                    </div>
                  </div>
                  <div className={styles.rowActions}>
                    {/* Der Weg in die Halle. Welcher Tag an welchem Geraet
                        haengt, entscheidet der Scan vor dem Geraet -- nicht
                        ein Dropdown am Schreibtisch (Entscheidung 3). */}
                    {geraet.status === "active" ? (
                      <>
                        <Link
                          href={`/portal/${studioId}/einrichten/geraet/${geraet.id}/tag`}
                          className={styles.secondary}
                        >
                          {geraet.activeTagCount > 0 ? "Tag ersetzen" : "Tag scannen"}
                        </Link>
                        <AktionsKnopf
                          aktion={geraetStilllegen.bind(null, studioId, pfad, geraet.id)}
                          label="Stilllegen"
                          bestaetigung="Wirklich stilllegen?"
                          art="destructive"
                        />
                      </>
                    ) : (
                      <AktionsKnopf
                        aktion={geraetWiederInBetrieb.bind(null, studioId, pfad, geraet.id)}
                        label="Wieder in Betrieb"
                      />
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        <AktionsFormular
          action={geraetAnlegen.bind(null, studioId, modelId)}
          submitLabel="Gerät anlegen"
        >
          <div className={styles.grid}>
            <Feld
              name="label"
              label="Bezeichnung"
              required
              placeholder="12"
              hint="Die Nummer oder der Name, der am Gerät steht."
            />
            <Feld
              name="locationNote"
              label="Standort"
              placeholder="Rückwand links"
              hint="Hilft beim Wiederfinden. Optional."
            />
          </div>
        </AktionsFormular>
      </section>
    </>
  );
}
