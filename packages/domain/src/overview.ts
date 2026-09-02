import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import type { ProblemReason } from "./workout.js";

/**
 * Der Ueberblick, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 4.
 *
 * Diese Datei uebersetzt nur -- sie rechnet nichts. Die Summen entstehen in
 * studio_overview (0034), weil die Rohzeilen dort noch erreichbar sind und
 * hier nicht mehr. Wer hier eine Kennzahl ergaenzen will, ergaenzt sie in
 * der Funktion; das ist die Absicht.
 */

export type OverviewMachine = {
  machineId: string;
  label: string;
  status: "active" | "inactive";
  sets: number;
};

export type OverviewProblem = {
  machineId: string;
  label: string;
  reason: ProblemReason | null;
  count: number;
};

export type StudioOverview = {
  days: number;
  activeMembers: number;
  /**
   * `null` heisst nicht "keine", sondern "verdeckt": unterhalb der
   * Mindestzahl gaebe die Satzzahl das Trainingspensum weniger Personen
   * preis. Die Oberflaeche muss das unterscheiden koennen -- eine 0 waere
   * eine Aussage ueber das Studio, die so nicht stimmt.
   */
  sets: number | null;
  problemReports: number | null;
  /** Ab wie vielen erfassenden Personen es Trainingszahlen gibt. */
  minMembers: number;
  breakdown: boolean;
  topMachines: OverviewMachine[];
  problems: OverviewProblem[];
};

type RohUebersicht = {
  days: number;
  active_members: number;
  sets: number | null;
  problem_reports: number | null;
  min_members: number;
  breakdown: boolean;
  top_machines: { machine_id: string; label: string; status: string; sets: number }[];
  problems: { machine_id: string; label: string; reason: string | null; count: number }[];
};

/**
 * `null` heisst: der Aufrufer ist kein Personal dieses Studios. Kein Fehler
 * -- die Funktion antwortet fuer ein fremdes und fuer ein nicht
 * existierendes Studio gleich.
 */
export async function getStudioOverview(
  client: SupabaseClient,
  studioId: string,
  days = 30,
): Promise<StudioOverview | null> {
  const { data, error } = await client.rpc("studio_overview", {
    p_studio_id: studioId,
    p_days: days,
  });
  if (error) throw new DomainError("internal", error.message);
  if (!data) return null;

  const roh = data as RohUebersicht;
  return {
    days: roh.days,
    activeMembers: roh.active_members,
    sets: roh.sets,
    problemReports: roh.problem_reports,
    minMembers: roh.min_members,
    breakdown: roh.breakdown,
    topMachines: roh.top_machines.map((zeile) => ({
      machineId: zeile.machine_id,
      label: zeile.label,
      status: zeile.status as OverviewMachine["status"],
      sets: zeile.sets,
    })),
    problems: roh.problems.map((zeile) => ({
      machineId: zeile.machine_id,
      label: zeile.label,
      reason: (zeile.reason as ProblemReason | null) ?? null,
      count: zeile.count,
    })),
  };
}
