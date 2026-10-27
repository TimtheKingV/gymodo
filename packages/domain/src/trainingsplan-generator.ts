// Plangenerator (Spec 2026-10-21, Abschnitte 2 und 3, F9, F12, F16, F19).
// Rein: kein DB-Zugriff, keine Uhr, kein Zufall -- gleiche Eingabe ergibt denselben Plan,
// damit gespeicherte Plaene nachvollziehbar bleiben und Tests exakt sein koennen.
import { PlanNichtMoeglichError } from "./errors.js";
import type { Beschwerden, Kandidat } from "./trainingsplan-auswahl.js";
import {
  filtereKandidaten,
  istVorsichtig,
  nachBaustein,
  pruefePflicht,
  waehleFokus,
  waehleKandidat,
} from "./trainingsplan-auswahl.js";
import type { Baustein, Erfahrung, FokusBereich, Minuten, PlanTyp } from "./trainingsplan-typen.js";
import type { Struktur, Ziel, Zielprofil } from "./trainingsplan-regeln.js";
import { PLAN_REGEL_VERSION, strukturFuerTage, zielprofil } from "./trainingsplan-regeln.js";
import { ZEIT, aufwaermenMinuten, cardioMinuten, pauseSekunden, uebungMinuten } from "./trainingsplan-zeit.js";

export type { Kandidat } from "./trainingsplan-auswahl.js";

/** Bewusst ohne Alter und Geschlecht: sie beeinflussen den Plan nicht (F7). */
export type GeneratorEingabe = {
  ziel: Ziel;
  tage: number;
  minuten: Minuten;
  fokus: FokusBereich[];
  erfahrung: Erfahrung;
  /** Beendet die Anfaengerphase: "neu" plant dann wie "unregelmaessig". Default false. */
  anfaengerBeendet?: boolean;
  beschwerden: Beschwerden;
  kandidaten: Kandidat[];
};

export type PlanPosition = {
  key: string;
  baustein: Baustein;
  rolle: "pflicht" | "fokus" | "ergaenzung" | "auffuellung" | "cardio";
  exerciseId: string;
  modelId: string;
  typ: PlanTyp;
  saetze: number;
  wdhVon: number | null;
  wdhBis: number | null;
  reserveVon: number;
  reserveBis: number;
  pauseSek: number;
  aufwaermsatz: boolean;
  dauerMin: number | null;
  hauptmuskeln: string[];
};

export type PlanEinheit = { key: string; positionen: PlanPosition[]; geschaetzteMinuten: number };

export type GeneratorErgebnis = {
  regelVersion: string;
  struktur: Struktur["key"];
  einheiten: PlanEinheit[];
  gruende: string[];
};

const STRUKTUR_GRUND: Record<Struktur["key"], string> = {
  gk_eine: "struktur_ganzkoerper_eine_einheit",
  gk_ab: "struktur_ganzkoerper_ab",
  gk_abc: "struktur_ganzkoerper_abc",
  ober_unter: "struktur_ober_unter",
};

// Gleitkomma-Rauschen (z. B. 55 * 1.05) darf eine exakt passende Uebung nicht verdraengen.
const EPSILON = 1e-9;

type Entwurf = Omit<PlanPosition, "key">;

/** Was eine Einheit an Gruenden beitraegt; der Plan sammelt sie ueber alle Einheiten. */
type Flags = {
  saetzeReduziert: boolean;
  ergaenzungEntfallen: boolean;
  zweiterFokusEntfallen: boolean;
  fokus: Set<FokusBereich>;
};

/** Die Felder einer Kraftposition, die vom Typ der Uebung abhaengen. */
export type TypVorgaben = Pick<
  PlanPosition,
  "typ" | "wdhVon" | "wdhBis" | "reserveVon" | "reserveBis" | "pauseSek" | "aufwaermsatz"
> & { wdhVon: number; wdhBis: number };

function typVorgaben(profil: Zielprofil, typ: PlanTyp): TypVorgaben {
  const [wdhVon, wdhBis] = profil.wdh[typ];
  return {
    typ,
    wdhVon,
    wdhBis,
    reserveVon: profil.reserve[0],
    reserveBis: profil.reserve[1],
    pauseSek: pauseSekunden(typ),
    // Nur Mehrgelenkuebungen bekommen einen Aufwaermsatz (Spec Abschnitt 2).
    aufwaermsatz: typ === "mehrgelenk",
  };
}

