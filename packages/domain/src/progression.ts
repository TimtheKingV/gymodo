/**
 * Deterministischer Belastungsvorschlag aus der eigenen Historie.
 *
 * Fachliche Grundlage: Spec Abschnitt 8.4 (planlose Variante des
 * Regelprinzips aus Blueprint Paragraf 5.7). Die Funktion ist rein: gleiche
 * Eingabe, gleiches Ergebnis, keine Uhr, kein Zufall, kein Datenbankzugriff.
 *
 * Sie gibt eine Rechnung aus, keine Empfehlung. Was daraus wird, entscheidet
 * das Mitglied -- die Plattform misst nichts (Spec Abschnitt 4.3).
 *
 * Version 2.0.0 (Cardio-Spec 2026-09-21, Abschnitt 5.2): Die Regel rechnet
 * mit "Belastung" und "Umfang" statt mit Kilogramm und Wiederholungen. Was
 * die Zahlen bedeuten (kg oder Watt, Wiederholungen oder Sekunden), weiss
 * sie nicht und muss sie nicht wissen -- die Einheit steht am Geraetemodell
 * und an der Uebung. Es gibt hier keinen Zweig "wenn Cardio".
 *
 * Die einzige inhaltliche Ergaenzung: ein Block traegt neben der Belastung
 * eine optionale Nebenbelastung (Neigung am Laufband, Trittfrequenz am
 * Ergometer). Die Regel steigert sie nie, verlangt aber, dass sie im Block
 * und zwischen den zwei betrachteten Bloecken gleich ist. Fuer Kraftgeraete
 * ist sie null, und (80, null) gegen (80, null) ist der Vergleich von
 * Version 1.0.0.
 */

export const PROGRESSION_ALGO_VERSION = "2.0.0";

/**
 * Wie viele Einheiten die Regel ansieht. Zwei, weil eine einzelne Einheit
 * ein Ausreisser sein kann und drei die Reaktion traege macht.
 * Schwellenwert, kein Naturgesetz -- vor dem Pilot fachlich zu pruefen.
 */
const HISTORY_WINDOW = 2;

export type WorkoutSetInput = {
  load: number;
  secondaryLoad: number | null;
  volume: number;
  rir: number | null;
  problemFlag: boolean;
};

/** Ein Block: alle Saetze einer Einheit an einem Geraet mit einer Uebung. */
export type BlockInput = {
  performedOn: string;
  sets: WorkoutSetInput[];
};

/** Die Satzzeile, so wie beide Aufrufer sie aus der Datenbank lesen. */
export type SatzZeile = {
  performed_at: string;
  load: number | string;
  secondary_load: number | string | null;
  volume: number;
  rir: number | string | null;
  problem_flag: boolean;
};

/**
 * Saetze zu Bloecken je Trainingstag. Liegt hier statt beim Aufrufer, weil
 * seit dem Abschluss-Screen zwei Stellen dieselbe Gruppierung brauchen --
 * und weil sie den Typ baut, der hier wohnt.
 */
export function toBlocks(rows: SatzZeile[]): BlockInput[] {
  const byDay = new Map<string, BlockInput>();
  for (const row of rows) {
    const day = row.performed_at.slice(0, 10);
    let block = byDay.get(day);
    if (!block) {
      block = { performedOn: day, sets: [] };
      byDay.set(day, block);
    }
    block.sets.push({
      load: Number(row.load),
      secondaryLoad:
        row.secondary_load === null || row.secondary_load === undefined
          ? null
          : Number(row.secondary_load),
      volume: row.volume,
      rir: row.rir === null ? null : Number(row.rir),
      problemFlag: row.problem_flag,
    });
  }
  // Innerhalb eines Tages chronologisch, damit "letzter Satz" stimmt.
  for (const block of byDay.values()) block.sets.reverse();
  return [...byDay.values()];
}

export type ProgressionInput = {
  targetMin: number;
  targetMax: number;
  loadStep: number;
  loadMin: number;
  loadMax: number;
  /** Neuester Block zuerst. */
  history: BlockInput[];
};

export type ProgressionReasonCode =
  | "kein_verlauf"
  | "daten_uneindeutig"
  | "problem_gemeldet"
  | "im_korridor"
  | "korridor_oben_erreicht"
  | "korridor_unten_verfehlt"
  | "geraetegrenze_erreicht";

/** Wird mitgeschrieben, damit ein alter Vorschlag nachvollziehbar bleibt. */
export type ProgressionInputsRecord = {
  targetMin: number;
  targetMax: number;
  loadStep: number;
  loadMin: number;
  loadMax: number;
  currentLoad: number | null;
  currentSecondaryLoad: number | null;
  consideredBlocks: number;
};

export type ProgressionSuggestion = {
  algoVersion: string;
  resultLoad: number | null;
  /**
   * Die Nebenbelastung wird nie gesteigert, nur mitgegeben -- damit der
   * Abschluss-Screen "+0,5 km/h bei 6 %" schreiben kann. Null, wenn es
   * keinen Vorschlag gibt oder das Geraet keine Nebenbelastung hat.
   */
  resultSecondaryLoad: number | null;
  reasonCode: ProgressionReasonCode;
  inputs: ProgressionInputsRecord;
};

/** Belastung und Nebenbelastung eines Blocks -- das Paar, das gleich bleiben muss. */
type Belastungspaar = { load: number; secondaryLoad: number | null };

/**
 * Das Paar des Blocks, oder null wenn die Saetze sich nicht einig sind --
 * in der Belastung ODER in der Nebenbelastung. Ein Block, in dem die
 * Neigung wechselt, hat so wenig einen Ausgangswert wie einer, in dem
 * das Gewicht wechselt.
 */
