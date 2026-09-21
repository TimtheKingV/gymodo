import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import {
  FORMAT_KENNUNG,
  PLATTFORM,
  type Eintrag,
  type Eintragsentwurf,
  type Screen,
  type Sitzung,
  type Sitzungskopf,
  sitzungJson,
} from "./format";
import { rendern } from "./markdown";
import { ordnername } from "./zeit";

/**
 * Ein Sitzungsordner auf der Platte -- dieselbe Aufgabe wie der `actor`
 * `TestnotizAblage` auf iOS, hier im Dev-Server.
 *
 * Der Zustand liegt in der Datei, nicht im Prozess: `sitzung.json` ist die
 * Wahrheit ueber Nummer und Anzahl. Ein Neuladen der Seite -- im Browser die
 * Regel, nicht die Ausnahme -- setzt die Sitzung deshalb fort, und ein
 * Neustart des Dev-Servers ebenfalls.
 */

export const SITZUNGSKENNUNG = /^\d{4}-\d{2}-\d{2}-\d{4}(-\d+)?$/;

/** Zwei schnelle Einträge bekaemen sonst dieselbe Nummer. */
let kette: Promise<unknown> = Promise.resolve();

function nacheinander<T>(arbeit: () => Promise<T>): Promise<T> {
  const naechste = kette.then(arbeit, arbeit);
  kette = naechste.catch(() => undefined);
  return naechste;
}

export async function sitzungAnlegen(wurzel: string, kopf: Sitzungskopf): Promise<Sitzung> {
  return nacheinander(async () => {
    await mkdir(wurzel, { recursive: true });
    const basis = ordnername(kopf.startedAt);
    const belegt = new Set(await readdir(wurzel).catch(() => []));
    let id = basis;
    let zaehler = 2;
    while (belegt.has(id)) {
      id = `${basis}-${zaehler}`;
      zaehler += 1;
    }
    await mkdir(path.join(wurzel, id));
    const sitzung: Sitzung = {
      format: FORMAT_KENNUNG,
      platform: PLATTFORM,
      session: { ...kopf, id },
      entries: [],
    };
    await sitzungSchreiben(wurzel, sitzung);
    return sitzung;
  });
}

export async function sitzungLesen(wurzel: string, id: string): Promise<Sitzung | null> {
  if (!SITZUNGSKENNUNG.test(id)) return null;
  try {
    const roh = await readFile(path.join(wurzel, id, "sitzung.json"), "utf8");
    return JSON.parse(roh) as Sitzung;
  } catch {
    return null;
  }
}

/**
 * Vergibt Nummer und Dateinamen, schreibt die Bilder und danach
 * `sitzung.json` und `sitzung.md` neu.
 */
export async function eintragSchreiben(
  wurzel: string,
  id: string,
  entwurf: Eintragsentwurf,
  screen: Screen | null,
  voll: Uint8Array,
  ausschnitt: Uint8Array | null,
): Promise<{ eintrag: Eintrag; anzahl: number }> {
  return nacheinander(async () => {
    const sitzung = await sitzungLesen(wurzel, id);
    if (!sitzung) throw new Error(`Sitzung ${id} gibt es nicht.`);
    const ordner = path.join(wurzel, id);

    const index = sitzung.entries.length + 1;
    const praefix = String(index).padStart(2, "0");

    const vollname = `${praefix}-voll.png`;
    await writeFile(path.join(ordner, vollname), voll);

    let ausschnittname: string | null = null;
    if (ausschnitt) {
      ausschnittname = `${praefix}-ausschnitt.png`;
      await writeFile(path.join(ordner, ausschnittname), ausschnitt);
    }

    const eintrag: Eintrag = {
      ...entwurf,
      index,
      screen,
      screenshot: vollname,
      crop: ausschnittname,
      // Sprachnotizen gibt es im Portal nicht -- die Felder bleiben Teil des
      // Vertrags und stehen auf null.
      audio: null,
      transcript: null,
    };

    sitzung.entries.push(eintrag);
    await sitzungSchreiben(wurzel, sitzung);
    return { eintrag, anzahl: sitzung.entries.length };
  });
}

async function sitzungSchreiben(wurzel: string, sitzung: Sitzung): Promise<void> {
  const ordner = path.join(wurzel, sitzung.session.id);
  await writeFile(path.join(ordner, "sitzung.json"), sitzungJson(sitzung), "utf8");
  await writeFile(path.join(ordner, "sitzung.md"), rendern(sitzung), "utf8");
}
