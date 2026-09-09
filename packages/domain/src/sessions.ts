import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { ortszeitTeile } from "./serie.js";
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

/** Die Tagesnummer dieses Augenblicks in dieser Zeitzone. */
function tagNummer(zeitpunkt: Date, zeitzone: string): number {
  const teile = ortszeitTeile(zeitpunkt, zeitzone);
  return Math.floor(Date.UTC(teile.jahr, teile.monat - 1, teile.tag) / 86_400_000);
}

/**
 * Wie viele Einheiten in die laufende Woche fallen -- Woche ab Montag,
 * Grenze in der Zeitzone des Studios.
 *
 * Die Zeitzone ist kein Beiwerk: 00:30 MESZ am Montag ist Sonntag 22:30
 * UTC. Ohne sie faellt eine Einheit von Montagnacht in die vorige Woche,
 * und das Mitglied saehe eine andere Woche als sein Studio.
 *
 * Die Deckelung der Liste auf SESSION_LIMIT ist hier unkritisch: eine
 * Woche mit mehr als 50 Einheiten gibt es nicht.
 */
export function zaehleDieseWoche(
  startsAt: string[],
  jetzt: Date,
  zeitzone: string,
): number {
  const heute = tagNummer(jetzt, zeitzone);
  // getUTCDay auf der reinen Tagesnummer: 0 = Sonntag.
  const wochentag = new Date(heute * 86_400_000).getUTCDay();
  const montag = heute - ((wochentag + 6) % 7);

  return startsAt.filter((iso) => tagNummer(new Date(iso), zeitzone) >= montag).length;
}

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

export type SessionsSummary = {
  /** Alle Einheiten, nicht nur die gelieferten (SESSION_LIMIT). */
  totalCount: number;
  /** `null`, wenn kein Studio genannt wurde -- ohne Zeitzone keine Woche. */
  thisWeekCount: number | null;
  lastSessionAt: string | null;
};

export type Sessions = { sessions: SessionSummary[]; summary: SessionsSummary };

export type SessionsOptions = { studioId?: string };

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
export async function getSessions(
  client: SupabaseClient,
  optionen: SessionsOptions = {},
): Promise<Sessions> {
  const userId = await requireUserId(client);

  // Die Gesamtzahl kommt aus einem COUNT, nicht aus der Laenge der Liste:
  // die ist auf SESSION_LIMIT gedeckelt, und "34 gesamt" waere ab der 51.
  // Einheit still falsch -- fuer genau die treuesten Mitglieder.
  const { count } = await client
    .from("workout_sessions")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId);

  const zeitzone = await zeitzoneDesStudios(client, optionen.studioId);

  const { data: sessionRows } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("user_id", userId)
    .order("started_at", { ascending: false })
    .limit(SESSION_LIMIT);

  const sessions = (sessionRows ?? []) as SessionRow[];
  const summary: SessionsSummary = {
    totalCount: count ?? 0,
    thisWeekCount: zeitzone
      ? zaehleDieseWoche(sessions.map((session) => session.started_at), new Date(), zeitzone)
      : null,
    // Die Liste kommt absteigend -- die erste Zeile ist die juengste. Eine
    // noch laufende Einheit zaehlt mit: wer gerade trainiert, hat heute
    // trainiert.
    lastSessionAt: sessions[0]?.started_at ?? null,
  };

  if (sessions.length === 0) return { sessions: [], summary };

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

  return { sessions: summaries, summary };
}

/**
 * Die Zeitzone des Studios, aus dessen Sicht die Woche gezaehlt wird.
 *
 * `null` statt einer Vorgabe: eine erfundene Zeitzone ergaebe eine Zahl,
 * die aussieht wie eine Auskunft. Ohne Studio faellt die Wochenzahl weg,
 * und der Screen zeigt sie nicht an.
 *
 * RLS entscheidet mit: wer nicht Mitglied ist, sieht die Zeile nicht und
 * bekommt damit ebenfalls `null`.
 */
async function zeitzoneDesStudios(
  client: SupabaseClient,
  studioId: string | undefined,
): Promise<string | null> {
  if (!studioId) return null;

  const { data } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle();

  return (data as { timezone: string } | null)?.timezone ?? null;
}