/**
 * Vorgaben je Typ fuer einen dauerhaften Tausch (Uebergabe Etappe 3, Punkt 2): die
 * getauschte Position bekommt die Werte des Typs der NEUEN Uebung, aus demselben
 * Zielprofil wie der Generator. swap_training_plan_position (0065) waehlt den Eintrag
 * nach exercises.plan_typ; die Regeln stehen so nur hier, nicht auch in SQL.
 */
export function tauschVorgaben(
  eingabe: Pick<GeneratorEingabe, "ziel" | "erfahrung" | "anfaengerBeendet">,
): Record<PlanTyp, TypVorgaben> {
  const profil = zielprofil(eingabe.ziel, eingabe.erfahrung, eingabe.anfaengerBeendet ?? false);
  return { mehrgelenk: typVorgaben(profil, "mehrgelenk"), isolation: typVorgaben(profil, "isolation") };
}

function position(k: Kandidat, rolle: Entwurf["rolle"], saetze: number, profil: Zielprofil): Entwurf {
  return {
    baustein: k.baustein,
    rolle,
    exerciseId: k.exerciseId,
    modelId: k.modelId,
    saetze,
    ...typVorgaben(profil, k.typ),
    dauerMin: null,
    hauptmuskeln: [...k.hauptmuskeln],
  };
}

type EinheitKontext = {
  einheit: Struktur["einheiten"][number];
  kandidaten: Kandidat[];
  variation: Map<Baustein, number>;
  profil: Zielprofil;
  fokus: FokusBereich[];
  kraftBudget: number;
  vorsichtig: (k: Kandidat) => boolean;
};

// Rang fuer die Anzeigereihenfolge: Pflicht, Fokus, Auffuellung, Ergaenzung (Cardio haengt separat an).
const ROLLEN_RANG: Record<Entwurf["rolle"], number> = { pflicht: 0, fokus: 1, auffuellung: 2, ergaenzung: 3, cardio: 4 };

/**
 * Anzeigereihenfolge: Mehrgelenk vor Isolation, darin nach Rolle. Array.sort ist stabil, daher
 * bleibt die Auswahlreihenfolge bei gleichem Rang erhalten und der Plan deterministisch.
 */
function sortiereFuerAnzeige(positionen: Entwurf[]): Entwurf[] {
  const typRang = (p: Entwurf) => (p.typ === "mehrgelenk" ? 0 : 1);
  return [...positionen].sort((a, b) => typRang(a) - typRang(b) || ROLLEN_RANG[a.rolle] - ROLLEN_RANG[b.rolle]);
}

