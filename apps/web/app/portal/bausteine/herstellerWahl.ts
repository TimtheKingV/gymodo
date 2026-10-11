import type { AuswahlOption } from "./Auswahl";
import type { ModellBelastungStart } from "./ModellBelastungRad";
import { belastungStart, type ProduktVorlage, type TypVorlage } from "./typVorlage";

/**
 * Hersteller- und Modellwahl der Modellformulare (Spec
 * 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.5) als reine
 * Funktionen -- ohne Browser pruefbar, die Komponente verdrahtet nur.
 */

/** Kein echter Herstellername: Hersteller kommen aus der Datei und beginnen nie mit "__". */
export const ANDERER_HERSTELLER = "__anderer";

export function herstellerOptionen(typ: TypVorlage): AuswahlOption[] {
  const anzahl = new Map<string, number>();
  for (const p of typ.produkte) anzahl.set(p.manufacturer, (anzahl.get(p.manufacturer) ?? 0) + 1);
  return [
    ...[...anzahl]
      .sort(([a], [b]) => a.localeCompare(b, "de"))
      .map(([name, n]) => ({ wert: name, anzeige: `${name} (${n})` })),
    { wert: ANDERER_HERSTELLER, anzeige: "Anderer Hersteller" },
  ];
}

/** Die Reihenfolge kommt sortiert aus listCatalogTypes. */
export function produkteVon(typ: TypVorlage, hersteller: string): ProduktVorlage[] {
  return typ.produkte.filter((p) => p.manufacturer === hersteller);
}

function teile(...werte: (string | null)[]): string {
  return werte.filter((w): w is string => w !== null && w.trim().length > 0).join(" ");
}

/** "Pure Kraft Brustpresse 4345" -- der Hersteller steht im eigenen Feld. */
export function produktName(p: Pick<ProduktVorlage, "series" | "name" | "modelCode">): string {
  return teile(p.series, p.name, p.modelCode);
}

export function vorlageText(p: { manufacturer: string; series: string | null; name: string; modelCode: string | null }): string {
  return `Vorlage: ${teile(p.manufacturer, p.series, p.name, p.modelCode)}`;
}

/**
 * Produkt vor Typ (G4), aber nur als Ganzes: ein Produkt ohne Raster laesst
 * die Typwerte stehen. Die Kategorie kommt immer vom Typ -- das Produkt hat
 * keine.
 */
export function vorlageStart(typ: TypVorlage, produkt: ProduktVorlage | null): ModellBelastungStart {
  const start = belastungStart(typ);
  if (!produkt?.load) return start;
  return {
    ...start,
    loadUnit: produkt.load.unit,
    loadStep: produkt.load.step,
    loadMin: produkt.load.min,
    loadMax: produkt.load.max,
    secondaryUnit: produkt.secondary?.unit ?? null,
    secondaryStep: produkt.secondary?.step ?? null,
    secondaryMin: produkt.secondary?.min ?? null,
    secondaryMax: produkt.secondary?.max ?? null,
  };
}

/**
 * Ein Vorschlag (Typname, Produktname) ersetzt nur, was selbst ein
 * Vorschlag war oder leer ist -- was der Trainer getippt hat, bleibt.
 */
export function nameNachVorschlag(aktuell: string, voriger: string | null, neuer: string | null): string {
  if (neuer === null) return aktuell;
  const leer = aktuell.trim().length === 0;
  return leer || aktuell === voriger ? neuer : aktuell;
}
