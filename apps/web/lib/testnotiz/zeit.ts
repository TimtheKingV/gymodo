/**
 * Zeitpunkte des Formats, ohne Locale und ohne Zeitzonenbibliothek.
 *
 * `zeitstempel` ist die einzige Stelle, die eine `Date` anfasst; alles
 * danach rechnet auf der Zeichenkette. Das haelt Ordnername, Kopfzeile und
 * Protokollzeile in derselben Zeitzone wie die Aufnahme -- auch dann, wenn
 * der Dev-Server spaeter in einer anderen steht als der Browser.
 */

import type { Zeitpunkt } from "./format";

function zwei(zahl: number): string {
  return String(Math.trunc(Math.abs(zahl))).padStart(2, "0");
}

/**
 * ISO 8601 mit Offset, ohne Sekundenbruchteile. Ohne zweites Argument gilt
 * die Zeitzone der laufenden Umgebung; Tests geben sie an.
 */
export function zeitstempel(
  datum: Date,
  offsetMinuten: number = -datum.getTimezoneOffset(),
): Zeitpunkt {
  const oertlich = new Date(datum.getTime() + offsetMinuten * 60_000);
  const datumsteil = [
    String(oertlich.getUTCFullYear()).padStart(4, "0"),
    zwei(oertlich.getUTCMonth() + 1),
    zwei(oertlich.getUTCDate()),
  ].join("-");
  const zeitteil = [
    zwei(oertlich.getUTCHours()),
    zwei(oertlich.getUTCMinutes()),
    zwei(oertlich.getUTCSeconds()),
  ].join(":");
  const vorzeichen = offsetMinuten < 0 ? "-" : "+";
  const offset = `${vorzeichen}${zwei(offsetMinuten / 60)}:${zwei(offsetMinuten % 60)}`;
  return `${datumsteil}T${zeitteil}${offset}`;
}

/** `2026-09-21T14:12:03+02:00` -> `2026-09-21-1412`, der Ordnername. */
export function ordnername(zeitpunkt: Zeitpunkt): string {
  return `${zeitpunkt.slice(0, 10)}-${zeitpunkt.slice(11, 13)}${zeitpunkt.slice(14, 16)}`;
}

/** `14:12`, mit `sekunden` `14:12:03`. */
export function uhrzeit(zeitpunkt: Zeitpunkt, sekunden = false): string {
  return zeitpunkt.slice(11, sekunden ? 19 : 16);
}

/** `2026-09-21 14:12` fuer die Kopfzeile von `sitzung.md`. */
export function datumUhrzeit(zeitpunkt: Zeitpunkt): string {
  return `${zeitpunkt.slice(0, 10)} ${uhrzeit(zeitpunkt)}`;
}
