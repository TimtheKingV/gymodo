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
  /** Der Montag als Ortsdatum -- Anfang des Wochenstreifens. */
  montag: string;
  /** "2026-09": der Monat, den der Umschalter "Monat" oeffnet. */
  monat: string;
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
  // einen rohen RangeError. Seit Aufgabe 4 faengt error.tsx der
  // Schreibtisch-Gruppe das ab -- aber ein verunstaltetes Lesezeichen
  // soll diese Woche zeigen, nicht die Fehlerseite.
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

  // Der Monat einer Woche ist der ihres Donnerstags: dort liegen immer
  // mindestens vier der sieben Tage. Mo 31. August bis So 6. September
  // oeffnet so den September, nicht den August mit einem einzigen Tag.
  const donnerstag = new Date(Date.UTC(jahr, monat - 1, tag - versatz + 3));

  return {
    von: von.toISOString(),
    bis: bis.toISOString(),
    montag: montag.toISOString().slice(0, 10),
    monat: donnerstag.toISOString().slice(0, 7),
    vorige: alsIsoDatum(montag.getUTCFullYear(), montag.getUTCMonth() + 1, montag.getUTCDate() - 7),
    naechste: alsIsoDatum(montag.getUTCFullYear(), montag.getUTCMonth() + 1, montag.getUTCDate() + 7),
    titel:
      `${KURZTAGE[1]}, ${montag.getUTCDate()}. ${MONATE[montag.getUTCMonth()]} – ` +
      `${KURZTAGE[0]}, ${sonntag.getUTCDate()}. ${MONATE[sonntag.getUTCMonth()]} ${sonntag.getUTCFullYear()}`,
  };
}

export type Monatsfenster = {
  von: string;
  bis: string;
  /** Der Montag, mit dem das Raster beginnt -- oft noch im Vormonat. */
  erster: string;
  /** 35 oder 42: volle Wochen, damit das Raster ein Rechteck bleibt. */
  tage: number;
  monat: string;
  vorige: string;
  naechste: string;
  titel: string;
};

const MONAT_FORM = /^(\d{4})-(0[1-9]|1[0-2])$/;

/**
 * Die Monatsansicht (Testnotiz 25.09., #1): Montag vor dem Ersten bis
 * Sonntag nach dem Letzten, wie ein Wandkalender. Gerechnet auf der
 * Wanduhr wie wochenFenster, aus demselben Grund. Anker ist "?monat=2026-09";
 * ein unlesbarer faellt auf den aktuellen Monat zurueck.
 */
export function monatsFenster(anker: string | undefined, zeitzone: string): Monatsfenster {
  const treffer = anker === undefined ? null : MONAT_FORM.exec(anker);
  const heute = datumTeile(ortszeitAlsDatum(new Date(), zeitzone));
  const jahr = treffer ? Number(treffer[1]) : heute.jahr;
  const monat = treffer ? Number(treffer[2]) : heute.monat;

  const letzterTag = new Date(Date.UTC(jahr, monat, 0)).getUTCDate();
  const vorErstem = (wochentag(jahr, monat, 1) + 6) % 7;
  const nachLetztem = (7 - ((wochentag(jahr, monat, letzterTag) + 6) % 7) - 1) % 7;
  const tage = vorErstem + letzterTag + nachLetztem;

  const erster = new Date(Date.UTC(jahr, monat - 1, 1 - vorErstem));
  const ende = new Date(Date.UTC(jahr, monat - 1, letzterTag + nachLetztem + 1));
  const alsInstant = (d: Date) =>
    ortszeitZuInstant(
      {
        jahr: d.getUTCFullYear(),
        monat: d.getUTCMonth() + 1,
        tag: d.getUTCDate(),
        stunde: 0,
        minute: 0,
      },
      zeitzone,
    ).toISOString();
  const monatsName = (versatz: number) =>
    new Date(Date.UTC(jahr, monat - 1 + versatz, 1)).toISOString().slice(0, 7);

  return {
    von: alsInstant(erster),
    bis: alsInstant(ende),
    erster: erster.toISOString().slice(0, 10),
    tage,
    monat: monatsName(0),
    vorige: monatsName(-1),
    naechste: monatsName(1),
    titel: `${MONATE[monat - 1]} ${jahr}`,
  };
}

/** Wie in der App (KurseWochentag.buchstabe): der schmalste Name. */
const BUCHSTABEN = ["S", "M", "D", "M", "D", "F", "S"] as const;

export type Kalendertag = {
  iso: string;
  buchstabe: string;
  nummer: number;
  /** "Dienstag, 1. September" -- fuer Screenreader, wie die Ueberschriften. */
  name: string;
  istHeute: boolean;
  /** Stattfindende Kurse -- ein abgesagter ist kein Grund hinzusehen. */
  kurse: number;
  imMonat: boolean;
};

/**
 * Die Zellen von Wochenstreifen und Monatsraster, ab einem Ortsdatum.
 * Zugeordnet wird wie in nachTagenGruppieren ueber local_day.
 */
export function kalenderTage(
  start: string,
  anzahl: number,
  heute: string,
  sessions: { localDay: string; status: string }[],
  monat?: string,
): Kalendertag[] {
  const { jahr, monat: m, tag } = datumTeile(start);
  return Array.from({ length: anzahl }, (_, i) => {
    const d = new Date(Date.UTC(jahr, m - 1, tag + i));
    const iso = d.toISOString().slice(0, 10);
    return {
      iso,
      buchstabe: BUCHSTABEN[d.getUTCDay()]!,
      nummer: d.getUTCDate(),
      name: `${WOCHENTAGE[d.getUTCDay()]}, ${d.getUTCDate()}. ${MONATE[d.getUTCMonth()]}`,
      istHeute: iso === heute,
      kurse: sessions.filter((s) => s.localDay === iso && s.status !== "cancelled").length,
      imMonat: monat === undefined || iso.startsWith(monat),
    };
  });
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
