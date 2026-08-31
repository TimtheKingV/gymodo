import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import type { ProblemReason } from "./workout.js";

/**
 * Ab wann eine offene Einheit als vergessen gilt (Spec 5.2).
 *
 * Traege ausgewertet, nicht per Cronjob: der Abschluss entsteht beim
 * naechsten Lesezugriff. Damit bleibt die Regel "kein Async in M1"
 * unangetastet und es entsteht kein Datenmuell.
 */
const IDLE_HOURS_UNTIL_AUTO_COMPLETE = 4;

/** Wie viele Einheiten der Verlauf zurueckreicht. */
const SESSION_LIMIT = 50;

export type SessionBlock = {
  machineId: string;
  machineLabel: string;
  exerciseId: string;
  exerciseName: string;
  sets: Array<{
    setIndex: number;
    weightKg: number;
    reps: number;
    rir: number | null;
    problemFlag: boolean;
    problemReason: ProblemReason | null;
    performedAt: string;
  }>;
};

export type SessionSummary = {
  id: string;
  startedAt: string;
  completedAt: string | null;
  completedReason: "manual" | "auto" | null;
  machineCount: number;
  setCount: number;
  blocks: SessionBlock[];
};

export type Sessions = { sessions: SessionSummary[] };

type SessionRow = {
  id: string;
  started_at: string;
  completed_at: string | null;
  completed_reason: "manual" | "auto" | null;
};

type SetRow = {
  session_id: string;
  machine_id: string;
  exercise_id: string;
  set_index: number;
  weight_kg: number | string;
  reps: number;
  rir: number | string | null;
  problem_flag: boolean;
  problem_reason: ProblemReason | null;
  performed_at: string;
  machines: { label: string };
  exercises: { name: string };
};

/**
 * Der Trainingsverlauf fuer den Home-Tab, einschliesslich der Bloecke und
 * Saetze fuer das Session-Detail (Spec 6.3).
 *
 * Bloecke haben keine eigene Tabelle -- sie werden aus den Saetzen
 * abgeleitet: gruppiert nach (Geraet, Uebung), sortiert nach dem ersten Satz
 * des Blocks (Spec 7.1). Ein zweiter Durchgang am selben Geraet trifft
 * deshalb denselben Block statt einen neuen anzulegen.
 */
export async function getSessions(client: SupabaseClient): Promise<Sessions> {
  const userId = await requireUserId(client);

  const { data: sessionRows } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("user_id", userId)
    .order("started_at", { ascending: false })
    .limit(SESSION_LIMIT);

  const sessions = (sessionRows ?? []) as SessionRow[];
  if (sessions.length === 0) return { sessions: [] };

  const { data: setRows } = await client
    .from("workout_sets")
    .select(
      "session_id, machine_id, exercise_id, set_index, weight_kg, reps, rir, problem_flag, problem_reason, performed_at, machines (label), exercises (name)",
    )
    .eq("user_id", userId)
    .in(
      "session_id",
      sessions.map((session) => session.id),
    )
    .order("performed_at", { ascending: true });

  const setsBySession = new Map<string, SetRow[]>();
  for (const row of (setRows ?? []) as unknown as SetRow[]) {
    const list = setsBySession.get(row.session_id) ?? [];
    list.push(row);
    setsBySession.set(row.session_id, list);
  }

  const idleCutoffMs = IDLE_HOURS_UNTIL_AUTO_COMPLETE * 60 * 60 * 1000;
  const now = Date.now();
  const toAutoComplete: Array<{ id: string; completedAt: string }> = [];

  const summaries = sessions.map((session) => {
    const sets = setsBySession.get(session.id) ?? [];

    const blockOrder: string[] = [];
    const blocks = new Map<string, SessionBlock>();
    for (const row of sets) {
      const id = `${row.machine_id}:${row.exercise_id}`;
      let block = blocks.get(id);
      if (!block) {
        block = {
          machineId: row.machine_id,
          machineLabel: row.machines.label,
          exerciseId: row.exercise_id,
          exerciseName: row.exercises.name,
          sets: [],
        };
        blocks.set(id, block);
        blockOrder.push(id);
      }
      block.sets.push({
        setIndex: row.set_index,
        weightKg: Number(row.weight_kg),
        reps: row.reps,
        rir: row.rir === null ? null : Number(row.rir),
        problemFlag: row.problem_flag,
        problemReason: row.problem_reason,
        performedAt: row.performed_at,
      });
    }

    let completedAt = session.completed_at;
    let completedReason = session.completed_reason;

    if (!completedAt) {
      const lastSet = sets[sets.length - 1];
      const lastActivity = lastSet
        ? Date.parse(lastSet.performed_at)
        : Date.parse(session.started_at);
      if (now - lastActivity > idleCutoffMs) {
        // Der Abschluss liegt beim letzten Satz, nicht bei jetzt. Sonst
        // haette eine vergessene Einheit rueckwirkend Stunden gedauert, in
        // denen niemand trainiert hat -- und die Statistik im Home-Tab waere
        // Fiktion.
        completedAt = new Date(lastActivity).toISOString();
        completedReason = "auto";
        toAutoComplete.push({ id: session.id, completedAt });
      }
    }

    return {
      id: session.id,
      startedAt: session.started_at,
      completedAt,
      completedReason,
      machineCount: new Set(sets.map((row) => row.machine_id)).size,
      setCount: sets.length,
      blocks: blockOrder.map((id) => blocks.get(id)!),
    };
  });

  // Erst antworten laesst sich nicht -- der Schreibvorgang muss durch sein,
  // bevor ein zweiter Lesezugriff dieselbe Einheit noch einmal auswertet.
  for (const entry of toAutoComplete) {
    await client
      .from("workout_sessions")
      .update({ completed_at: entry.completedAt, completed_reason: "auto" })
      .eq("id", entry.id);
  }

  return { sessions: summaries };
}
