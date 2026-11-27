/**
 * Entwurf eines Follow-along-Flows, wie ihn das Importwerkzeug aus einem
 * Transkript erzeugt, bevor daraus Seed-SQL wird. pruefeFlowEntwurf ist die
 * harte Schranke davor: lieber ein klarer Fehler als ein kaputter Flow in der DB.
 */

export type FlowLevel = "einsteiger" | "mittel" | "fortgeschritten";

export type FlowSchritt = {
  name: string;
  beschreibung: string | null;
  workS: number;
  restS: number;
  istWarmup: boolean;
  unsicher?: boolean;
  /** Katalogschluessel (exercises.catalog_key) der Uebung, die der Schritt zeigt. */
  uebung?: string;
};

export type FlowEntwurf = {
  key: string;
  titel: string;
  beschreibung: string | null;
  level: FlowLevel | null;
  quelle: { url: string; kanal: string };
  schritte: FlowSchritt[];
};

const KEY_MUSTER = /^[a-z0-9-]+$/;
const UEBUNG_MUSTER = /^[a-z0-9_]+$/;
const LEVELS = ["einsteiger", "mittel", "fortgeschritten"];

function istObjekt(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function text(v: unknown): boolean {
  return typeof v === "string" && v.trim() !== "";
}

function textOderNull(v: unknown, was: string): void {
  if (v !== null && typeof v !== "string") throw new Error(`${was} muss Text oder null sein.`);
}

export function pruefeFlowEntwurf(e: unknown): FlowEntwurf {
  if (!istObjekt(e)) throw new Error("Entwurf muss ein Objekt sein.");
  if (typeof e.key !== "string" || !KEY_MUSTER.test(e.key)) {
    throw new Error("key darf nur aus a-z, 0-9 und Bindestrich bestehen.");
  }
  if (!text(e.titel)) throw new Error("Titel darf nicht leer sein.");
  textOderNull(e.beschreibung, "Beschreibung");
  if (e.level !== null && !(typeof e.level === "string" && LEVELS.includes(e.level))) {
    throw new Error("level muss einsteiger, mittel, fortgeschritten oder null sein.");
  }
  if (!istObjekt(e.quelle) || !text(e.quelle.url) || !text(e.quelle.kanal)) {
    throw new Error("quelle braucht url und kanal.");
  }
  if (!Array.isArray(e.schritte) || e.schritte.length === 0) {
    throw new Error("Der Entwurf braucht mindestens einen Schritt.");
  }

  const schritte: unknown[] = e.schritte;
  schritte.forEach((s, i) => {
    const nr = `Schritt ${i + 1}`;
    if (!istObjekt(s)) throw new Error(`${nr} muss ein Objekt sein.`);
    if (!text(s.name)) throw new Error(`${nr}: Name darf nicht leer sein.`);
    textOderNull(s.beschreibung, `${nr}: Beschreibung`);
    if (typeof s.istWarmup !== "boolean") throw new Error(`${nr}: istWarmup muss boolean sein.`);
    if (s.uebung !== undefined && !(typeof s.uebung === "string" && UEBUNG_MUSTER.test(s.uebung))) {
      throw new Error(`${nr}: uebung muss ein Katalogschluessel sein.`);
    }
    if (!Number.isInteger(s.workS)) throw new Error(`${nr}: workS muss ganzzahlig sein.`);
    if (!Number.isInteger(s.restS)) throw new Error(`${nr}: restS muss ganzzahlig sein.`);
    if ((s.workS as number) <= 0) throw new Error(`${nr}: workS muss groesser als 0 sein.`);
    if ((s.restS as number) < 0) throw new Error(`${nr}: restS darf nicht negativ sein.`);
    if (i === schritte.length - 1 && s.restS !== 0) {
      throw new Error(`${nr}: der letzte Schritt muss restS 0 haben.`);
    }
  });

  return e as unknown as FlowEntwurf;
}
