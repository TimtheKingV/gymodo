import Link from "next/link";
import { AktionsKnopf } from "../../Form";
import { geraetStilllegen, geraetWiederInBetrieb } from "../../actions";
import { ladeKatalog } from "../catalog";
import { TagAnlegen } from "../TagAnlegen";
import styles from "../../portal.module.css";

/**
 * Alle Geraete quer ueber die Modelle -- die Ansicht fuer den Rundgang
 * durch den Raum. Sortiert nach Erreichbarkeit: was noch keinen aktiven
 * Tag hat, steht oben, weil es fuer Mitglieder schlicht nicht existiert.
 */
export default async function GeraetePage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const pfad = `/portal/${studioId}/geraete`;

  const geraete = katalog.models
    .flatMap((modell) =>
      modell.machines.map((geraet) => ({ ...geraet, modell })),
    )
    .sort((a, b) => {
      const rang = (eintrag: typeof a) =>
        eintrag.status === "inactive" ? 2 : eintrag.activeTagCount > 0 ? 1 : 0;
      const unterschied = rang(a) - rang(b);
      if (unterschied !== 0) return unterschied;
      return a.label.localeCompare(b.label, "de", { numeric: true });
    });

  const inBetrieb = geraete.filter((geraet) => geraet.status === "active").length;
  const ohneTag = geraete.filter(
    (geraet) => geraet.status === "active" && geraet.activeTagCount === 0,
  ).length;

  function lead(): string {
    if (geraete.length === 0) {
      return "Noch kein Gerät angelegt. Geräte entstehen im jeweiligen Gerätemodell.";
    }
    if (ohneTag === 0) {
      return inBetrieb === 1
        ? "Das Gerät in Betrieb ist erreichbar."
        : `Alle ${inBetrieb} Geräte in Betrieb sind erreichbar.`;
    }
    return ohneTag === 1
      ? "Ein Gerät hat noch keinen aktiven Tag und ist damit für Mitglieder nicht auffindbar."
      : `${ohneTag} Geräte haben noch keinen aktiven Tag und sind damit für Mitglieder nicht auffindbar.`;
  }

  return (
    <div className={styles.content}>
      <h1 className={styles.pageTitle}>Geräte</h1>
      <p className={styles.pageLead}>{lead()}</p>

      {geraete.length > 0 ? (
        <section className={styles.section}>
          <div className={styles.sectionHead}>
            <h2 className={styles.sectionTitle}>Alle Geräte</h2>
            <span className={styles.sectionNote}>Ohne Tag zuerst.</span>
          </div>
          <ul className={styles.rows}>
            {geraete.map((geraet) => (
              <li key={geraet.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {geraet.label}{" "}
                    {geraet.status === "inactive" ? (
                      <span className={styles.badge}>stillgelegt</span>
                    ) : null}
                  </div>
                  <div className={styles.rowMeta}>
                    <Link href={`/portal/${studioId}/modelle/${geraet.modell.id}`}>
                      {geraet.modell.name}
                    </Link>
                    {" · "}
                    {geraet.locationNote ?? (
                      <span className={styles.absent}>ohne Standortangabe</span>
                    )}
                    {" · "}
                    {geraet.activeTagCount > 0 ? (
                      "erreichbar"
                    ) : (
                      <span className={styles.absent}>kein aktiver Tag</span>
                    )}
                  </div>
                </div>
                <div className={styles.rowActions}>
                  {geraet.status === "active" ? (
                    <>
                      <TagAnlegen studioId={studioId} pfad={pfad} machineId={geraet.id} />
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
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
