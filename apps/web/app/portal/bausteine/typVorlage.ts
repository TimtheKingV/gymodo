import type { CatalogProduct, CatalogType } from "@fitretro/domain";
import type { Category } from "@fitretro/domain/belastung";
import type { ModellBelastungStart } from "./ModellBelastungRad";

/** Ein Herstellermodell, wie das Formular es braucht -- Bild als URL, nie als Pfad. */
export type ProduktVorlage = Pick<
  CatalogProduct,
  "id" | "manufacturer" | "series" | "name" | "modelCode" | "note" | "load" | "secondary"
> & { fotoUrl: string | null };

/**
 * Was das Modellformular vom Gymtavo-Typ braucht, um vorzubefuellen
 * (Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 5.2).
 * Schlank, weil die Liste als Prop in den Browser geht: 55 Typen mit allen
 * Uebungstexten waeren ein Vielfaches.
 */
export type TypVorlage = Pick<
  CatalogType,
  | "id"
  | "name"
  | "manufacturer"
  | "category"
  | "loadUnit"
  | "loadStep"
  | "loadMin"
  | "loadMax"
  | "secondaryUnit"
  | "secondaryStep"
  | "secondaryMin"
  | "secondaryMax"
  | "cardioWerte"
> & {
  /** Der Pfad bleibt auf dem Server; das Formular muss nur wissen, ob. */
  hatFoto: boolean;
  /** Signiert auf dem Server (ladeTypVorlagen); Symbolbild der Modellkarten. */
  fotoUrl: string | null;
  produkte: ProduktVorlage[];
};

export function typVorlagen(
  typen: CatalogType[],
  kategorie?: Category,
  fotoUrls: Record<string, string> = {},
): TypVorlage[] {
  const url = (pfad: string | null) => (pfad ? (fotoUrls[pfad] ?? null) : null);
  return typen
    // Ein neues Modell bekommt nie einen abgeloesten Typ (Testnotiz 12.10., #1).
    .filter((typ) => !typ.retired)
    .filter((typ) => kategorie === undefined || typ.category === kategorie)
    .map((typ) => ({
      id: typ.id,
      name: typ.name,
      manufacturer: typ.manufacturer,
      category: typ.category,
      loadUnit: typ.loadUnit,
      loadStep: typ.loadStep,
      loadMin: typ.loadMin,
      loadMax: typ.loadMax,
      secondaryUnit: typ.secondaryUnit,
      secondaryStep: typ.secondaryStep,
      secondaryMin: typ.secondaryMin,
      secondaryMax: typ.secondaryMax,
      cardioWerte: typ.cardioWerte,
      hatFoto: typ.photoPath !== null,
      fotoUrl: url(typ.photoPath),
      produkte: typ.products.map((p) => ({
        id: p.id,
        manufacturer: p.manufacturer,
        series: p.series,
        name: p.name,
        modelCode: p.modelCode,
        note: p.note,
        load: p.load,
        secondary: p.secondary,
        fotoUrl: url(p.photoPath),
      })),
    }));
}

export function belastungStart(typ: TypVorlage): ModellBelastungStart {
  return {
    category: typ.category,
    loadUnit: typ.loadUnit,
    loadMin: typ.loadMin,
    loadMax: typ.loadMax,
    loadStep: typ.loadStep,
    secondaryUnit: typ.secondaryUnit,
    secondaryMin: typ.secondaryMin,
    secondaryMax: typ.secondaryMax,
    secondaryStep: typ.secondaryStep,
  };
}
