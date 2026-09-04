import Link from "next/link";
import { DomainError, getStudioOverview, listCourseWeek } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { erreichbarkeit, ladeKatalog } from "../catalog";
import { uhrzeit, wochenFenster } from "./kurse/woche";
import { Seite } from "../../bausteine/Seite";
import { Abschnitt } from "../../bausteine/Abschnitt";
import { Zeile, Zeilen } from "../../bausteine/Zeile";
import { Kacheln, Kachel } from "../../bausteine/Kachel";
import { Zustand } from "../../bausteine/Zustand";
import { Produktgrenze } from "../../bausteine/Produktgrenze";
import styles from "../../portal.module.css";

const problemLabel: Record<string, string> = {
  schmerz: "Schmerz",
  geraet_passt_nicht: "Gerät passt nicht",
  zu_schwer: "Zu schwer",
  sonstiges: "Sonstiges",
};

/** Wie tags/page.tsx: Datum ausgeschrieben, in der Studio-Zeitzone (Designsystem 10). */
function datum(iso: string, timeZone: string): string {
  return new Date(iso).toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone,
  });
}

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
      <Seite titel="Überblick">
        <Zustand
          art="keinRecht"
          titel="Der Überblick ist Trainern und Inhabern vorbehalten."
          naechsterSchritt="Deine eigenen Trainingsdaten siehst du in der App, nicht hier."
        />
      </Seite>
    );
  }

  // Diese Woche: eine eigene Abfrage, unabhaengig von studio_overview. Ein
  // Fehler hier darf weder die Kacheln noch den Katalog mitreissen -- wie
  // der Fehlerfall der Summen daneben einen funktionierenden Katalog laesst.
  // Gezeigt werden die naechsten planmaessigen Termine der Kalenderwoche,
  // hoechstens fuenf: der Ueberblick ist eine Vorschau mit einem Weg zu den
  // Kursen, keine zweite Kopie der vollstaendigen Wochenansicht.
  let wocheFehler: string | null = null;
  let sitzungen: Awaited<ReturnType<typeof listCourseWeek>>["sessions"] = [];
  try {
    const fenster = wochenFenster(undefined, katalog.studioTimezone);
    const woche = await listCourseWeek(client, studioId, fenster.von, fenster.bis);
    sitzungen = woche.sessions
      .filter((sitzung) => sitzung.status === "planned")
      .sort((a, b) => a.startsAt.localeCompare(b.startsAt))
      .slice(0, 5);
  } catch (e) {
    wocheFehler = e instanceof DomainError ? e.message : "Der Kursplan liess sich nicht laden.";
  }

  // Extrahiert, weil sie im Fehlerfall der Summen allein steht (kein Platz
  // fuer "Meistgenutzt" daneben), sonst aber die linke Haelfte der
  // zweispaltigen Reihe aus Main.dc.html bildet.
  const wasNochFehlt = (
    <Abschnitt titel="Was noch fehlt">
      {ohneTag === 0 && uebungenOhneVideo === 0 && geraeteGesamt > 0 ? (
        <p className={styles.sectionNote}>
          Nichts. Jedes Gerät in Betrieb ist erreichbar, jede Übung hat ein
          Einweisungsvideo.
        </p>
      ) : (
        <Zeilen>
          {geraeteGesamt === 0 ? (
            <Zeile
              titel="Noch kein Gerät angelegt"
              meta="Fang mit dem Gerät an, das am häufigsten benutzt wird."
              aktionen={
                <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                  Modell anlegen
                </Link>
              }
            />
          ) : null}
          {ohneTag > 0 ? (
            <Zeile
              titel={ohneTag === 1 ? "1 Gerät ohne Tag" : `${ohneTag} Geräte ohne Tag`}
              meta={
                <>
                  Für Mitglieder nicht auffindbar ·{" "}
                  {vorrat === 0 ? (
                    <span className={styles.absent}>kein Tag vorrätig</span>
                  ) : (
                    `${vorrat} vorrätig`
                  )}
                </>
              }
              aktionen={
                <Link className={styles.secondary} href={`/portal/${studioId}/tags`}>
                  Tag verbinden
                </Link>
              }
            />
          ) : null}
          {uebungenOhneVideo > 0 ? (
            <Zeile
              titel={
                uebungenOhneVideo === 1
                  ? "1 Übung ohne Einweisungsvideo"
                  : `${uebungenOhneVideo} Übungen ohne Einweisungsvideo`
              }
              meta="Nutzbar, nur ohne Anleitung"
              aktionen={
                <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                  Ansehen
                </Link>
              }
            />
          ) : null}
        </Zeilen>
      )}
    </Abschnitt>
  );

  return (
    <Seite
      titel="Überblick"
      vorspann={
        uebersicht ? (
          <>
            Letzte {uebersicht.days} Tage. Studioweite Summen — welches Mitglied
            was trainiert hat, zeigt das Portal nirgends.
          </>
        ) : undefined
      }
    >
      {!uebersicht ? (
        <Zustand
          art="fehler"
          titel={fehler!}
          naechsterSchritt="Die Summen fehlen. Alles Weitere auf dieser Seite kommt aus dem Katalog und stimmt — Geräte, Tags und Videos sind davon nicht betroffen."
        />
      ) : frischesStudio ? (
        // Spec Abschnitt 5: nie eine leere Statistik mit Nullen. Vier
        // Kacheln, die viermal 0 zeigen, sagen ueber ein neues Studio
        // nichts, was der naechste Schritt nicht besser sagt. Sobald ein
        // Geraet existiert, sind die Kacheln wieder Inhalt -- "2 / 4
        // Geräte erreichbar" ist eine Aussage, keine Reihe von Nullen.
        <Zustand
          art="leer"
          titel="Noch nichts zu zählen."
          naechsterSchritt="Das Studio hat weder ein Gerät noch eine begonnene Einheit. Fang mit dem ersten Gerätemodell an — die Zahlen kommen von selbst, sobald jemand trainiert."
        />
      ) : (
        <Kacheln>
          <Kachel
            zahl={
              <>
                {erreichbarGesamt} / {geraeteGesamt}
              </>
            }
            label="Geräte erreichbar"
          />
          <Kachel zahl={uebersicht.activeMembers} label="Mitglieder aktiv" />
          {/* Ein Strich, keine 0: unter der Mindestzahl ist die Zahl
              verdeckt, nicht null. Die Begruendung steht in den beiden
              Abschnitten weiter unten und wird hier nicht wiederholt. */}
          <Kachel zahl={uebersicht.sets ?? "—"} label="Sätze erfasst" />
          <Kachel zahl={uebersicht.problemReports ?? "—"} label="Probleme gemeldet" />
        </Kacheln>
      )}

      <Abschnitt
        titel="Diese Woche"
        notiz={
          <Link
            href={`/portal/${studioId}/kurse`}
            className={styles.secondary}
            style={{ fontSize: "14px" }}
          >
            Zu den Kursen
          </Link>
        }
      >
        {wocheFehler ? (
          <Zustand art="fehler" titel={wocheFehler} />
        ) : sitzungen.length === 0 ? (
          <Zustand
            art="leer"
            titel="Kein Kurstermin in dieser Woche."
            naechsterSchritt="Kurstermine legst du unter Kurse an."
          />
        ) : (
          <Zeilen>
            {sitzungen.map((sitzung) => (
              <Zeile
                key={sitzung.sessionId}
                titel={`${datum(sitzung.startsAt, katalog.studioTimezone)} · ${uhrzeit(sitzung.startsAt, katalog.studioTimezone)} · ${sitzung.name}`}
                meta={`${sitzung.instructorName ?? "Ohne Trainer"}${sitzung.room ? ` · ${sitzung.room}` : ""}`}
                aktionen={
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontWeight: 700 }}>
                      {sitzung.bookedCount} von {sitzung.capacity}
                    </div>
                    {/* Nur die Zahl, nie ein Versprechen: eine
                        Nachrueck-Benachrichtigung von der Warteliste gibt es
                        nicht, und Designsystem 11 / Struktur-Spec 8 verbieten
                        den Satz deshalb, bis sie existiert. */}
                    {sitzung.freeSeats <= 0 && sitzung.waitlistCount > 0 ? (
                      <div style={{ fontSize: "12px", color: "var(--text-faint)" }}>
                        +{sitzung.waitlistCount} Warteliste
                      </div>
                    ) : null}
                  </div>
                }
              />
            ))}
          </Zeilen>
        )}
      </Abschnitt>

      {uebersicht ? (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))",
            gap: "var(--s24)",
            marginTop: "var(--s24)",
          }}
        >
          {wasNochFehlt}

          <Abschnitt titel="Meistgenutzt">
            {!uebersicht.breakdown ? (
              <Zustand
                art="leer"
                titel="Noch keine Rangliste."
                naechsterSchritt={`Sie erscheint, sobald ${uebersicht.minMembers} Mitglieder im Zeitraum Sätze erfasst haben. Bei weniger ließe sich aus ihr ablesen, wer was trainiert hat — und das zeigt das Portal nicht.`}
              />
            ) : uebersicht.topMachines.length === 0 ? (
              <Zustand
                art="leer"
                titel="Noch kein Satz erfasst."
                naechsterSchritt="Aktive Mitglieder gibt es — eine Einheit gilt als begonnen, sobald jemand ein Gerät antippt. Gezählt wird hier erst, was am Gerät bestätigt wurde."
              />
            ) : (
              <Zeilen>
                {uebersicht.topMachines.map((geraet) => (
                  <Zeile
                    key={geraet.machineId}
                    titel={
                      <>
                        {geraet.label}
                        {geraet.status === "inactive" ? (
                          <> <span className={styles.badge}>stillgelegt</span></>
                        ) : null}
                      </>
                    }
                    aktionen={
                      <span>
                        {geraet.sets} {geraet.sets === 1 ? "Satz" : "Sätze"}
                      </span>
                    }
                  />
                ))}
              </Zeilen>
            )}
          </Abschnitt>
        </div>
      ) : (
        wasNochFehlt
      )}

      {uebersicht ? (
        <Abschnitt
          titel="Gemeldete Probleme"
          notiz="Ohne Namen. Wer gemeldet hat, steht hier nicht."
        >
          {!uebersicht.breakdown ? (
            <Zustand
              art="leer"
              titel="Noch keine Aufschlüsselung."
              naechsterSchritt={`Sie erscheint, sobald ${uebersicht.minMembers} Mitglieder im Zeitraum Sätze erfasst haben. Bis dahin bleibt auch die Zahl oben verdeckt — sie zeigt einen Strich, keine Null.`}
            />
          ) : uebersicht.problems.length === 0 ? (
            <Zustand art="leer" titel="Keine Meldung im Zeitraum." />
          ) : (
            <Zeilen>
              {uebersicht.problems.map((meldung) => (
                <Zeile
                  key={`${meldung.machineId}-${meldung.reason ?? "ohne"}`}
                  titel={meldung.label}
                  meta={
                    meldung.reason
                      ? (problemLabel[meldung.reason] ?? meldung.reason)
                      : "ohne Angabe"
                  }
                  aktionen={<span>{meldung.count} ×</span>}
                />
              ))}
            </Zeilen>
          )}
        </Abschnitt>
      ) : null}

      <Produktgrenze>
        gymodo misst nichts. Alles hier ist gezählt, was Mitglieder selbst
        bestätigt haben.
      </Produktgrenze>
    </Seite>
  );
}
