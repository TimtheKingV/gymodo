import Link from "next/link";
import { AktionsFormular, Feld } from "../../Form";
import { modellAnlegen } from "../../actions";
import { erreichbarkeit, ladeKatalog } from "../catalog";
import styles from "../../portal.module.css";

export default async function ModellePage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);

  const geraeteGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).geraete,
    0,
  );
  const erreichbarGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).erreichbar,
    0,
  );

  return (
    <div className={styles.content}>
      <h1 className={styles.pageTitle}>Gerätekatalog</h1>
      <p className={styles.pageLead}>
        {geraeteGesamt === 0
          ? "Lege ein Gerätemodell an, dann eine Geräteinstanz, dann klebst du einen Tag darauf. Foto, Einstellparameter und Einweisungsvideo kannst du jederzeit nachreichen — ein Gerät funktioniert auch ohne sie."
          : `${erreichbarGesamt} von ${geraeteGesamt} Geräten sind für Mitglieder erreichbar. Erreichbar heißt: ein aktiver Tag klebt darauf.`}
      </p>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Gerätemodelle</h2>
          <span className={styles.sectionNote}>
            Ein Modell beschreibt den Gerätetyp. Die einzelnen Geräte im Raum
            sind Instanzen davon.
          </span>
        </div>

        {katalog.models.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Gerätemodell.</p>
            <p className={styles.emptyNext}>
              Fang mit dem Gerät an, das am häufigsten benutzt wird.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {katalog.models.map((modell) => {
              const stand = erreichbarkeit(modell);
              const mitVideo = modell.exercises.filter((u) => u.hasVideo).length;
              return (
                <li key={modell.id} className={styles.row}>
                  <div className={styles.rowMain}>
                    <div className={styles.rowTitle}>{modell.name}</div>
                    <div className={styles.rowMeta}>
                      {modell.manufacturer ? `${modell.manufacturer} · ` : ""}
                      {stand.geraete === 0 ? (
                        <span className={styles.absent}>noch kein Gerät</span>
                      ) : (
                        `${stand.erreichbar} von ${stand.geraete} erreichbar`
                      )}
                      {" · "}
                      {modell.exercises.length === 0 ? (
                        <span className={styles.absent}>keine Übung</span>
                      ) : (
                        `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}, ${mitVideo} mit Video`
                      )}
                    </div>
                  </div>
                  <div className={styles.rowActions}>
                    <Link
                      className={styles.secondary}
                      href={`/portal/${studioId}/modelle/${modell.id}`}
                    >
                      Bearbeiten
                    </Link>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className={styles.section} id="modell-anlegen">
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Modell anlegen</h2>
        </div>
        <AktionsFormular
          action={modellAnlegen.bind(null, studioId)}
          submitLabel="Modell anlegen"
        >
          <div className={styles.grid}>
            <Feld name="name" label="Name" required placeholder="Latzug" />
            <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />
            <Feld
              name="weightStepKg"
              label="Gewichtsschritt"
              required
              inputMode="decimal"
              placeholder="2,5"
              hint="In Kilogramm. So viel liegt zwischen zwei Steckplätzen."
            />
            <Feld
              name="minWeightKg"
              label="Minimum"
              inputMode="decimal"
              placeholder="5"
              hint="Leer lassen für 0."
            />
            <Feld
              name="maxWeightKg"
              label="Maximum"
              inputMode="decimal"
              placeholder="100"
              hint="Leer lassen, wenn kein Anschlag bekannt ist."
            />
          </div>
        </AktionsFormular>
      </section>
    </div>
  );
}
