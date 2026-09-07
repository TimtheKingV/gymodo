import Link from "next/link";
import { Abschnitt } from "../../../bausteine/Abschnitt";
import { Erlaeuterung } from "../../../bausteine/Erlaeuterung";
import { Reiter } from "../../../bausteine/Reiter";
import { Seite } from "../../../bausteine/Seite";
import { Zeilen } from "../../../bausteine/Zeile";
import { Zustand } from "../../../bausteine/Zustand";
import { MitgliedZeile } from "./LeuteActions";
import { kuerzen, ladeLeute, leuteReiter, seit } from "./leute";
import styles from "../../../portal.module.css";

/**
 * Reiter "Mitglieder" (Aufgabe 19, LeuteMitglieder.dc.html). Bis hier war
 * dies EINE Seite mit EINER Liste, in der Mitglieder und Mitarbeiter
 * durcheinanderstanden -- und in der jede Zeile den Rollenknopf trug.
 * Struktur-Spec Abschnitt 2 trennt beides: die Mitarbeiterliste ist die
 * Rechteverwaltung und liegt eine Route tiefer, unter
 * leute/mitarbeiter.
 *
 * Kein Client-Rand: `aktiv` ist hier eine Konstante, weil diese Seite
 * weiss, welcher Reiter sie ist. Am Modell (Aufgabe 16) musste dafuer ein
 * "use client"-Baustein her, weil die Reiterleiste dort in einem Layout
 * ueber vier Routen steht.
 *
 * Der Fusssatz ist neu und ersetzt den ueberholten aus dem Artboard
 * (Befund 20): der zeichnete noch den Vorbehalt "Heute lassen die
 * Richtlinien der Datenbank Mitarbeiter noch an Saetze, Gewichte und
 * Verlaeufe heran". Seit Migration 0033 (2. September) haben die vier
 * betroffenen Policies die Staff-Klausel verloren; der Vorbehalt
 * beschreibt etwas, das es nicht mehr gibt, und machte die Zusicherung
 * schwaecher als die Wirklichkeit.
 */
export default async function LeutePage({
  params,
  searchParams,
}: {
  params: Promise<{ studioId: string }>;
  searchParams: Promise<{ alle?: string }>;
}) {
  const { studioId } = await params;
  const { alle } = await searchParams;
  const daten = await ladeLeute(studioId);
  const pfad = `/portal/${studioId}/leute`;

  if (daten.keinRecht) {
    // Aufgabe 19: kein dritter handgeschriebener Kein-Recht-Block mehr.
    // Der Zustand-Baustein traegt die Regel aus Designsystem 5 an einer
    // Stelle; sein Docstring nannte leute/page.tsx bis hier ausdruecklich
    // als offene Migration.
    return (
      <Seite titel="Mitglieder">
        <Zustand art="keinRecht" titel="Diese Seite ist Trainern und Inhabern vorbehalten." />
      </Seite>
    );
  }

  const { sichtbar, weitere } = kuerzen(daten.mitglieder, alle === "1");

  return (
    <Seite
      titel="Mitglieder"
      vorspann="Wer hier steht, kann sich anmelden und im Studio trainieren. Das Portal zeigt die Mitgliedschaft — nicht, was jemand trainiert hat."
    >
      <Reiter name="Leute" eintraege={leuteReiter(studioId, daten, "mitglieder")} />

      <Abschnitt titel="Alle Mitglieder">
        {daten.fehler ? (
          <Zustand art="fehler" titel={daten.fehler} />
        ) : daten.mitglieder.length === 0 ? (
          <Zustand
            art="leer"
            titel="Noch niemand ist beigetreten."
            naechsterSchritt="Gib den Beitrittscode weiter, dann erscheint die Person hier."
          />
        ) : (
          <>
            <Zeilen>
              {sichtbar.map((person) => (
                <MitgliedZeile
                  key={person.userId}
                  studioId={studioId}
                  pfad={pfad}
                  person={person}
                  seit={seit(person.joinedAt, daten.zeitzone)}
                />
              ))}
            </Zeilen>
            {weitere > 0 ? (
              // Serverseitig gekuerzt, serverseitig aufgeklappt: ein
              // gewoehnlicher Link auf ?alle=1, kein Zustand im Browser.
              //
              // Hier bleibt es ein <Link>. Das Termindetail traegt
              // denselben Kuerzungs-Link und musste am 6. September auf
              // ein <a> wechseln, weil Nexts Client-Router ihn im
              // Produktionsbau ins Leere laufen liess -- gemessen und
              // nachgestellt. Diese Stelle ist gegen denselben Bau
              // geprueft und geht durch; der Unterschied ist die Route,
              // nicht das Muster (dort ein dynamisches Blattsegment,
              // hier nicht). Wer das aendert, prueft es gegen
              // `next start`, nicht gegen `next dev`.
              <div className={styles.rowActions}>
                <span className={styles.absent}>… {weitere} weitere</span>
                <Link href={`${pfad}?alle=1`} className={styles.secondary}>
                  Alle anzeigen
                </Link>
              </div>
            ) : null}
          </>
        )}
      </Abschnitt>

      <Erlaeuterung>
        Mitglieder treten über den Studio-Code bei —{" "}
        <Link href={`/portal/${studioId}/einstellungen`}>Einstellungen</Link>
      </Erlaeuterung>
      <Erlaeuterung>
        Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das Portal legt
        eine Mitgliedschaft an und beendet sie, sonst nichts.
      </Erlaeuterung>
    </Seite>
  );
}
