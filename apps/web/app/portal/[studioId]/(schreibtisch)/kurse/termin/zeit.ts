import { ortszeitTeile, ortszeitZuInstant, type Ortszeit } from "@fitretro/domain/serie";

/**
 * Datum und Uhrzeit als zwei Felder -- und der Weg von dort zum Augenblick.
 *
 * Beide Termin-Bildschirme brauchen dieselbe Rechnung. TerminAnlegen.dc.html
 * und Termin.dc.html zeichnen "Datum" und "Uhrzeit" als getrennte Felder;
 * der Server bekommt daraus einen ISO-Zeitpunkt MIT Zone, nie die nackte
 * Wandzeit -- sonst deutet er sie in seiner eigenen Zeitzone (Designsystem
 * 10). Das Modul ist bewusst frei von "use client" und von Serverimporten:
 * beide Formulare rechnen im Browser mit, waehrend getippt wird.
 */

function zwei(zahl: number): string {
  return String(zahl).padStart(2, "0");
}

/** "2026-09-03" plus Stunde und Minute -- als Wanduhr des Studios gelesen. */
export function alsOrtszeit(datum: string, stunde: number, minute: number): Ortszeit | null {
  const treffer = /^(\d{4})-(\d{2})-(\d{2})$/.exec(datum);
  if (!treffer) return null;
  return {
    jahr: Number(treffer[1]),
    monat: Number(treffer[2]),
    tag: Number(treffer[3]),
    stunde,
    minute,
  };
}

/**
 * Aus den beiden Feldwerten der Augenblick.
 *
 * Die Felder liefern eine nackte Wandzeit ohne Zone ("2026-11-05", "18:00").
 * new Date() deutete die in der Zone des BROWSERS -- die Serienrechnung und
 * der Server lesen aber die Wandzeit des STUDIOS. Sitzt der Trainer in einer
 * anderen Zone als sein Studio, entstuende ein anderer Termin als der
 * getippte.
 */
export function feldZuInstant(
  datum: string,
  uhrzeit: string,
  zeitzone: string,
): Date | null {
  const treffer = /^(\d{2}):(\d{2})/.exec(uhrzeit);
  if (!treffer) return null;
  const teile = alsOrtszeit(datum, Number(treffer[1]), Number(treffer[2]));
  return teile === null ? null : ortszeitZuInstant(teile, zeitzone);
}

/** Der umgekehrte Weg: ein gespeicherter Zeitpunkt in die beiden Felder. */
export function feldwerte(
  iso: string,
  zeitzone: string,
): { datum: string; uhrzeit: string } {
  const t = ortszeitTeile(new Date(iso), zeitzone);
  return {
    datum: `${t.jahr}-${zwei(t.monat)}-${zwei(t.tag)}`,
    uhrzeit: `${zwei(t.stunde)}:${zwei(t.minute)}`,
  };
}

/** "Do., 3. September 2026" -- der Wortlaut beider Artboards. */
export function langesDatum(zeitpunkt: Date, zeitzone: string): string {
  return zeitpunkt.toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: zeitzone,
  });
}

/** "Do., 3. September 2026 · 18:00" -- eine Zeile der Serienvorschau. */
export function tagUndZeit(zeitpunkt: Date, zeitzone: string): string {
  const t = ortszeitTeile(zeitpunkt, zeitzone);
  return `${langesDatum(zeitpunkt, zeitzone)} · ${zwei(t.stunde)}:${zwei(t.minute)}`;
}
