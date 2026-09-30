/**
 * Die Werte aus dem Format-Vertrag
 * (docs/superpowers/specs/2026-09-14-testnotiz-format.md). Dieselben
 * Schluessel wie in der iOS-Fassung (`TestnotizEintrag.swift`), weil der
 * Ordner ein Vertrag zwischen Plattformen ist, kein Oberflaechentext.
 *
 * Zeitpunkte sind Zeichenketten, keine Date-Objekte: der Browser kennt die
 * Zeitzone des Testers, der Server nicht zwingend dieselbe. Wer die Uhrzeit
 * erzeugt, schreibt sie samt Offset -- gelesen wird danach nur noch mit
 * Zeichenkettenmitteln (`zeit.ts`).
 */

/**
 * `/2` statt `/1`: seit dem Handy-Weg kann ein Eintrag ohne Bild entstehen
 * (Nur Notiz, ohne angehaengten Screenshot), `screenshot` ist also nullbar.
 * Das bricht einen strikten Leser des alten Vertrags, deshalb die neue Zahl.
 * iOS schreibt unveraendert `/1`; beide Ordner sehen in `sitzung.md` gleich
 * aus.
 */
export const FORMAT_KENNUNG = "gymodo.testnotiz/2";
export const PLATTFORM = "web";

/** ISO 8601 mit Offset, ohne Sekundenbruchteile: `2026-09-21T14:12:03+02:00`. */
export type Zeitpunkt = string;

export type Art = "crop" | "element" | "note";

export type Rechteck = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type Ausschnittsrahmen = {
  points: Rechteck;
  pixels: Rechteck;
};

export type Screen = {
  name: string;
  file: string;
  stack: string[];
  context: Record<string, string>;
};

export type ElementAngabe = {
  /** Web meldet `dom`; iOS `accessibility`, Android `semantics`. */
  source: "accessibility" | "semantics" | "dom";
  identifier: string | null;
  label: string | null;
  type: string;
  frame: Rechteck;
  file: string | null;
  line: number | null;
};

export type Laufzeit = {
  online: boolean;
  pendingWrites: number;
  signedIn: boolean;
  studioId: string | null;
};

export type Protokollzeile = {
  at: Zeitpunkt;
  level: "debug" | "info" | "notice" | "error" | "fault" | "undefined";
  category: string;
  message: string;
};

export type Eintrag = {
  id: string;
  index: number;
  createdAt: Zeitpunkt;
  kind: Art;
  screen: Screen | null;
  /** `null`, wenn kein Bild zustande kam -- am Handy ist das Anhaengen freiwillig. */
  screenshot: string | null;
  crop: string | null;
  cropRect: Ausschnittsrahmen | null;
  element: ElementAngabe | null;
  note: string | null;
  audio: string | null;
  transcript: string | null;
  runtime: Laufzeit;
  log: Protokollzeile[];
};

export type Sitzungskopf = {
  id: string;
  startedAt: Zeitpunkt;
  app: {
    bundleId: string;
    version: string;
    build: string;
    configuration: string;
  };
  device: {
    model: string;
    os: string;
    screen: { width: number; height: number; scale: number };
  };
};

export type Sitzung = {
  format: string;
  platform: string;
  session: Sitzungskopf;
  entries: Eintrag[];
};

/**
 * Was der Browser beim Sichern schickt: der Eintrag ohne die Felder, die
 * erst die Ablage vergibt (Nummer, Dateinamen, Screen) und ohne die beiden
 * Sprachfelder, die das Portal nie fuellt.
 */
export type Eintragsentwurf = Omit<
  Eintrag,
  "index" | "screenshot" | "crop" | "screen" | "audio" | "transcript"
>;

/**
 * Wie `JSONEncoder.testnotiz` auf iOS: eingerueckt und mit sortierten
 * Schluesseln. Sortiert wird, damit zwei Einträge nacheinander einen
 * lesbaren Unterschied ergeben und nicht eine umsortierte Datei.
 */
export function sitzungJson(sitzung: Sitzung): string {
  return JSON.stringify(sortiert(sitzung), null, 2) + "\n";
}

function sortiert(wert: unknown): unknown {
  if (Array.isArray(wert)) return wert.map(sortiert);
  if (wert === null || typeof wert !== "object") return wert;
  const quelle = wert as Record<string, unknown>;
  const ziel: Record<string, unknown> = {};
  for (const schluessel of Object.keys(quelle).sort()) {
    ziel[schluessel] = sortiert(quelle[schluessel]);
  }
  return ziel;
}
