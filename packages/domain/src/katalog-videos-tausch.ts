import { MAX_VIDEO_SECONDS, readVideoDurationSeconds } from "./media.js";

/**
 * Neue Uebungsvideos in den Katalog einspielen (KI-Loops statt
 * Strichzeichnungen). Die Laenge kommt aus derselben Funktion wie beim
 * Katalog-Import: der lehnt jede andere Angabe ab.
 */

export type Datei = { key: string; bytes: Uint8Array };
export type VideoEintrag = { file: string; duration_s: number };
type KatalogUebung = { key: string; volume_kind: "reps" | "seconds"; video: VideoEintrag | null };

export type Plan =
  | { ok: true; eintraege: Map<string, VideoEintrag>; neu: string[]; ersetzt: string[] }
  | { ok: false; fehler: string[] };

/** Rechnet aus Katalog und Dateien die neuen video-Eintraege. Sammelt alle Fehler. */
export function plane(exercises: KatalogUebung[], dateien: Datei[]): Plan {
  const fehler: string[] = [];
  const eintraege = new Map<string, VideoEintrag>();
  const neu: string[] = [];
  const ersetzt: string[] = [];
  const nachKey = new Map(exercises.map((u) => [u.key, u]));

  for (const d of dateien) {
    const u = nachKey.get(d.key);
    if (!u) {
      fehler.push(`${d.key}: keine Uebung mit diesem Schluessel im Katalog`);
      continue;
    }
    if (u.volume_kind !== "reps") {
      fehler.push(`${d.key}: Uebung mit Zeitvorgabe behaelt ihr Video`);
      continue;
    }
    const dauer = readVideoDurationSeconds(d.bytes);
    if (dauer === null) {
      fehler.push(`${d.key}: Laenge nicht lesbar`);
      continue;
    }
    if (dauer < 1 || dauer > MAX_VIDEO_SECONDS) {
      fehler.push(`${d.key}: ${dauer} s liegt ausserhalb von 1 bis ${MAX_VIDEO_SECONDS} s`);
      continue;
    }
    eintraege.set(d.key, { file: `media/videos/${d.key}.mp4`, duration_s: dauer });
    (u.video === null ? neu : ersetzt).push(d.key);
  }
  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, eintraege, neu, ersetzt };
}

function videoText(e: VideoEintrag): string {
  return `"video": {\n        "file": ${JSON.stringify(e.file)},\n        "duration_s": ${e.duration_s}\n      }`;
}

/**
 * Setzt die video-Felder der genannten Uebungen direkt im Katalogtext und
 * laesst alles andere zeichengleich (die Datei ist von Hand gesetzt, ein
 * Neuschreiben ueber JSON.stringify wuerde sie ueberall umbrechen).
 */
export function setzeVideos(text: string, eintraege: Map<string, VideoEintrag>): string {
  const start = text.indexOf('"exercises": [');
  if (start < 0) throw new Error("Katalogtext hat keinen Abschnitt exercises");
  const kopf = text.slice(0, start);
  const rest = text.slice(start);
  const gesehen = new Set<string>();
  const teile = rest.split(/(?=^ {6}"key": ")/m);
  const ergebnis = teile.map((teil) => {
    const m = /^ {6}"key": "([^"]+)"/.exec(teil);
    const e = m ? eintraege.get(m[1]!) : undefined;
    if (!m || !e) return teil;
    gesehen.add(m[1]!);
    return teil.replace(/"video": (?:null|\{[^}]*\})/, () => videoText(e));
  });
  const fehlend = [...eintraege.keys()].filter((k) => !gesehen.has(k));
  if (fehlend.length > 0) throw new Error(`Nicht im Katalogtext gefunden: ${fehlend.join(", ")}`);
  return kopf + ergebnis.join("");
}