/** Belegt eine Einheit nach dem Ablauf der Spec: Pflicht, Saetze kuerzen, Fokus, Ergaenzungen. */
function baueKraftteil(ctx: EinheitKontext, flags: Flags): { positionen: Entwurf[]; minuten: number } {
  const { einheit, kandidaten, variation, profil } = ctx;
  const waehle = (b: Baustein) => waehleKandidat(nachBaustein(kandidaten, b), variation.get(b) ?? 0, belegt, ctx.vorsichtig);
  const grenze = ctx.kraftBudget * (1 + ZEIT.toleranz) + EPSILON;
  const belegt = new Set<string>();
  const nimm = (k: Kandidat) => belegt.add(k.exerciseId);

  const pflicht: Kandidat[] = einheit.bausteine.pflicht.map((b) => {
    // Trotz pruefePflicht kann die einzige Uebung schon in einem anderen Pflichtbaustein stehen;
    // dann lieber ein klarer Fehler als ein Plan ohne Pflichtbaustein.
    const k = waehle(b);
    if (!k) throw new PlanNichtMoeglichError(b, "kein_geraet");
    nimm(k);
    return k;
  });

  // F16: reicht die Zeit nicht fuer die Pflicht mit Zielsatzzahl, sinken alle Saetze auf 2.
  // Pflichtbausteine bleiben auch dann, wenn 2 Saetze das Budget noch ueberschreiten.
  let saetze: number = profil.saetze;
  const pflichtMinuten = (s: number) => pflicht.reduce((sum, k) => sum + uebungMinuten(k.typ, s), 0);
  if (saetze > 2 && pflichtMinuten(saetze) > grenze) {
    saetze = 2;
    flags.saetzeReduziert = true;
  }
  let summe = pflichtMinuten(saetze);
  const passt = (k: Kandidat) => summe + uebungMinuten(k.typ, saetze) <= grenze;

  const positionen = pflicht.map((k) => position(k, "pflicht", saetze, profil));
  const erlaubteBausteine = [...einheit.bausteine.pflicht, ...einheit.bausteine.ergaenzung];

  // F9: jeder gesetzte Fokus ersetzt einen Ergaenzungsplatz, damit die Zeit gleich bleibt --
  // bevorzugt den Platz seines eigenen Bausteins (sonst stuende der Baustein doppelt), sonst
  // die letzte verbleibende Ergaenzung in Strukturreihenfolge.
  const ergaenzungen = [...einheit.bausteine.ergaenzung];
  ctx.fokus.forEach((bereich, i) => {
    const k = waehleFokus(kandidaten, bereich, erlaubteBausteine, belegt);
    if (!k) return;
    if (!passt(k)) {
      if (i === 1) flags.zweiterFokusEntfallen = true;
      else flags.ergaenzungEntfallen = true;
      return;
    }
    nimm(k);
    summe += uebungMinuten(k.typ, saetze);
    positionen.push(position(k, "fokus", saetze, profil));
    flags.fokus.add(bereich);
    const eigener = ergaenzungen.indexOf(k.baustein);
    ergaenzungen.splice(eigener >= 0 ? eigener : ergaenzungen.length - 1, 1);
  });

  for (const b of ergaenzungen) {
    const k = waehle(b);
    if (!k) continue;
    if (!passt(k)) {
      flags.ergaenzungEntfallen = true;
      continue;
    }
    nimm(k);
    summe += uebungMinuten(k.typ, saetze);
    positionen.push(position(k, "ergaenzung", saetze, profil));
  }

  // Auffuellen bis zum Budget (Spec: "Der Generator fuellt bis zum Budget"): weitere Runden
  // ueber die Bausteine der Einheit, Pflicht vor Ergaenzung, je Runde die naechste noch freie
  // Uebung -- bis eine ganze Runde nichts mehr hinzufuegt. Sonst endet z. B. Ober/Unter mit
  // 4 Uebungen weit unter der gewaehlten Zeit.
  const runde = [...einheit.bausteine.pflicht, ...einheit.bausteine.ergaenzung];
  for (let neu = true; neu; ) {
    neu = false;
    for (const b of runde) {
      const k = waehle(b);
      if (!k || !passt(k)) continue;
      nimm(k);
      summe += uebungMinuten(k.typ, saetze);
      positionen.push(position(k, "auffuellung", saetze, profil));
      neu = true;
    }
  }
  return { positionen, minuten: summe };
}

