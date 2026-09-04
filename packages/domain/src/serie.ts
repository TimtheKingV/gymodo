/**
 * Die Serienrechnung, Spec 2026-09-03-kurse-design.md Abschnitt 9.
 *
 * Serientermine werden beim Anlegen AUSGESCHRIEBEN, nicht als Regel
 * gespeichert -- eine Wiederholungsregel, die man spaeter aufloesen muss,
 * ist der klassische Kalendersumpf. Diese Datei erzeugt die Zeitpunkte.
 *
 * Die ganze Schwierigkeit ist die Sommerzeit. Ein Kurs, der donnerstags
 * um 18:00 Ortszeit stattfindet, findet auch nach der Umstellung um 18:00
 * Ortszeit statt; sieben mal 24 Stunden auf einen Zeitpunkt zu addieren
 * ergaebe ab dem letzten Oktobersonntag 17:00. Gerechnet wird deshalb auf
 * der Wanduhr des Studios und erst danach auf dem Zeitstrahl.
 *
 * Bewusst ohne Bibliothek und ohne node:-Import: Intl kann alles
 * Noetige, und die Datei muss auch im Browserbundle tragbar bleiben --
 * die Serienvorschau rechnet im Client mit.
 */

/**
 * Mehr als zwei Jahre woechentlich legt niemand mit Absicht an. Die
 * Grenze ist eine Ergonomiegrenze, keine fachliche: sie faengt den
 * vertippten Jahreszahl-Fall ab, bevor 500 Zeilen entstehen, die einzeln
 * abgesagt werden muessten.
 */
export const MAX_SERIENTERMINE = 104;

export type Ortszeit = {
  jahr: number;
  monat: number;
  tag: number;
  stunde: number;
  minute: number;
};

const felder = {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
} as const;

function teileRoh(zeitpunkt: Date, zeitzone: string): Record<string, number> {
  const formatierer = new Intl.DateTimeFormat("en-US", {
    timeZone: zeitzone,
    hour12: false,
    ...felder,
  });
  const teile: Record<string, number> = {};
  for (const { type, value } of formatierer.formatToParts(zeitpunkt)) {
    if (type in felder || type === "second") teile[type] = Number(value);
  }
  // hourCycle h23 liefert fuer Mitternacht je nach Umgebung 24 statt 0.
  if (teile.hour === 24) teile.hour = 0;
  return teile;
}

/** Was die Wanduhr dieser Zeitzone in diesem Augenblick zeigt. */
export function ortszeitTeile(zeitpunkt: Date, zeitzone: string): Ortszeit {
  const t = teileRoh(zeitpunkt, zeitzone);
  return {
    jahr: t.year!,
    monat: t.month!,
    tag: t.day!,
    stunde: t.hour!,
    minute: t.minute!,
  };
}

/**
 * Der Versatz dieser Zeitzone zu UTC in diesem Augenblick, in
 * Millisekunden. Positiv oestlich von Greenwich.
 */
export function zonenVersatzMs(zeitpunkt: Date, zeitzone: string): number {
  const t = teileRoh(zeitpunkt, zeitzone);
  const alsWaereEsUtc = Date.UTC(t.year!, t.month! - 1, t.day!, t.hour!, t.minute!, t.second!);
  // Die Millisekunden fallen bei formatToParts weg -- sie stehen auf
  // beiden Seiten gleich und kuerzen sich aus der Differenz heraus.
  return alsWaereEsUtc - (zeitpunkt.getTime() - (zeitpunkt.getTime() % 1000));
}

/**
 * Aus einer Wandzeit den Augenblick machen.
 *
 * Zwei Durchgaenge, und der zweite ist kein Schoenheitsfehler: der erste
 * Versatz wird an einem noch falschen Augenblick gemessen. Liegt die
 * gesuchte Wandzeit auf der anderen Seite einer Umstellung, ist er um
 * eine Stunde daneben -- der zweite Durchgang misst am korrigierten
 * Augenblick nach und rechnet damit erneut.
 */
export function ortszeitZuInstant(teile: Ortszeit, zeitzone: string): Date {
  const alsWaereEsUtc = Date.UTC(
    teile.jahr,
    teile.monat - 1,
    teile.tag,
    teile.stunde,
    teile.minute,
    0,
  );

  const ersterVersatz = zonenVersatzMs(new Date(alsWaereEsUtc), zeitzone);
  const ersterVersuch = new Date(alsWaereEsUtc - ersterVersatz);

  const zweiterVersatz = zonenVersatzMs(ersterVersuch, zeitzone);
  if (zweiterVersatz === ersterVersatz) return ersterVersuch;

  return new Date(alsWaereEsUtc - zweiterVersatz);
}

/** Der Ortstag als vergleichbare Zahl: 2026-10-22 wird 20261022. */
function ortstagSchluessel(zeitpunkt: Date, zeitzone: string): number {
  const t = ortszeitTeile(zeitpunkt, zeitzone);
  return t.jahr * 10_000 + t.monat * 100 + t.tag;
}

/**
 * Woechentliche Termine von `start` bis einschliesslich des ORTSTAGS von
 * `bis`.
 *
 * Auf den Ortstag und nicht auf den Zeitpunkt, weil der Trainer im
 * Formular ein Datum waehlt und keine Uhrzeit: "bis Do., 3. Dezember"
 * heisst, dass der 3. Dezember dazugehoert -- auch wenn das Feld intern
 * Mitternacht mitbringt.
 *
 * `start` ist immer dabei, auch wenn `bis` davor liegt: ein Termin ohne
 * Wiederholung ist eine Serie aus einem.
 */
export function serienTermine(start: Date, bis: Date, zeitzone: string): Date[] {
  const wand = ortszeitTeile(start, zeitzone);
  const grenze = ortstagSchluessel(bis, zeitzone);

  const termine: Date[] = [];
  for (let woche = 0; woche < MAX_SERIENTERMINE; woche += 1) {
    // Auf der Wanduhr rechnen: Date.UTC normalisiert einen Tagesueberlauf
    // (der 38. Oktober wird der 7. November), und weil hier nur Kalender-
    // felder bewegt werden, bleibt die Uhrzeit unberuehrt.
    const kalender = new Date(
      Date.UTC(wand.jahr, wand.monat - 1, wand.tag + woche * 7),
    );
    const termin = ortszeitZuInstant(
      {
        jahr: kalender.getUTCFullYear(),
        monat: kalender.getUTCMonth() + 1,
        tag: kalender.getUTCDate(),
        stunde: wand.stunde,
        minute: wand.minute,
      },
      zeitzone,
    );

    if (woche > 0 && ortstagSchluessel(termin, zeitzone) > grenze) break;
    termine.push(termin);
  }

  return termine;
}
