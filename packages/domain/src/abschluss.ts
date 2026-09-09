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

/** Eine Zeile aus progression_suggestions, so wie sie zurueckgelesen wird. */
export type GespeicherteVorschlagZeile = {
  machine_id: string;
  exercise_id: string;
  created_at: string;
  algo_version: string;
  result_weight_kg: number | string | null;
  reason_code: string;
  inputs: { currentWeightKg?: number | string | null } | null;
};

/**
 * Baut die Vorschlaege eines bereits abgeschlossenen Trainings aus den
 * festgehaltenen Zeilen -- ohne zu rechnen und ohne zu schreiben.
 *
 * Welche Zeile zu welchem Block gehoert, entscheidet der Zeitpunkt: der
 * Abschluss schreibt seine Zeilen unmittelbar nach dem Setzen von
 * completed_at, also ist die AELTESTE Zeile eines Blocks ab completedAt
 * genau die, die dieser Abschluss ausgeliefert hat. Spaetere Zeilen
 * desselben Blocks stammen von einem Geraetescan (tag-context) und gehoeren
 * nicht zu diesem Abschluss.
 *
 * Findet sich in diesem Fenster nichts, faellt es auf die neueste Zeile des
 * Blocks zurueck. Das deckt zwei Faelle: Sessions, die vor dieser Aenderung
 * abgeschlossen wurden, und eine Uhrendifferenz zwischen Anwendung
 * (completed_at kommt aus der Node-Uhr) und Datenbank (created_at aus now()).
 * Gibt es ueberhaupt keine Zeile, faellt der Block weg -- was nicht
 * festgehalten wurde, wird nicht behauptet.
 */
export function ausGespeichertenZeilen(
  paare: Array<{ machineId: string; exerciseId: string }>,
  zeilen: GespeicherteVorschlagZeile[],
  completedAt: string,
): Blockvorschlag[] {
  const grenze = Date.parse(completedAt);
  const nachBlock = new Map<string, GespeicherteVorschlagZeile[]>();
  for (const zeile of zeilen) {
    const schluessel = `${zeile.machine_id}:${zeile.exercise_id}`;
    const liste = nachBlock.get(schluessel) ?? [];
    liste.push(zeile);
    nachBlock.set(schluessel, liste);
  }

  const vorschlaege: Blockvorschlag[] = [];
  for (const paar of paare) {
    const liste = nachBlock.get(`${paar.machineId}:${paar.exerciseId}`);
    if (!liste || liste.length === 0) continue;

    const sortiert = [...liste].sort(
      (a, b) => Date.parse(a.created_at) - Date.parse(b.created_at),
    );
    const zeile =
      sortiert.find((k) => Date.parse(k.created_at) >= grenze) ??
      sortiert[sortiert.length - 1]!;

    const ergebnis =
      zeile.result_weight_kg === null || zeile.result_weight_kg === undefined
        ? null
        : Number(zeile.result_weight_kg);
    const bisherRoh = zeile.inputs?.currentWeightKg;
    const bisher =
      bisherRoh === null || bisherRoh === undefined ? null : Number(bisherRoh);
    const deltaKg =
      ergebnis === null || bisher === null
        ? null
        : Number((ergebnis - bisher).toFixed(2));

    vorschlaege.push({
      machineId: paar.machineId,
      exerciseId: paar.exerciseId,
      resultWeightKg: ergebnis,
      deltaKg,
      reasonCode: zeile.reason_code as ProgressionReasonCode,
      algoVersion: zeile.algo_version,
    });
  }
  return vorschlaege;
}

/**
 * Die Bloecke einer Session, in der Reihenfolge ihres ersten Auftretens,
 * samt Studio -- die eine Abfrage, die beide Wege (rechnen und zuruecklesen)
 * gleichermassen brauchen.
 */
async function bloeckeDerSession(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<{
  paare: Array<{ machineId: string; exerciseId: string }>;
  studioId: string | null;
}> {
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
  return { paare, studioId: zeilen[0]?.studio_id ?? null };
}

/**
 * Die Vorschlaege einer SCHON abgeschlossenen Session -- nur lesend.
 *
 * Der idempotente Frueheinstieg von completeSession ist genau dafuer da,
 * nichts noch einmal zu tun. Neu zu rechnen hiesse, ein zweites Mal nach
 * progression_suggestions zu schreiben, und die Tabelle hat keinen
 * eindeutigen Index -- jeder Wiederholer erzeugte Dubletten in genau der
 * Ablage, die die Nachvollziehbarkeit tragen soll (M1-Spec SS8.4).
 */
export async function gespeicherteVorschlaege(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
  completedAt: string,
): Promise<Blockvorschlag[]> {
  const { paare } = await bloeckeDerSession(client, sessionId, userId);
  if (paare.length === 0) return [];

  const machineIds = [...new Set(paare.map((p) => p.machineId))];
  const exerciseIds = [...new Set(paare.map((p) => p.exerciseId))];

  const { data: zeilen } = await client
    .from("progression_suggestions")
    .select(
      "machine_id, exercise_id, created_at, algo_version, result_weight_kg, reason_code, inputs",
    )
    .eq("user_id", userId)
    .in("machine_id", machineIds)
    .in("exercise_id", exerciseIds)
    .order("created_at", { ascending: false })
    .limit(paare.length * 8);

  return ausGespeichertenZeilen(
    paare,
    (zeilen ?? []) as GespeicherteVorschlagZeile[],
    completedAt,
  );
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
 *
 * SCHREIBT. Gehoert deshalb ausschliesslich in den Zweig, der die Session
 * tatsaechlich abschliesst; ein wiederholter Abschluss liest ueber
 * gespeicherteVorschlaege zurueck, statt neu zu rechnen.
 */
export async function vorschlaegeFuerAbschluss(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<Blockvorschlag[]> {
  const { paare, studioId } = await bloeckeDerSession(client, sessionId, userId);
  if (paare.length === 0 || studioId === null) return [];

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

  // Die Historie aller betroffenen Geraete in einer Abfrage. Groesseres
  // Fenster als in tag-context (dort HISTORY_DAYS * 6 = 36 Zeilen fuer EIN
  // Geraet): hier teilen sich alle Uebungen an derselben Maschine eine
  // gemeinsame Abfrage, und ein Block muss auch dann noch genug Zeilen
  // abbekommen, wenn ein anderer Block an derselben Maschine haengt.
  // Deshalb 60 Zeilen je Block statt 36.
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