export function generierePlan(eingabe: GeneratorEingabe): GeneratorErgebnis {
  const struktur = strukturFuerTage(eingabe.tage);
  const profil = zielprofil(eingabe.ziel, eingabe.erfahrung, eingabe.anfaengerBeendet ?? false);
  const kandidaten = filtereKandidaten(eingabe.kandidaten, eingabe.beschwerden);

  for (const b of new Set(struktur.einheiten.flatMap((e) => e.bausteine.pflicht))) {
    pruefePflicht(b, eingabe.kandidaten, kandidaten);
  }

  // Cardio nur bei Abnehmen und nur, wenn ein (nicht gemiedenes) Cardiogeraet da ist (F19);
  // sonst geht die Zeit an Kraftuebungen.
  const abnehmen = eingabe.ziel === "abnehmen";
  const cardioSoll = abnehmen ? cardioMinuten(eingabe.minuten) : 0;
  const cardioListe = nachBaustein(kandidaten, "cardio");
  // "gefaellt nicht" nur, wenn es keine andere Cardiouebung gibt.
  const cardioKandidat = cardioListe.find((k) => !k.gefaelltNicht) ?? cardioListe[0] ?? null;
  // Wie bei pruefePflicht: "kein Geraet" nur, wenn das Studio wirklich keins hat; sind alle
  // gemieden, erklaert das schon beschwerden_meiden, und das Studio wird nicht beschuldigt.
  const studioHatCardio = nachBaustein(eingabe.kandidaten, "cardio").length > 0;
  const cardio = cardioKandidat ? cardioSoll : 0;
  const aufwaermen = aufwaermenMinuten(eingabe.minuten);
  const kraftBudget = eingabe.minuten - aufwaermen - cardio;
  const fokus = [...new Set(eingabe.fokus)].slice(0, 2);
  const vorsichtig = (k: Kandidat) => istVorsichtig(k, eingabe.beschwerden);

  const flags: Flags = {
    saetzeReduziert: false,
    ergaenzungEntfallen: false,
    zweiterFokusEntfallen: false,
    fokus: new Set(),
  };
  // Zaehlt je Baustein, wie oft er schon in einer Einheit vorkam: so wechseln A/B (und OK_A/OK_B)
  // die Uebung, und bei nur einem Kandidaten bleibt sie gleich.
  const zaehler = new Map<Baustein, number>();

  const einheiten: PlanEinheit[] = struktur.einheiten.map((einheit) => {
    const variation = new Map(zaehler);
    for (const b of [...einheit.bausteine.pflicht, ...einheit.bausteine.ergaenzung]) {
      zaehler.set(b, (zaehler.get(b) ?? 0) + 1);
    }
    const kraft = baueKraftteil({ einheit, kandidaten, variation, profil, fokus, kraftBudget, vorsichtig }, flags);
    // Cardio wird erst nach dem Sortieren angehaengt, damit es immer zuletzt steht.
    const entwuerfe: Entwurf[] = sortiereFuerAnzeige(kraft.positionen);
    if (cardio > 0 && cardioKandidat) {
      entwuerfe.push({
        baustein: "cardio",
        rolle: "cardio",
        exerciseId: cardioKandidat.exerciseId,
        modelId: cardioKandidat.modelId,
        // Typ nur fuer den Datensatz; Cardio laeuft ueber dauerMin, nicht ueber Saetze.
        typ: "isolation",
        saetze: 1,
        wdhVon: null,
        wdhBis: null,
        reserveVon: profil.reserve[0],
        reserveBis: profil.reserve[1],
        pauseSek: 0,
        aufwaermsatz: false,
        dauerMin: cardio,
        hauptmuskeln: [],
      });
    }
    return {
      key: einheit.key,
      positionen: entwuerfe.map((p, i) => ({ key: String(i), ...p })),
      geschaetzteMinuten: aufwaermen + kraft.minuten + cardio,
    };
  });

  // Feste Reihenfolge der Codes, damit die Erklaerseite stabil bleibt.
  const gruende: string[] = [STRUKTUR_GRUND[struktur.key], "zeit_uebungen"];
  const wenn = (bedingung: boolean, code: string) => {
    if (bedingung) gruende.push(code);
  };
  wenn(flags.saetzeReduziert, "zeit_saetze_reduziert");
  wenn(flags.ergaenzungEntfallen, "zeit_ergaenzung_entfallen");
  wenn(aufwaermen === 0, "zeit_aufwaermen_entfallen");
  // Ehrlich sagen, wenn das Studio zu wenig Uebungen fuer die gewaehlte Zeit hat (Anti-Ziel:
  // Einheit regelmaessig deutlich kuerzer als angegeben); 10 % Abstand gelten als deutlich.
  wenn(
    einheiten.some((e) => e.geschaetzteMinuten < 0.9 * eingabe.minuten - EPSILON),
    "zeit_budget_nicht_ausgeschoepft",
  );
  for (const f of fokus) wenn(flags.fokus.has(f), `fokus_${f}`);
  wenn(flags.zweiterFokusEntfallen, "fokus_zweiter_entfallen");
  wenn(cardio > 0, "abnehmen_cardio_zone");
  wenn(abnehmen && cardioKandidat !== null && cardioSoll < 20, "abnehmen_cardio_gekuerzt");
  wenn(cardioSoll > 0 && !studioHatCardio, "abnehmen_kein_cardio_geraet");
  wenn(abnehmen, "abnehmen_alltag");
  wenn(abnehmen && fokus.includes("bauch"), "bauch_kein_fettabbau");
  // Nach dem Anfaengerende gilt die Anfaenger-Reserve nicht mehr, der Grund waere falsch.
  wenn(eingabe.erfahrung === "neu" && !eingabe.anfaengerBeendet, "anfaenger_reserve");
  const stufen = Object.values(eingabe.beschwerden);
  wenn(stufen.includes("meiden"), "beschwerden_meiden");
  wenn(stufen.includes("vorsichtig"), "beschwerden_vorsichtig");

  return { regelVersion: PLAN_REGEL_VERSION, struktur: struktur.key, einheiten, gruende };
}
