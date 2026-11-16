// Einheit als Ganzes neu bauen (P4): Reihenfolge, Entfernen, Hinzufuegen, Tauschen und
// Werte aendern in einem Schritt. Rein: Merkmale und Vorgaben kommen von aussen, damit
// die Regeln hier stehen und nicht in SQL oder im Client.
import { DomainError } from "./errors.js";
import type { GeneratorEingabe, PlanEinheit, PlanPosition, TypVorgaben } from "./trainingsplan-generator.js";
import { tauschVorgaben } from "./trainingsplan-generator.js";
import { zielprofil } from "./trainingsplan-regeln.js";
import type { Baustein, PlanTyp } from "./trainingsplan-typen.js";
import { ZEIT, aufwaermenMinuten, cardioMinuten } from "./trainingsplan-zeit.js";

/** Eine Position, wie der Client sie liefert; fehlende Werte bestimmt baueEinheit. */
export type EinheitEingabePosition = {
  key: string | null;
  exerciseId: string;
  modelId: string;
  saetze?: number;
  wdhVon?: number;
  wdhBis?: number;
  pauseSek?: number;
  dauerMin?: number;
};

/** Planmerkmale einer Uebung aus dem Katalog; null heisst: nicht fuer Plaene freigegeben. */
export type UebungsMerkmale = { baustein: Baustein | null; typ: PlanTyp | null; hauptmuskeln: string[] };

export type EinheitVorgaben = {
  typ: Record<PlanTyp, TypVorgaben>;
  saetze: number;
  cardioMin: number;
  aufwaermenMin: number;
};

const MAX_POSITIONEN = 20;
const CARDIO_STANDARD_MIN = 10;

/** Vorgaben aus derselben Quelle wie der Generator (Zielprofil, Zeitregeln). */
export function vorgabenAusEingabe(
  eingabe: Pick<GeneratorEingabe, "ziel" | "erfahrung" | "anfaengerBeendet" | "minuten">,
): EinheitVorgaben {
  const profil = zielprofil(eingabe.ziel, eingabe.erfahrung, eingabe.anfaengerBeendet ?? false);
  return {
    typ: tauschVorgaben(eingabe),
    saetze: profil.saetze,
    // Bei kurzen Einheiten plant der Generator kein Cardio (0); eine neu hinzugefuegte
    // Cardio-Position braucht trotzdem eine gueltige Dauer (mindestens 5).
    cardioMin: cardioMinuten(eingabe.minuten) || CARDIO_STANDARD_MIN,
    aufwaermenMin: aufwaermenMinuten(eingabe.minuten),
  };
}

export function positionMinuten(
  p: Pick<PlanPosition, "baustein" | "saetze" | "pauseSek" | "aufwaermsatz" | "dauerMin">,
): number {
  if (p.baustein === "cardio") return p.dauerMin ?? 0;
  return (
    ZEIT.einstellenMin +
    p.saetze * ZEIT.satzMin +
    ((p.saetze - 1) * p.pauseSek) / 60 +
    (p.aufwaermsatz ? ZEIT.aufwaermsatzMin : 0)
  );
}

const ungueltig = () => new DomainError("validation_failed", "Diese Einheit kann so nicht gespeichert werden.");

function ganzzahl(wert: number, von: number, bis: number): boolean {
  return Number.isInteger(wert) && wert >= von && wert <= bis;
}

/** Werte einer Position vor dem Ueberschreiben durch den Client. */
type Werte = Pick<
  PlanPosition,
  "saetze" | "wdhVon" | "wdhBis" | "reserveVon" | "reserveBis" | "pauseSek" | "aufwaermsatz" | "dauerMin" | "rolle"
>;

function ausVorgaben(cardio: boolean, typ: PlanTyp, vorgaben: EinheitVorgaben): Werte {
  if (cardio) {
    const v = vorgaben.typ.isolation;
    return {
      saetze: 1,
      wdhVon: null,
      wdhBis: null,
      reserveVon: v.reserveVon,
      reserveBis: v.reserveBis,
      pauseSek: 0,
      aufwaermsatz: false,
      dauerMin: vorgaben.cardioMin,
      rolle: "cardio",
    };
  }
  const v = vorgaben.typ[typ];
  return {
    saetze: vorgaben.saetze,
    wdhVon: v.wdhVon,
    wdhBis: v.wdhBis,
    reserveVon: v.reserveVon,
    reserveBis: v.reserveBis,
    pauseSek: v.pauseSek,
    aufwaermsatz: v.aufwaermsatz,
    dauerMin: null,
    rolle: "ergaenzung",
  };
}

/**
 * Baut die Einheit aus der Client-Liste neu. Bestehende Positionen (Schluessel aus `alt`)
 * behalten ihre Werte, solange Art (Kraft/Cardio) und Uebung passen; sonst gelten die
 * Vorgaben. Gelieferte Werte ueberschreiben, danach greifen die Grenzen.
 * Wirft DomainError (validation_failed, uebung_ohne_planmerkmale).
 */
