import Link from "next/link";
import { getStudioOverview } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { erreichbarkeit, ladeKatalog } from "./catalog";
import styles from "../portal.module.css";

const problemLabel: Record<string, string> = {
  schmerz: "Schmerz",
  geraet_passt_nicht: "Gerät passt nicht",
  zu_schwer: "Zu schwer",
  sonstiges: "Sonstiges",
};

export default async function UeberblickPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const client = await createServerSupabaseClient();
  const uebersicht = await getStudioOverview(client, studioId, 30);

  const geraeteGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).geraete,
    0,
  );
  const erreichbarGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).erreichbar,
    0,
  );
  const ohneTag = geraeteGesamt - erreichbarGesamt;
  const uebungenOhneVideo = katalog.models.reduce(
    (summe, modell) => summe + modell.exercises.filter((u) => !u.hasVideo).length,
    0,
  );
  const vorrat = katalog.tags.filter((tag) => tag.status === "unassigned").length;

  // Ein einfaches Mitglied bekommt aus studio_overview null. Es hat auf
  // dieser Seite nichts verloren -- aber es soll einen Satz sehen, keinen
  // Absturz.
  if (!uebersicht) {
    return (
      <main className={styles.content}>
        <h1 className={styles.pageTitle}>Überblick</h1>
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>
              Der Überblick ist Trainern und Inhabern vorbehalten.
            </p>
            <p className={styles.emptyNext}>
              Deine eigenen Trainingsdaten siehst du in der App, nicht hier.
            </p>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Überblick</h1>
      <p className={styles.pageLead}>
        Letzte {uebersicht.days} Tage. Studioweite Summen — welches Mitglied was
        trainiert hat, zeigt das Portal nirgends.
      </p>

      <div className={styles.kacheln}>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>
            {erreichbarGesamt} / {geraeteGesamt}
          </div>
          <div className={styles.kachelLabel}>Geräte erreichbar</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.activeMembers}</div>
          <div className={styles.kachelLabel}>Mitglieder aktiv</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.sets}</div>
          <div className={styles.kachelLabel}>Sätze erfasst</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.problemReports}</div>
          <div className={styles.kachelLabel}>Probleme gemeldet</div>
        </div>
      </div>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Was noch fehlt</h2>
        </div>
        {ohneTag === 0 && uebungenOhneVideo === 0 && geraeteGesamt > 0 ? (
          <p className={styles.sectionNote}>
            Nichts. Jedes Gerät in Betrieb ist erreichbar, jede Übung hat ein
            Einweisungsvideo.
          </p>
        ) : (
          <ul className={styles.rows}>
            {geraeteGesamt === 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>Noch kein Gerät angelegt</div>
                  <div className={styles.rowMeta}>
                    Fang mit dem Gerät an, das am häufigsten benutzt wird.
                  </div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                    Modell anlegen
                  </Link>
                </div>
              </li>
            ) : null}
            {ohneTag > 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {ohneTag === 1 ? "1 Gerät ohne Tag" : `${ohneTag} Geräte ohne Tag`}
                  </div>
                  <div className={styles.rowMeta}>
                    Für Mitglieder nicht auffindbar ·{" "}
                    {vorrat === 0 ? (
                      <span className={styles.absent}>kein Tag vorrätig</span>
                    ) : (
                      `${vorrat} vorrätig`
                    )}
                  </div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/tags`}>
                    Tag verbinden
                  </Link>
                </div>
              </li>
            ) : null}
            {uebungenOhneVideo > 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {uebungenOhneVideo === 1
                      ? "1 Übung ohne Einweisungsvideo"
                      : `${uebungenOhneVideo} Übungen ohne Einweisungsvideo`}
                  </div>
                  <div className={styles.rowMeta}>Nutzbar, nur ohne Anleitung</div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                    Ansehen
                  </Link>
                </div>
              </li>
            ) : null}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Meistgenutzt</h2>
        </div>
        {!uebersicht.breakdown ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Rangliste.</p>
            <p className={styles.emptyNext}>
              Sie erscheint ab {uebersicht.minMembers} aktiven Mitgliedern im
              Zeitraum. Bei weniger ließe sich aus ihr ablesen, wer was
              trainiert hat — und das zeigt das Portal nicht.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {uebersicht.topMachines.map((geraet) => (
              <li key={geraet.machineId} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {geraet.label}{" "}
                    {geraet.status === "inactive" ? (
                      <span className={styles.badge}>stillgelegt</span>
                    ) : null}
                  </div>
                </div>
                <div className={styles.rowMeta}>
                  {geraet.sets} {geraet.sets === 1 ? "Satz" : "Sätze"}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Gemeldete Probleme</h2>
          <span className={styles.sectionNote}>
            Ohne Namen. Wer gemeldet hat, steht hier nicht.
          </span>
        </div>
        {!uebersicht.breakdown || uebersicht.problems.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Keine Meldung im Zeitraum.</p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {uebersicht.problems.map((meldung) => (
              <li
                key={`${meldung.machineId}-${meldung.reason ?? "ohne"}`}
                className={styles.row}
              >
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{meldung.label}</div>
                  <div className={styles.rowMeta}>
                    {meldung.reason
                      ? (problemLabel[meldung.reason] ?? meldung.reason)
                      : "ohne Angabe"}
                  </div>
                </div>
                <div className={styles.rowMeta}>{meldung.count} ×</div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <p className={styles.hint}>
        gymodo misst nichts. Alles hier ist gezählt, was Mitglieder selbst
        bestätigt haben.
      </p>
    </main>
  );
}
