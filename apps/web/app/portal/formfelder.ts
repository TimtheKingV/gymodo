import type { Category, LoadUnit, VolumeKind } from "@fitretro/domain/belastung";
import { istEinheit, istKategorie, istUmfangsart } from "./bausteine/einstellungVorschlaege";

/**
 * Liest die Felder von ModellBelastungRad und UebungUmfangRad aus einem
 * FormData -- EIN Ort, den beide Server-Action-Dateien (Schreibtisch und
 * Halle) teilen. Vorher lasen beide dieselben drei Zahlen mit denselben
 * fuenf Zeilen; mit Kategorie, Einheit, Nebenbelastung und Umfangsart
 * waeren es zwei Kopien von zwanzig.
 *
 * Fehlende Felder fallen auf die Kraft-Vorgaben zurueck (kraft, kg, reps):
 * ein Formular, das die neuen Auswahlfelder nicht traegt, legt weiter ein
 * Kraftgeraet an.
 */

function text(formData: FormData, name: string): string {
  const wert = formData.get(name);
  return typeof wert === "string" ? wert.trim() : "";
}

/** Deutsche Eingabe: 2,5 ist dasselbe wie 2.5. Leer bleibt undefined. */
function zahl(formData: FormData, name: string): number | undefined {
  const roh = text(formData, name).replace(",", ".");
  if (roh.length === 0) return undefined;
  const wert = Number(roh);
  return Number.isFinite(wert) ? wert : Number.NaN;
}

export type BelastungsFelder = {
  category: Category;
  loadUnit: LoadUnit;
  loadStep: number | undefined;
  loadMin: number | undefined;
  loadMax: number | null;
  secondaryUnit: LoadUnit | null;
  secondaryStep: number | null;
  secondaryMin: number | null;
  secondaryMax: number | null;
};

export function belastungAusFormular(formData: FormData): BelastungsFelder {
  const kategorie = text(formData, "category");
  const einheit = text(formData, "loadUnit");
  const neben = text(formData, "secondaryUnit");
  const secondaryUnit = istEinheit(neben) ? neben : null;
  return {
    category: istKategorie(kategorie) ? kategorie : "kraft",
    loadUnit: istEinheit(einheit) ? einheit : "kg",
    loadStep: zahl(formData, "loadStep"),
    loadMin: zahl(formData, "loadMin"),
    loadMax: zahl(formData, "loadMax") ?? null,
    secondaryUnit,
    // Ohne Einheit keine Rastung -- auch wenn das Rad noch Werte traegt
    // (der Trainer hat die Nebenbelastung wieder auf "keine" gestellt).
    secondaryStep: secondaryUnit ? (zahl(formData, "secondaryStep") ?? null) : null,
    secondaryMin: secondaryUnit ? (zahl(formData, "secondaryMin") ?? null) : null,
    secondaryMax: secondaryUnit ? (zahl(formData, "secondaryMax") ?? null) : null,
  };
}

export type UmfangsFelder = {
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
};

/**
 * Minuten kommen als Minuten aus dem Rad und gehen als Sekunden in die
 * Datenbank (exercises.volume_kind = 'seconds'). NaN bleibt NaN, damit
 * das Zod-Schema der Domain die Meldung liefert, nicht dieses Modul.
 */
export function umfangAusFormular(formData: FormData): UmfangsFelder {
  const art = text(formData, "volumeKind");
  const volumeKind: VolumeKind = istUmfangsart(art) ? art : "reps";
  const faktor = volumeKind === "seconds" ? 60 : 1;
  const min = zahl(formData, "targetMin") ?? Number.NaN;
  const max = zahl(formData, "targetMax") ?? Number.NaN;
  return {
    volumeKind,
    targetMin: Math.round(min * faktor),
    targetMax: Math.round(max * faktor),
  };
}
