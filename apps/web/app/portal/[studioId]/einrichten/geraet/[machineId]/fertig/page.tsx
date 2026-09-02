import Link from "next/link";
import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import styles from "../../../halle.module.css";

/**
 * Der Abschluss zaehlt auf, was jetzt gilt -- und was nicht. Ein Geraet ohne
 * Video ist vollstaendig nutzbar (Spec 6.8); die Zeile steht trotzdem da,
 * weil der Ueberblick am Schreibtisch darueber Buch fuehrt.
 *
 * Der Probe-Scan des Artboards fehlt hier bewusst: er braeuchte den
 * Klartext-Token, und 0026 gewaehrt authenticated die Spalte token nicht.
 * Siehe den Plan, Aufgabe 12.
 */
export default async function FertigPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  const { modell, geraet } = treffer;
  const basis = `/portal/${studioId}/einrichten`;

  const aktiverTag = katalog.tags.find(
    (tag) => tag.machineId === machineId && tag.status === "active",
  );
  const ohneVideo = modell.exercises.filter((uebung) => !uebung.hasVideo).length;

  const geliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const vorraetig =
    geliefert - katalog.tags.filter((tag) => tag.kind === "machine").length;

  const zeilen: Array<{ haupt: string; meta: string; faint?: boolean }> = [
    modell.photoPath !== null
      ? { haupt: "Foto steht", meta: `Am Modell ${modell.name}` }
      : {
          haupt: "Kein Foto",
          meta: `Am Modell ${modell.name} · Mitglieder sähen nur den Namen`,
          faint: true,
        },
    modell.settingDefinitions.length > 0
      ? {
          haupt: `${modell.settingDefinitions.length} Einstellparameter`,
          meta: `${modell.settingDefinitions.map((p) => p.label).join(", ")} · ebenfalls am Modell`,
        }
      : {
          haupt: "Keine Einstellparameter",
          meta: "Nutzbar, das Mitglied hat nur nichts einzustellen",
          faint: true,
        },
    aktiverTag
      ? {
          haupt: "Tag verbunden",
          meta: `Charge ${aktiverTag.batchCode} · Nummer ${aktiverTag.batchIndex} · aktiv seit gerade eben`,
        }
      : {
          haupt: "Kein aktiver Tag",
          meta: "Ohne ihn findet kein Mitglied dieses Gerät",
          faint: true,
        },
    {
      haupt: `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}`,
      meta:
        modell.exercises.length > 0
          ? modell.exercises.map((uebung) => uebung.name).join(", ")
          : "Ohne Übung zeigt das Gerät nichts zum Trainieren",
    },
  ];

  if (ohneVideo > 0) {
    zeilen.push({
      haupt: `${ohneVideo} ${ohneVideo === 1 ? "Übung ohne Video" : "Übungen ohne Video"}`,
      meta: "Nutzbar, nur ohne Anleitung",
      faint: true,
    });
  }

  return (
    <>
      <div>
        <h1 className={styles.titel}>
          {modell.name} {geraet.label} {aktiverTag ? "steht" : "wartet noch"}
        </h1>
        <p className={styles.unterzeile}>
          {aktiverTag
            ? "Für Mitglieder auffindbar"
            : "Ohne Tag für Mitglieder nicht auffindbar"}
        </p>
      </div>

      <section className={styles.abschnitt}>
        <div className={styles.abschnittKopf}>
          <h2 className={styles.label}>Was jetzt gilt</h2>
        </div>
        {zeilen.map((zeile) => (
          <div key={zeile.haupt} className={styles.zeile}>
            <div style={{ minWidth: 0 }}>
              <div className={styles.zeileHaupt}>{zeile.haupt}</div>
              <div
                className={zeile.faint ? styles.zeileMetaFaint : styles.zeileMeta}
              >
                {zeile.meta}
              </div>
            </div>
          </div>
        ))}
      </section>

      {aktiverTag ? null : (
        <Link href={`${basis}/geraet/${machineId}/tag`} className={styles.neben}>
          Tag nachholen
        </Link>
      )}

      <Link href={`${basis}/modell`} className={styles.haupt}>
        Nächstes Gerät
      </Link>
      <Link href={basis} className={styles.neben}>
        Für heute fertig
      </Link>

      <p className={styles.notiz}>
        {vorraetig > 0
          ? `${vorraetig} ${vorraetig === 1 ? "Tag" : "Tags"} noch in der Packung.`
          : "Kein Tag mehr vorrätig. Die eingerichteten Geräte funktionieren weiter; die übrigen warten auf die nächste Lieferung."}
      </p>
    </>
  );
}
