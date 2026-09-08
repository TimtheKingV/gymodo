import type { SupabaseClient } from "@supabase/supabase-js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
  toBlocks,
  type ProgressionReasonCode,
  type ProgressionSuggestion,
  type SatzZeile,
} from "./progression.js";

/**
 * Was TrainingAbschluss unter "Beim naechsten Mal" je Block zeigt.
 *
 * deltaKg ist der sichtbare Teil ("+2,5"), resultWeightKg der Wert dahinter.
 * Beide sind null, wenn es keinen Vorschlag gibt -- der reasonCode sagt
 * dann, warum.
 */
export type Blockvorschlag = {
  machineId: string;
  exerciseId: string;
  resultWeightKg: number | null;
  deltaKg: number | null;
  reasonCode: ProgressionReasonCode;
  algoVersion: string;
};

/**
 * Die Paare aus Geraet und Uebung dieser Session, in der Reihenfolge ihres
 * ersten Auftretens -- dieselbe Blockdefinition wie im Training selbst
 * (M1-Spec SS5.3: ein Block ist ein Geraet plus eine Uebung).
 */
export function blockPaare(
  rows: Array<{ machine_id: string; exercise_id: string }>,
): Array<{ machineId: string; exerciseId: string }> {
  const gesehen = new Set<string>();
  const paare: Array<{ machineId: string; exerciseId: string }> = [];
  for (const row of rows) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    if (gesehen.has(schluessel)) continue;
    gesehen.add(schluessel);
    paare.push({ machineId: row.machine_id, exerciseId: row.exercise_id });
  }
  return paare;
}

/**
 * Das Delta ist die Zahl, die der Screen zeigt. Es entsteht nur, wenn es
 * beides gibt: einen Vorschlag und ein bisheriges Gewicht, gegen das er
 * sich vergleichen laesst.
 */
export function zuVorschlag(eingabe: {
  machineId: string;
  exerciseId: string;
  suggestion: ProgressionSuggestion;
}): Blockvorschlag {
  const { resultWeightKg, reasonCode, algoVersion, inputs } = eingabe.suggestion;
  const bisher = inputs.currentWeightKg;
  const deltaKg =
    resultWeightKg === null || bisher === null || bisher === undefined
      ? null
      : Number((resultWeightKg - bisher).toFixed(2));

  return {
    machineId: eingabe.machineId,
    exerciseId: eingabe.exerciseId,
    resultWeightKg,
    deltaKg,
    reasonCode,
    algoVersion,
  };
}

/**
 * Vorschlaege fuer alle Bloecke einer beendeten Session.
 *
 * Fuenf Abfragen, unabhaengig von der Blockzahl -- Saetze der Session,
 * Uebungen, Geraetemodelle, Historie ueber alle betroffenen Geraete, und
 * ein Sammel-Insert. Ein Aufruf je Block waere N+1 auf einem Pfad, den
 * jedes beendete Training nimmt.
 *
 * Wird in derselben Anfrage festgehalten wie berechnet (M1-Spec SS8.4):
 * Nachvollziehbarkeit ohne Queue, genau wie beim Geraetevorschlag.
 */
export async function vorschlaegeFuerAbschluss(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<Blockvorschlag[]> {
  const { data: sessionSaetze } = await client
    .from("workout_sets")
    .select("machine_id, exercise_id, studio_id")
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .order("performed_at", { ascending: true });

  const zeilen = (sessionSaetze ?? []) as Array<{
    machine_id: string;
    exercise_id: string;
    studio_id: string;
  }>;
  const paare = blockPaare(zeilen);
  if (paare.length === 0) return [];

  const studioId = zeilen[0]!.studio_id;
  const machineIds = [...new Set(paare.map((p) => p.machineId))];
  const exerciseIds = [...new Set(paare.map((p) => p.exerciseId))];

  const { data: uebungen } = await client
    .from("exercises")
    .select("id, target_reps_min, target_reps_max")
    .in("id", exerciseIds);

  const { data: geraete } = await client
    .from("machines")
    .select(
      "id, equipment_models (weight_step_kg, min_weight_kg, max_weight_kg)",
    )
    .in("id", machineIds);

  // Die Historie aller betroffenen Geraete in einer Abfrage. Dieselbe
  // Fenstergroesse wie in tag-context: mehr als sechs Saetze je Tag ueber
  // den Betrachtungszeitraum traegt der Algorithmus ohnehin nicht.
  const { data: historie } = await client
    .from("workout_sets")
    .select(
      "machine_id, exercise_id, performed_at, weight_kg, reps, rir, problem_flag",
    )
    .eq("user_id", userId)
    .in("machine_id", machineIds)
    .order("performed_at", { ascending: false })
    .limit(paare.length * 60);

  const uebungNach = new Map(
    (uebungen ?? []).map((u) => {
      const row = u as { id: string; target_reps_min: number; target_reps_max: number };
      return [row.id, row];
    }),
  );
  const modellNach = new Map(
    (geraete ?? []).map((g) => {
      const row = g as unknown as {
        id: string;
        equipment_models: {
          weight_step_kg: number | string;
          min_weight_kg: number | string;
          max_weight_kg: number | string | null;
        };
      };
      return [row.id, row.equipment_models];
    }),
  );

  const historieNach = new Map<string, SatzZeile[]>();
  for (const row of (historie ?? []) as Array<SatzZeile & {
    machine_id: string;
    exercise_id: string;
  }>) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    const liste = historieNach.get(schluessel) ?? [];
    liste.push(row);
    historieNach.set(schluessel, liste);
  }

  const vorschlaege: Blockvorschlag[] = [];
  // inputs steht mit im Insert -- die Spalte ist not null (Migration 0015)
  // und will fuer die Nachvollziehbarkeit ohnehin die echten Eingaben, nicht
  // ein leeres Objekt.
  const zeilenFuerInsert: Array<{
    studio_id: string;
    user_id: string;
    machine_id: string;
    exercise_id: string;
    algo_version: string;
    inputs: ProgressionSuggestion["inputs"];
    result_weight_kg: number | null;
    reason_code: ProgressionReasonCode;
  }> = [];

  for (const paar of paare) {
    const uebung = uebungNach.get(paar.exerciseId);
    const modell = modellNach.get(paar.machineId);
    if (!uebung || !modell) continue;

    const suggestion = suggestNextWeight({
      targetRepsMin: uebung.target_reps_min,
      targetRepsMax: uebung.target_reps_max,
      weightStepKg: Number(modell.weight_step_kg),
      minWeightKg: Number(modell.min_weight_kg),
      maxWeightKg: Number(modell.max_weight_kg ?? 9999),
      history: toBlocks(
        historieNach.get(`${paar.machineId}:${paar.exerciseId}`) ?? [],
      ),
    });

    const vorschlag = zuVorschlag({ ...paar, suggestion });
    vorschlaege.push(vorschlag);
    zeilenFuerInsert.push({
      studio_id: studioId,
      user_id: userId,
      machine_id: vorschlag.machineId,
      exercise_id: vorschlag.exerciseId,
      algo_version: PROGRESSION_ALGO_VERSION,
      inputs: suggestion.inputs,
      result_weight_kg: vorschlag.resultWeightKg,
      reason_code: vorschlag.reasonCode,
    });
  }

  if (zeilenFuerInsert.length > 0) {
    await client.from("progression_suggestions").insert(zeilenFuerInsert);
  }

  return vorschlaege;
}