function uniformLoad(block: BlockInput): Belastungspaar | null {
  const first = block.sets[0];
  if (!first) return null;
  return block.sets.every(
    (set) => set.load === first.load && set.secondaryLoad === first.secondaryLoad,
  )
    ? { load: first.load, secondaryLoad: first.secondaryLoad }
    : null;
}

function samePair(a: Belastungspaar | null, b: Belastungspaar): boolean {
  return a !== null && a.load === b.load && a.secondaryLoad === b.secondaryLoad;
}

function reachedTop(block: BlockInput, targetMax: number): boolean {
  return (
    block.sets.length > 0 && block.sets.every((set) => set.volume >= targetMax)
  );
}

/**
 * Der erste Satz zaehlt: spaetere Saetze fallen durch Ermuedung ohnehin ab.
 * Schafft schon der erste den Korridor nicht, ist die Belastung zu hoch.
 */
function missedBottom(block: BlockInput, targetMin: number): boolean {
  const firstSet = block.sets[0];
  return firstSet !== undefined && firstSet.volume < targetMin;
}

/** Naechstgelegene einstellbare Stufe -- fuer das Ablesen eines Istwerts. */
function snapToNearestStep(load: number, input: ProgressionInput): number {
  const steps = Math.round((load - input.loadMin) / input.loadStep);
  return input.loadMin + steps * input.loadStep;
}

function decide(
  input: ProgressionInput,
  current: Belastungspaar | null,
  resultLoad: number | null,
  reasonCode: ProgressionReasonCode,
): ProgressionSuggestion {
  return {
    algoVersion: PROGRESSION_ALGO_VERSION,
    resultLoad,
    resultSecondaryLoad: resultLoad === null ? null : (current?.secondaryLoad ?? null),
    reasonCode,
    inputs: {
      targetMin: input.targetMin,
      targetMax: input.targetMax,
      loadStep: input.loadStep,
      loadMin: input.loadMin,
      loadMax: input.loadMax,
      currentLoad: current?.load ?? null,
      currentSecondaryLoad: current?.secondaryLoad ?? null,
      consideredBlocks: Math.min(input.history.length, HISTORY_WINDOW),
    },
  };
}

/**
 * Haelt das Ergebnis in den Geraetegrenzen und auf einer einstellbaren Stufe.
 * Verhindert die Grenze die Aenderung, gewinnt sie den Begruendungscode --
 * sonst behauptete der Vorschlag eine Steigerung, die das Geraet nicht hergibt.
 */
function withinMachineLimits(
  input: ProgressionInput,
  current: Belastungspaar,
  target: number,
  reasonCode: ProgressionReasonCode,
): ProgressionSuggestion {
  const clamped = Math.min(Math.max(target, input.loadMin), input.loadMax);
  // Abrunden, damit die Rastung eine Obergrenze nie ueberschreitet.
  const steps = Math.floor((clamped - input.loadMin) / input.loadStep + 1e-9);
  const settable = input.loadMin + steps * input.loadStep;

  if (settable === current.load && target !== current.load) {
    return decide(input, current, settable, "geraetegrenze_erreicht");
  }
  return decide(input, current, settable, reasonCode);
}

export function suggestNextLoad(input: ProgressionInput): ProgressionSuggestion {
  const latest = input.history[0];
  if (!latest) return decide(input, null, null, "kein_verlauf");

  // Wechselt die Belastung (oder die Nebenbelastung) innerhalb eines
  // Blocks, laesst sich kein Ausgangswert ablesen. Konservativ heisst hier:
  // gar nichts vorschlagen.
  const recorded = uniformLoad(latest);
  if (recorded === null) {
    return decide(input, null, null, "daten_uneindeutig");
  }
  const current: Belastungspaar = {
    load: snapToNearestStep(recorded.load, input),
    secondaryLoad: recorded.secondaryLoad,
  };

  // Sicherheitsfeedback schlaegt jede Steigerung.
  if (latest.sets.some((set) => set.problemFlag)) {
    return decide(input, current, current.load, "problem_gemeldet");
  }

  const lastSet = latest.sets[latest.sets.length - 1];
  const previous = input.history[1];

  // "Oberes Ende mit Reserve erreicht": entweder belegt durch RIR (Altdaten;
  // die App erfasst seit dem 11. September keine Reserve mehr), oder durch
  // zwei Einheiten in Folge -- unter denselben Bedingungen, also mit
  // demselben Paar aus Belastung und Nebenbelastung.
  const withReserve =
    lastSet !== undefined && lastSet.rir !== null && lastSet.rir >= 1;
  const topTwice =
    lastSet !== undefined &&
    lastSet.rir === null &&
    previous !== undefined &&
    reachedTop(previous, input.targetMax) &&
    samePair(uniformLoad(previous), current);

  if (reachedTop(latest, input.targetMax) && (withReserve || topTwice)) {
    return withinMachineLimits(
      input,
      current,
      current.load + input.loadStep,
      "korridor_oben_erreicht",
    );
  }

  const missedTwice =
    missedBottom(latest, input.targetMin) &&
    previous !== undefined &&
    missedBottom(previous, input.targetMin) &&
    samePair(uniformLoad(previous), current);

  if (missedTwice) {
    return withinMachineLimits(
      input,
      current,
      current.load - input.loadStep,
      "korridor_unten_verfehlt",
    );
  }

  return decide(input, current, current.load, "im_korridor");
}
