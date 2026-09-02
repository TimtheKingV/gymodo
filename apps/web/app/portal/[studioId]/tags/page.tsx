import { AktionsKnopf } from "../../Form";
import { tagSperren } from "../../actions";
import { ladeKatalog } from "../catalog";
import { TagZuweisen } from "./TagZuweisen";
import styles from "../../portal.module.css";

const STATUS_TEXT: Record<string, string> = {
  unassigned: "vorrätig",
  active: "aktiv",
  revoked: "gesperrt",
  replaced: "ersetzt",
};

function datum(iso: string): string {
  return new Date(iso).toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export default async function TagsPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const pfad = `/portal/${studioId}/tags`;

  const geraeteNachId = new Map(
    katalog.models.flatMap((modell) =>
      modell.machines.map((geraet) => [
        geraet.id,
        { label: geraet.label, modell: modell.name, status: geraet.status },
      ]),
    ),
  );

  const freieGeraete = katalog.models.flatMap((modell) =>
    modell.machines
      .filter((geraet) => geraet.status === "active")
      .map((geraet) => ({ id: geraet.id, label: geraet.label, modell: modell.name })),
  );

  return (
    <div className={styles.content}>
      <h1 className={styles.pageTitle}>Tags</h1>
      <p className={styles.pageLead}>
        Tags kommen als Lieferung und werden nicht hier erzeugt. Welcher Tag an
        welchem Gerät hängt, entscheidet der Scan am Gerät. Aushangschilder sind
        ab Lieferung gültig und hängen an keinem Gerät.
      </p>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Alle Tags</h2>
        </div>

        {katalog.tags.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Tag.</p>
            <p className={styles.emptyNext}>
              Ohne Tag findet ein Mitglied kein Gerät. Leg einen an und klebe ihn
              auf.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {katalog.tags.map((tag) => {
              const geraet = tag.machineId ? geraeteNachId.get(tag.machineId) : null;
              const badgeKlasse =
                tag.status === "active"
                  ? `${styles.badge} ${styles.badgeActive}`
                  : tag.status === "revoked"
                    ? `${styles.badge} ${styles.badgeRevoked}`
                    : styles.badge;

              return (
                <li key={tag.id} className={styles.row}>
                  <div className={styles.rowMain}>
                    <div className={styles.rowTitle}>
                      <span className={badgeKlasse}>
                        {STATUS_TEXT[tag.status] ?? tag.status}
                      </span>{" "}
                      {geraet ? `${geraet.label} — ${geraet.modell}` : "ohne Gerät"}
                    </div>
                    <div className={styles.rowMeta}>
                      Angelegt {datum(tag.createdAt)}
                      {tag.status === "revoked" ? " · bleibt als Nachweis stehen" : ""}
                    </div>
                  </div>
                  <div className={styles.rowActions}>
                    {tag.status === "unassigned" ? (
                      <TagZuweisen
                        studioId={studioId}
                        pfad={pfad}
                        tagId={tag.id}
                        geraete={freieGeraete}
                      />
                    ) : null}
                    {tag.status !== "revoked" ? (
                      <AktionsKnopf
                        aktion={tagSperren.bind(null, studioId, pfad, tag.id)}
                        label="Sperren"
                        bestaetigung="Wirklich sperren?"
                        art="destructive"
                      />
                    ) : null}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}
