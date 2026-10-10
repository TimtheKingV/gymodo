import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pruefeKatalog, type KatalogDatei, type Pruefung } from "./katalog-datei.js";
import { pruefeMedien, type Medien } from "./katalog-medien.js";

export type GeladenerKatalog = { katalog: KatalogDatei; medien: Medien };

/**
 * Liest die Katalogdatei von der Platte. Medienpfade gelten relativ zur
 * Datei, nicht zum Arbeitsverzeichnis -- sonst haengt das Ergebnis davon ab,
 * aus welchem Ordner jemand das Skript startet.
 */
export function ladeKatalog(datei: string): Pruefung<GeladenerKatalog> {
  let inhalt: string;
  try {
    inhalt = readFileSync(datei, "utf8");
  } catch {
    return { ok: false, fehler: [`${datei}: Datei nicht lesbar`] };
  }

  let roh: unknown;
  try {
    roh = JSON.parse(inhalt);
  } catch (fehler) {
    return { ok: false, fehler: [`${datei}: kein gueltiges JSON (${(fehler as Error).message})`] };
  }

  const pruefung = pruefeKatalog(roh);
  if (!pruefung.ok) return pruefung;

  const basis = dirname(resolve(datei));
  const medien = pruefeMedien(pruefung.wert, (pfad) => {
    try {
      return new Uint8Array(readFileSync(resolve(basis, pfad)));
    } catch {
      return null;
    }
  });
  if (!medien.ok) return medien;
  return { ok: true, wert: { katalog: pruefung.wert, medien: medien.wert } };
}
