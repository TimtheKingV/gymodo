import Link from "next/link";
import { DomainError, getStudioOverview } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { erreichbarkeit, ladeKatalog } from "../catalog";
import styles from "../../portal.module.css";

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

  // Wie in leute/page.tsx: der Fehler bleibt auf der Seite, statt sie
  // abzuschiessen. getStudioOverview wirft bei jedem RPC-Fehler -- solange
  // die Migrationen 0033/0034 irgendwo nicht eingespielt sind, ist das der
  // Normalfall und nicht die Ausnahme. Ohne dieses Netz stuende hier die
  // Standardseite von Next, und die sagt weder, was falsch ist, noch was
  // gilt.
  let uebersicht: Awaited<ReturnType<typeof getStudioOverview>> = null;
  let fehler: string | null = null;
  try {
    uebersicht = await getStudioOverview(client, studioId, 30);
  } catch (e) {
    fehler = e instanceof DomainError ? e.message : "Die Summen liessen sich nicht laden.";
  }

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

  // Spec Abschnitt 5: Leer heisst Ueberschrift plus naechster Schritt, nie
  // eine leere Statistik mit Nullen. Ein Studio ohne Geraet und ohne
  // begonnene Einheit hat keine Zahlen, sondern einen Anfang.
  const frischesStudio = geraeteGesamt === 0 && (uebersicht?.activeMembers ?? 0) === 0;

  // Ein einfaches Mitglied bekommt aus studio_overview null. Es hat auf
  // dieser Seite nichts verloren -- aber es soll einen Satz sehen, keinen
  // Absturz. Ein Fehler sieht anders aus als eine Absage, deshalb erst
  // hier und nur ohne fehler.
  if (!fehler && !uebersicht) {
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
      {uebersicht ? (
        <p className={styles.pageLead}>
          Letzte {uebersicht.days} Tage. Studioweite Summen — welches Mitglied
          was trainiert hat, zeigt das Portal nirgends.
        </p>
      ) : null}

      {!uebersicht ? (
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.error}>{fehler}</p>
            <p className={styles.emptyNext}>
              Die Summen fehlen. Alles Weitere auf dieser Seite kommt aus dem
              Katalog und stimmt — Geräte, Tags und Videos sind davon nicht
              betroffen.
            </p>
          </div>
        </div>
      ) : frischesStudio ? (
        // Spec Abschnitt 5: nie eine leere Statistik mit Nullen. Vier
        // Kacheln, die viermal 0 zeigen, sagen ueber ein neues Studio
        // nichts, was der naechste Schritt nicht besser sagt. Sobald ein
        // Geraet existiert, sind die Kacheln wieder Inhalt -- "2 / 4
        // Geräte erreichbar" ist eine Aussage, keine Reihe von Nullen.
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch nichts zu zählen.</p>
            <p className={styles.emptyNext}>
              Das Studio hat weder ein Gerät noch eine begonnene Einheit. Fang
              mit dem ersten Gerätemodell an — die Zahlen kommen von selbst,
              sobald jemand trainiert.
            </p>
          </div>
        </div>
      ) : (
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
          {/* Ein Strich, keine 0: unter der Mindestzahl ist die Zahl
              verdeckt, nicht null. Die Begruendung steht in den beiden
              Abschnitten weiter unten und wird hier nicht wiederholt. */}
          <div className={styles.kachel}>
            <div className={styles.kachelZahl}>{uebersicht.sets ?? "—"}</div>
            <div className={styles.kachelLabel}>Sätze erfasst</div>
          </div>
          <div className={styles.kachel}>
            <div className={styles.kachelZahl}>
              {uebersicht.problemReports ?? "—"}
            </div>
            <div className={styles.kachelLabel}>Probleme gemeldet</div>
          </div>
        </div>
      )}

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

      {uebersicht ? (
        <>
          <section className={styles.section}>
            <div className={styles.sectionHead}>
              <h2 className={styles.sectionTitle}>Meistgenutzt</h2>
            </div>
            {!uebersicht.breakdown ? (
              <div className={styles.empty}>
                <p className={styles.emptyTitle}>Noch keine Rangliste.</p>
                <p className={styles.emptyNext}>
                  Sie erscheint, sobald {uebersicht.minMembers} Mitglieder im
                  Zeitraum Sätze erfasst haben. Bei weniger ließe sich aus ihr
                  ablesen, wer was trainiert hat — und das zeigt das Portal
                  nicht.
                </p>
              </div>
            ) : uebersicht.topMachines.length === 0 ? (
              <div className={styles.empty}>
                <p className={styles.emptyTitle}>Noch kein Satz erfasst.</p>
                <p className={styles.emptyNext}>
                  Aktive Mitglieder gibt es — eine Einheit gilt als begonnen,
                  sobald jemand ein Gerät antippt. Gezählt wird hier erst, was
                  am Gerät bestätigt wurde.
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
            {!uebersicht.breakdown ? (
              <div className={styles.empty}>
                <p className={styles.emptyTitle}>Noch keine Aufschlüsselung.</p>
                <p className={styles.emptyNext}>
                  Sie erscheint, sobald {uebersicht.minMembers} Mitglieder im
                  Zeitraum Sätze erfasst haben. Bis dahin bleibt auch die Zahl
                  oben verdeckt — sie zeigt einen Strich, keine Null.
                </p>
              </div>
            ) : uebersicht.problems.length === 0 ? (
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
        </>
      ) : null}

      <p className={styles.hint}>
        gymodo misst nichts. Alles hier ist gezählt, was Mitglieder selbst
        bestätigt haben.
      </p>
    </main>
  );
}
