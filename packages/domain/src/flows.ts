import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";

export type FlowSchritt = {
  position: number;
  name: string;
  beschreibung: string | null;
  workS: number;
  restS: number;
  istWarmup: boolean;
};

export type Flow = {
  id: string;
  studioId: string;
  key: string;
  titel: string;
  beschreibung: string | null;
  level: "einsteiger" | "mittel" | "fortgeschritten" | null;
  schritte: FlowSchritt[];
  dauerS: number;
};

export type FlowRunEingabe = {
  id: string;
  flowId: string;
  startedAt: string;
  endedAt: string;
  lastStep: number;
  outcome: "finished" | "aborted";
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Gesamtdauer in Sekunden: Arbeit plus Pause aller Schritte. */
export function flowDauerS(schritte: Pick<FlowSchritt, "workS" | "restS">[]): number {
  return schritte.reduce((summe, s) => summe + s.workS + s.restS, 0);
}

/** Prueft einen gemeldeten Durchlauf gegen die Schrittzahl des Flows. */
export function pruefeFlowRun(run: FlowRunEingabe, schrittAnzahl: number): FlowRunEingabe {
  if (!UUID.test(run.id)) throw new DomainError("validation_failed", "Die Lauf-ID ist keine gueltige UUID.");
  const start = Date.parse(run.startedAt);
  const ende = Date.parse(run.endedAt);
  if (Number.isNaN(start) || Number.isNaN(ende)) throw new DomainError("validation_failed", "Start und Ende muessen gueltige Zeitpunkte sein.");
  if (ende < start) throw new DomainError("validation_failed", "Das Ende liegt vor dem Start.");
  if (!Number.isInteger(run.lastStep) || run.lastStep < 1 || run.lastStep > schrittAnzahl) {
    throw new DomainError("validation_failed", "Der letzte Schritt liegt ausserhalb des Flows.");
  }
  if (run.outcome === "finished" && run.lastStep !== schrittAnzahl) {
    throw new DomainError("validation_failed", "Ein beendeter Flow muss beim letzten Schritt enden.");
  }
  return run;
}

type SchrittZeile = {
  position: number;
  name: string;
  beschreibung: string | null;
  work_s: number;
  rest_s: number;
  is_warmup: boolean;
};

type FlowZeile = {
  id: string;
  studio_id: string;
  key: string;
  titel: string;
  beschreibung: string | null;
  level: Flow["level"];
  flow_steps: SchrittZeile[] | null;
};

/** Alle sichtbaren Flows (nach Titel), Schritte nach Position. */
export async function listFlows(client: SupabaseClient): Promise<Flow[]> {
  const { data, error } = await client
    .from("flows")
    .select("id, studio_id, key, titel, beschreibung, level, flow_steps(position, name, beschreibung, work_s, rest_s, is_warmup)")
    .order("titel", { ascending: true });
  if (error) throw new DomainError("internal", "Flows konnten nicht geladen werden.");
  return ((data ?? []) as unknown as FlowZeile[]).map((f) => {
    const schritte: FlowSchritt[] = (f.flow_steps ?? [])
      .map((s) => ({
        position: s.position,
        name: s.name,
        beschreibung: s.beschreibung,
        workS: s.work_s,
        restS: s.rest_s,
        istWarmup: s.is_warmup,
      }))
      .sort((a, b) => a.position - b.position);
    return {
      id: f.id,
      studioId: f.studio_id,
      key: f.key,
      titel: f.titel,
      beschreibung: f.beschreibung,
      level: f.level,
      schritte,
      dauerS: flowDauerS(schritte),
    };
  });
}

/** Speichert einen Durchlauf. Idempotent: dieselbe `id` erneut zu senden aendert nichts. */
export async function recordFlowRun(client: SupabaseClient, userId: string, run: FlowRunEingabe): Promise<void> {
  const flow = await client
    .from("flows")
    .select("studio_id, flow_steps(position)")
    .eq("id", run.flowId)
    .maybeSingle();
  if (flow.error) throw new DomainError("internal", "Der Flow konnte nicht geladen werden.");
  if (!flow.data) throw new DomainError("not_found", "Der Flow wurde nicht gefunden.");
  const zeile = flow.data as unknown as { studio_id: string; flow_steps: { position: number }[] | null };
  pruefeFlowRun(run, (zeile.flow_steps ?? []).length);
  const { error } = await client.from("flow_runs").upsert(
    {
      id: run.id,
      flow_id: run.flowId,
      user_id: userId,
      studio_id: zeile.studio_id,
      started_at: run.startedAt,
      ended_at: run.endedAt,
      last_step: run.lastStep,
      outcome: run.outcome,
    },
    { onConflict: "id", ignoreDuplicates: true },
  );
  if (error) throw new DomainError("internal", "Der Durchlauf konnte nicht gespeichert werden.");
}
