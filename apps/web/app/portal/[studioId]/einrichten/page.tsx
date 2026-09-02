import Link from "next/link";
import { ladeKatalog } from "../catalog";
import styles from "./halle.module.css";

/**
 * Der Einstieg steht in der Halle, nicht am Schreibtisch: was fehlt noch,
 * wie viele Tags sind in der Packung, und ein Knopf, der den Gang beginnt.
 *
 * "Was noch fehlt" fuehrt zwei verschiedene Maengel in einer Liste, weil sie
 * denselben Ausgang haben -- den Gang. Ein Geraet ohne aktiven Tag existiert
 * fuer Mitglieder nicht; ein Modell ohne Foto ist nach dem Scan nicht von
 * seinem baugleichen Nachbarn zu unterscheiden (Entscheidung 10).
 */
export default async function EinrichtenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const basis = `/portal/${studioId}/einrichten`;

  const geraete = katalog.models.flatMap((modell) =>
    modell.machines
      .filter((geraet) => geraet.status === "active")
      .map((geraet) => ({ ...geraet, modell })),
  );

  const ohneTag = geraete.filter((geraet) => geraet.activeTagCount === 0);
  const unvollstaendig = katalog.models.filter(
    (modell) =>
      modell.photoPath === null || modell.settingDefinitions.length === 0,
  );

  const geliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const verbraucht = katalog.tags.filter((tag) => tag.kind === "machine").length;
  const vorraetig = geliefert - verbraucht;

  function mangel(modell: (typeof katalog.models)[number]): string {
    if (modell.photoPath === null && modell.settingDefinitions.length === 0) {
      return "Kein Foto, keine Einstellparameter · Mitglieder sähen nur den Namen";
    }
    if (modell.photoPath === null) {
      return "Kein Foto · nach dem Scan nicht von einem baugleichen Gerät zu unterscheiden";
    }
    return "Keine Einstellparameter · das Mitglied hat nichts einzustellen";
  }

  return (
    <>
      <div>
        <h1 className={styles.titel}>Einrichten</h1>
        <p className={styles.unterzeile}>
          Geh von Gerät zu Gerät. Jedes ist fertig, sobald sein Tag klebt.
        </p>
      </div>

      <div className={styles.karte}>
        <div className={styles.zahlen}>
          <div>
            <div className={styles.zahl}>{geraete.length}</div>
            <div className={styles.zahlLabel}>Geräte</div>
          </div>
          <div>
            <div className={styles.zahl}>{katalog.models.length}</div>
            <div className={styles.zahlLabel}>Modelle</div>
          </div>
          <div>
            <div className={ohneTag.length > 0 ? styles.zahlOffen : styles.zahl}>
              {ohneTag.length}
            </div>
            <div
              className={
                ohneTag.length > 0 ? styles.zahlLabelOffen : styles.zahlLabel
              }
            >
              ohne Tag
            </div>
          </div>
        </div>
      </div>

      <div className={styles.karte}>
        <div>
          <div className={styles.karteTitel}>{vorratText(vorraetig)}</div>
          <div className={styles.notiz}>
            {katalog.shipments.length === 0
              ? "Noch keine Lieferung angekommen. Ohne Tag findet ein Mitglied kein Gerät."
              : `${katalog.shipments.length} ${katalog.shipments.length === 1 ? "Lieferung" : "Lieferungen"} · ${geliefert} Stück, ${verbraucht} vergeben`}
          </div>
        </div>
      </div>

      <Link href={`${basis}/modell`} className={styles.haupt}>
        Gerät einrichten
      </Link>

      {ohneTag.length + unvollstaendig.length > 0 ? (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Was noch fehlt</h2>
          </div>
          {ohneTag.map((geraet) => (
            <div key={geraet.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{geraet.label}</div>
                <div className={styles.zeileMeta}>
                  {geraet.locationNote ?? "ohne Standortangabe"} · kein Tag, für
                  Mitglieder nicht auffindbar
                </div>
              </div>
              <Link
                href={`${basis}/geraet/${geraet.id}/tag`}
                className={styles.nebenSchmal}
              >
                Weiter
              </Link>
            </div>
          ))}
          {unvollstaendig.map((modell) => (
            <div key={modell.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{modell.name}</div>
                <div className={styles.zeileMetaFaint}>{mangel(modell)}</div>
              </div>
              <Link
                href={`${basis}/modell/${modell.id}/einstellungen`}
                className={styles.nebenSchmal}
              >
                Weiter
              </Link>
            </div>
          ))}
        </section>
      ) : null}

      <p className={styles.notiz}>
        Ein Gerät ist fertig, sobald sein Tag klebt. Übungen und Videos lassen
        sich jederzeit nachtragen.
      </p>
    </>
  );
}

function vorratText(vorraetig: number): string {
  if (vorraetig <= 0) return "Kein Tag vorrätig";
  return `${vorraetig} ${vorraetig === 1 ? "Tag" : "Tags"} vorrätig`;
}
