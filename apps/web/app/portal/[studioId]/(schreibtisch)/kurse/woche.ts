import { ortszeitTeile, ortszeitZuInstant } from "@fitretro/domain";
import type { CourseWeekSession } from "@fitretro/domain";

/**
 * Die Wochenrechnung der Kursuebersicht.
 *
 * Sie rechnet auf der Wanduhr des Studios, nicht auf dem Zeitstrahl --
 * aus demselben Grund wie serie.ts: die Woche mit der Zeitumstellung ist
 * 169 oder 167 Stunden lang, und sie umfasst trotzdem genau sieben Tage.
 *
 * Der Anker ist ein Datum in der URL (?woche=2026-09-03), damit ein
 * Neuladen und ein Lesezeichen dieselbe Woche zeigen. Kein Client-State.
 */

const WOCHENTAGE = [
  "Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag",
] as const;

const MONATE = [
  "Januar", "Februar", "März", "April", "Mai", "Juni",
  "Juli", "August", "September", "Oktober", "November", "Dezember",
] as const;

const KURZTAGE = ["So.", "Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa."] as const;

/** Der Wochentag eines Ortsdatums, 0 = Sonntag. */
function wochentag(jahr: number, monat: number, tag: number): number {
  return new Date(Date.UTC(jahr, monat - 1, tag)).getUTCDay();
}

function datumTeile(iso: string): { jahr: number; monat: number; tag: number } {
  const [jahr, monat, tag] = iso.split("-").map(Number);
  return { jahr: jahr!, monat: monat!, tag: tag! };
}

function alsIsoDatum(jahr: number, monat: number, tag: number): string {
  const d = new Date(Date.UTC(jahr, monat - 1, tag));
  return d.toISOString().slice(0, 10);
}

export type Wochenfenster = {
  von: string;
  bis: string;
  vorige: string;
  naechste: string;
  titel: string;
};

/**
 * Das Fenster von Montag 00:00 Ortszeit bis zum darauffolgenden Montag
 * 00:00 Ortszeit. Beide Grenzen sind echte Zeitpunkte -- course_week
 * vergleicht gegen starts_at, und das ist timestamptz.
 */
const ANKER_FORM = /^\d{4}-\d{2}-\d{2}$/;

export function wochenFenster(anker: string | undefined, zeitzone: string): Wochenfenster {
  // ?woche=abc erreicht diese Funktion AUSSERHALB des try/catch von
  // page.tsx -- datumTeile("abc") liefert NaN fuer alle drei Felder,
  // wochentag baut daraus ein Invalid Date, und sowohl
  // Intl.DateTimeFormat.formatToParts als auch toISOString werfen dann
  // einen rohen RangeError. Diese Anwendung hat kein error.tsx, also
  // laendet das auf Nexts Standard-Fehlerseite. Ein verunstaltetes
  // Lesezeichen soll diese Woche zeigen, keinen Fehler.
  const gueltigerAnker = anker !== undefined && ANKER_FORM.test(anker) ? anker : undefined;
  const heute = gueltigerAnker ?? ortszeitAlsDatum(new Date(), zeitzone);
  const { jahr, monat, tag } = datumTeile(heute);

  // Montag als Wochenanfang: Sonntag (0) ist der siebte Tag, nicht der erste.
  const versatz = (wochentag(jahr, monat, tag) + 6) % 7;
  const montag = new Date(Date.UTC(jahr, monat - 1, tag - versatz));
  const sonntag = new Date(Date.UTC(jahr, monat - 1, tag - versatz + 6));

  const von = ortszeitZuInstant(
    {
      jahr: montag.getUTCFullYear(),
      monat: montag.getUTCMonth() + 1,
      tag: montag.getUTCDate(),
      stunde: 0,
      minute: 0,
    },
    zeitzone,
  );
  const bis = ortszeitZuInstant(
    {
      jahr: sonntag.getUTCFullYear(),
      monat: sonntag.getUTCMonth() + 1,
      tag: sonntag.getUTCDate() + 1,
      stunde: 0,
      minute: 0,
    },
    zeitzone,
  );

  return {
    von: von.toISOString(),
    bis: bis.toISOString(),
    vorige: alsIsoDatum(montag.getUTCFullYear(), montag.getUTCMonth() + 1, montag.getUTCDate() - 7),
    naechste: alsIsoDatum(montag.getUTCFullYear(), montag.getUTCMonth() + 1, montag.getUTCDate() + 7),
    titel:
      `${KURZTAGE[1]}, ${montag.getUTCDate()}. ${MONATE[montag.getUTCMonth()]} – ` +
      `${KURZTAGE[0]}, ${sonntag.getUTCDate()}. ${MONATE[sonntag.getUTCMonth()]} ${sonntag.getUTCFullYear()}`,
  };
}

/** Heute, als Ortsdatum des Studios. */
export function ortszeitAlsDatum(zeitpunkt: Date, zeitzone: string): string {
  const t = ortszeitTeile(zeitpunkt, zeitzone);
  return alsIsoDatum(t.jahr, t.monat, t.tag);
}

export type Tagesgruppe = {
  localDay: string;
  ueberschrift: string;
  sessions: CourseWeekSession[];
};

/**
 * Sieben Gruppen, immer. Ein Tag ohne Kurse sagt "Keine Kurse" (so das
 * Artboard) -- der Leer-Zustand gehoert an den Tag, nicht an die Woche.
 */
export function nachTagenGruppieren(
  sessions: CourseWeekSession[],
  von: string,
  zeitzone: string,
): Tagesgruppe[] {
  const start = ortszeitTeile(new Date(von), zeitzone);
  const gruppen: Tagesgruppe[] = [];

  for (let i = 0; i < 7; i += 1) {
    const tag = new Date(Date.UTC(start.jahr, start.monat - 1, start.tag + i));
    const localDay = tag.toISOString().slice(0, 10);
    gruppen.push({
      localDay,
      ueberschrift:
        `${WOCHENTAGE[tag.getUTCDay()]}, ${tag.getUTCDate()}. ${MONATE[tag.getUTCMonth()]}`,
      // Zugeordnet wird nach local_day aus der Datenbank -- nie nach dem
      // UTC-Tag von starts_at. Ein Kurs um 00:30 Ortszeit gehoert auf
      // seinen Ortstag, auch wenn er in UTC noch am Vortag liegt.
      sessions: sessions.filter((s) => s.localDay === localDay),
    });
  }

  return gruppen;
}

/** "18:00" in der Zeitzone des Studios. */
export function uhrzeit(startsAt: string, zeitzone: string): string {
  const t = ortszeitTeile(new Date(startsAt), zeitzone);
  return `${String(t.stunde).padStart(2, "0")}:${String(t.minute).padStart(2, "0")}`;
}
