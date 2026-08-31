/**
 * Deterministischer Gewichtsvorschlag aus der eigenen Historie.
 *
 * Fachliche Grundlage: Spec Abschnitt 8.4 (planlose Variante des
 * Regelprinzips aus Blueprint Paragraf 5.7). Die Funktion ist rein: gleiche
 * Eingabe, gleiches Ergebnis, keine Uhr, kein Zufall, kein Datenbankzugriff.
 *
 * Sie gibt eine Rechnung aus, keine Empfehlung. Was daraus wird, entscheidet
 * das Mitglied -- die Plattform misst nichts (Spec Abschnitt 4.3).
 */

export const PROGRESSION_ALGO_VERSION = "1.0.0";

/**
 * Wie viele Einheiten die Regel ansieht. Zwei, weil eine einzelne Einheit
 * ein Ausreisser sein kann und drei die Reaktion traege macht.
 * Schwellenwert, kein Naturgesetz -- vor dem Pilot fachlich zu pruefen.
 */
const HISTORY_WINDOW = 2;

export type WorkoutSetInput = {
  weightKg: number;
  reps: number;
  rir: number | null;
  problemFlag: boolean;
};

/** Ein Block: alle Saetze einer Einheit an einem Geraet mit einer Uebung. */
export type BlockInput = {
  performedOn: string;
  sets: WorkoutSetInput[];
};

export type ProgressionInput = {
  targetRepsMin: number;
  targetRepsMax: number;
  weightStepKg: number;
  minWeightKg: number;
  maxWeightKg: number;
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
  targetRepsMin: number;
  targetRepsMax: number;
  weightStepKg: number;
  minWeightKg: number;
  maxWeightKg: number;
  currentWeightKg: number | null;
  consideredBlocks: number;
};

export type ProgressionSuggestion = {
  algoVersion: string;
  resultWeightKg: number | null;
  reasonCode: ProgressionReasonCode;
  inputs: ProgressionInputsRecord;
};

/** Gewicht des Blocks, oder null wenn die Saetze sich nicht einig sind. */
function uniformWeight(block: BlockInput): number | null {
  const first = block.sets[0];
  if (!first) return null;
  return block.sets.every((set) => set.weightKg === first.weightKg)
    ? first.weightKg
    : null;
}

function reachedTop(block: BlockInput, targetRepsMax: number): boolean {
  return (
    block.sets.length > 0 && block.sets.every((set) => set.reps >= targetRepsMax)
  );
}

/**
 * Der erste Satz zaehlt: spaetere Saetze fallen durch Ermuedung ohnehin ab.
 * Schafft schon der erste den Korridor nicht, ist das Gewicht zu hoch.
 */
function missedBottom(block: BlockInput, targetRepsMin: number): boolean {
  const firstSet = block.sets[0];
  return firstSet !== undefined && firstSet.reps < targetRepsMin;
}

/** Naechstgelegene einstellbare Stufe -- fuer das Ablesen eines Istwerts. */
function snapToNearestStep(weight: number, input: ProgressionInput): number {
  const steps = Math.round((weight - input.minWeightKg) / input.weightStepKg);
  return input.minWeightKg + steps * input.weightStepKg;
}

function decide(
  input: ProgressionInput,
  currentWeightKg: number | null,
  resultWeightKg: number | null,
  reasonCode: ProgressionReasonCode,
): ProgressionSuggestion {
  return {
    algoVersion: PROGRESSION_ALGO_VERSION,
    resultWeightKg,
    reasonCode,
    inputs: {
      targetRepsMin: input.targetRepsMin,
      targetRepsMax: input.targetRepsMax,
      weightStepKg: input.weightStepKg,
      minWeightKg: input.minWeightKg,
      maxWeightKg: input.maxWeightKg,
      currentWeightKg,
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
  current: number,
  target: number,
  reasonCode: ProgressionReasonCode,
): ProgressionSuggestion {
  const clamped = Math.min(
    Math.max(target, input.minWeightKg),
    input.maxWeightKg,
  );
  // Abrunden, damit die Rastung eine Obergrenze nie ueberschreitet.
  const steps = Math.floor(
    (clamped - input.minWeightKg) / input.weightStepKg + 1e-9,
  );
  const settable = input.minWeightKg + steps * input.weightStepKg;

  if (settable === current && target !== current) {
    return decide(input, current, settable, "geraetegrenze_erreicht");
  }
  return decide(input, current, settable, reasonCode);
}

export function suggestNextWeight(
  input: ProgressionInput,
): ProgressionSuggestion {
  const latest = input.history[0];
  if (!latest) return decide(input, null, null, "kein_verlauf");

  // Wechselt das Gewicht innerhalb eines Blocks, laesst sich kein Ausgangswert
  // ablesen. Konservativ heisst hier: gar nichts vorschlagen.
  const recordedWeight = uniformWeight(latest);
  if (recordedWeight === null) {
    return decide(input, null, null, "daten_uneindeutig");
  }
  const current = snapToNearestStep(recordedWeight, input);

  // Sicherheitsfeedback schlaegt jede Steigerung.
  if (latest.sets.some((set) => set.problemFlag)) {
    return decide(input, current, current, "problem_gemeldet");
  }

  const lastSet = latest.sets[latest.sets.length - 1];
  const previous = input.history[1];

  // "Oberes Ende mit Reserve erreicht": entweder belegt durch RIR, oder --
  // wenn das Mitglied RIR abgeschaltet hat -- durch zwei Einheiten in Folge.
  const withReserve =
    lastSet !== undefined && lastSet.rir !== null && lastSet.rir >= 1;
  const topTwice =
    lastSet !== undefined &&
    lastSet.rir === null &&
    previous !== undefined &&
    reachedTop(previous, input.targetRepsMax) &&
    uniformWeight(previous) === current;

  if (reachedTop(latest, input.targetRepsMax) && (withReserve || topTwice)) {
    return withinMachineLimits(
      input,
      current,
      current + input.weightStepKg,
      "korridor_oben_erreicht",
    );
  }

  const missedTwice =
    missedBottom(latest, input.targetRepsMin) &&
    previous !== undefined &&
    missedBottom(previous, input.targetRepsMin) &&
    uniformWeight(previous) === current;

  if (missedTwice) {
    return withinMachineLimits(
      input,
      current,
      current - input.weightStepKg,
      "korridor_unten_verfehlt",
    );
  }

  return decide(input, current, current, "im_korridor");
}
