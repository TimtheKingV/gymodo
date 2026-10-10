import type { CatalogType } from "@fitretro/domain";
import type { Category } from "@fitretro/domain/belastung";
import type { ModellBelastungStart } from "./ModellBelastungRad";

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
> & {
  /** Der Pfad bleibt auf dem Server; das Formular muss nur wissen, ob. */
  hatFoto: boolean;
};

export function typVorlagen(typen: CatalogType[], kategorie?: Category): TypVorlage[] {
  return typen
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
      hatFoto: typ.photoPath !== null,
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

/**
 * Der Typname ist ein Vorschlag, kein Ueberschreiben: was der Trainer
 * selbst getippt hat, bleibt. Erkannt wird der Vorschlag daran, dass der
 * Name noch genau der des vorigen Typs ist.
 */
export function nameNachTypwahl(
  aktuell: string,
  vorigerTyp: TypVorlage | null,
  neuerTyp: TypVorlage | null,
): string {
  if (!neuerTyp) return aktuell;
  const leer = aktuell.trim().length === 0;
  const vomTyp = vorigerTyp !== null && aktuell === vorigerTyp.name;
  return leer || vomTyp ? neuerTyp.name : aktuell;
}
