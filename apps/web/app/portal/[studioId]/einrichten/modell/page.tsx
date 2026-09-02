import Link from "next/link";
import { ladeKatalog } from "../../catalog";
import { Schrittleiste } from "../Schrittleiste";
import styles from "../halle.module.css";

/**
 * Schritt 1: welches Modell. Der Akzent gehoert dem Anlegen, nicht dem
 * Waehlen -- bei der Erstbestueckung ist das der Fall, der oefter eintritt.
 */
export default async function ModellWaehlenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const basis = `/portal/${studioId}/einrichten`;

  function meta(modell: (typeof katalog.models)[number]): string {
    const teile = [
      modell.manufacturer ?? "Ohne Hersteller",
      `${modell.machines.length} ${modell.machines.length === 1 ? "Gerät" : "Geräte"}`,
      `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}`,
      `${modell.settingDefinitions.length} Parameter`,
    ];
    if (modell.photoPath === null) teile.push("kein Foto");
    return teile.join(" · ");
  }

  return (
    <>
      <Schrittleiste nummer={1} titel="Modell" />
      <div>
        <Link href={basis} className={styles.zurueck}>
          ← Einrichten
        </Link>
        <h1 className={styles.titel}>Was steht hier?</h1>
      </div>

      {katalog.models.length > 0 ? (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Modelle im Studio</h2>
          </div>
          {katalog.models.map((modell) => (
            <div key={modell.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{modell.name}</div>
                <div
                  className={
                    modell.photoPath === null
                      ? styles.zeileMetaFaint
                      : styles.zeileMeta
                  }
                >
                  {meta(modell)}
                </div>
              </div>
              <Link
                href={`${basis}/modell/${modell.id}/einstellungen`}
                className={styles.nebenSchmal}
              >
                Wählen
              </Link>
            </div>
          ))}
        </section>
      ) : (
        <p className={styles.notiz}>Noch kein Modell im Studio.</p>
      )}

      <div className={styles.karteGestrichelt}>
        <div>
          <div className={styles.karteTitel}>Noch nicht dabei</div>
          <div className={styles.notiz}>
            Ein Modell beschreibt den Gerätetyp. Zwei Kabelzüge nebeneinander
            sind ein Modell und zwei Geräte.
          </div>
        </div>
        <Link href={`${basis}/modell/neu`} className={styles.haupt}>
          Neues Modell anlegen
        </Link>
      </div>
    </>
  );
}