export function baueEinheit(
  alt: PlanEinheit,
  eingabe: EinheitEingabePosition[],
  merkmale: Record<string, UebungsMerkmale>,
  vorgaben: EinheitVorgaben,
): PlanEinheit {
  if (eingabe.length === 0 || eingabe.length > MAX_POSITIONEN) throw ungueltig();

  const altNachKey = new Map(alt.positionen.map((p) => [p.key, p]));
  const keys = new Set<string>();
  const uebungen = new Set<string>();
  for (const p of eingabe) {
    if (p.key !== null) {
      if (!altNachKey.has(p.key) || keys.has(p.key)) throw ungueltig();
      keys.add(p.key);
    }
    if (uebungen.has(p.exerciseId)) throw ungueltig();
    uebungen.add(p.exerciseId);
  }

  const nummern = alt.positionen.map((p) => Number(p.key)).filter((n) => Number.isInteger(n));
  let naechster = (nummern.length > 0 ? Math.max(...nummern) : -1) + 1;

  const positionen = eingabe.map((p): PlanPosition => {
    const m = merkmale[p.exerciseId];
    if (!m || m.baustein === null || m.typ === null) {
      throw new DomainError("uebung_ohne_planmerkmale", "Diese Übung ist noch nicht für Trainingspläne freigegeben.");
    }
    const cardio = m.baustein === "cardio";
    const bisher = p.key === null ? undefined : altNachKey.get(p.key);

    let werte: Werte;
    let key: string;
    if (bisher && (bisher.baustein === "cardio") === cardio) {
      key = bisher.key;
      if (bisher.exerciseId === p.exerciseId) {
        werte = { ...bisher };
      } else {
        // Tausch gleicher Art: Werte der Stelle bleiben, nur der Aufwaermsatz folgt der Uebung.
        werte = { ...bisher, aufwaermsatz: !cardio && m.typ === "mehrgelenk" };
      }
    } else {
      // Art gewechselt: die Position behaelt ihren Schluessel; neue Positionen bekommen einen frischen.
      key = bisher ? bisher.key : String(naechster++);
      werte = ausVorgaben(cardio, m.typ, vorgaben);
    }
    // Ersetzt die Stelle ihre Art, bekommt sie die Rolle der neuen Art; sonst bleibt die alte.
    const rolle = bisher && (bisher.baustein === "cardio") === cardio ? bisher.rolle : werte.rolle;

    if (cardio) {
      // Cardio laeuft nur ueber die Dauer; Satz-Werte vom Client sind ein Fehler.
      if (p.saetze !== undefined && p.saetze !== 1) throw ungueltig();
      if (p.wdhVon !== undefined || p.wdhBis !== undefined) throw ungueltig();
      if (p.pauseSek !== undefined && p.pauseSek !== 0) throw ungueltig();
      const dauerMin = p.dauerMin ?? werte.dauerMin;
      if (dauerMin === null || !ganzzahl(dauerMin, 5, 120)) throw ungueltig();
      werte = { ...werte, saetze: 1, wdhVon: null, wdhBis: null, pauseSek: 0, dauerMin };
    } else {
      if (p.dauerMin !== undefined) throw ungueltig();
      const saetze = p.saetze ?? werte.saetze;
      const wdhVon = p.wdhVon ?? werte.wdhVon;
      const wdhBis = p.wdhBis ?? werte.wdhBis;
      const pauseSek = p.pauseSek ?? werte.pauseSek;
      if (!ganzzahl(saetze, 1, 10) || !ganzzahl(pauseSek, 0, 600)) throw ungueltig();
      if (wdhVon === null || wdhBis === null) throw ungueltig();
      if (!ganzzahl(wdhVon, 1, 50) || !ganzzahl(wdhBis, wdhVon, 50)) throw ungueltig();
      werte = { ...werte, saetze, wdhVon, wdhBis, pauseSek, dauerMin: null };
    }

    return {
      key,
      baustein: m.baustein,
      rolle,
      exerciseId: p.exerciseId,
      modelId: p.modelId,
      typ: m.typ,
      saetze: werte.saetze,
      wdhVon: werte.wdhVon,
      wdhBis: werte.wdhBis,
      reserveVon: werte.reserveVon,
      reserveBis: werte.reserveBis,
      pauseSek: werte.pauseSek,
      aufwaermsatz: werte.aufwaermsatz,
      dauerMin: werte.dauerMin,
      hauptmuskeln: m.hauptmuskeln,
    };
  });

  // Der Generator rundet nicht (aufwaermen + Summe + Cardio); hier ebenso nicht.
  const geschaetzteMinuten = vorgaben.aufwaermenMin + positionen.reduce((s, p) => s + positionMinuten(p), 0);
  return { key: alt.key, positionen, geschaetzteMinuten };
}
