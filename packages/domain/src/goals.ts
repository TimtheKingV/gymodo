import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

export const GOAL_KINDS = ["weekly_days", "target_weight"] as const;
export type GoalKind = (typeof GOAL_KINDS)[number];

export const zielSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("weekly_days"),
    targetValue: z
      .number()
      .int("Tage sind ganze Zahlen.")
      .min(1, "Zwischen 1 und 7 Tagen.")
      .max(7, "Zwischen 1 und 7 Tagen."),
  }),
  z.object({
    kind: z.literal("target_weight"),
    targetValue: z
      .number()
      .min(20, "Das Zielgewicht liegt zwischen 20 und 400 kg.")
      .max(400, "Das Zielgewicht liegt zwischen 20 und 400 kg.")
      .refine((kg) => Math.round(kg * 10) === kg * 10, "Hoechstens eine Nachkommastelle."),
  }),
]);

export type Ziel = { id: string; kind: GoalKind; targetValue: number; createdAt: string };
export type AktiveZiele = { weeklyDays: Ziel | null; targetWeight: Ziel | null };

export function pruefeZiel(roh: unknown): z.infer<typeof zielSchema> {
  const geprueft = zielSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data;
}

function zuZiel(row: { id: string; kind: string; target_value: number | string; created_at: string }): Ziel {
  return {
    id: row.id,
    kind: row.kind as GoalKind,
    targetValue: Number(row.target_value),
    createdAt: row.created_at,
  };
}

/** Ersetzt das aktive Ziel derselben Sorte -- eine Transaktion in der Datenbank. */
export async function setGoal(client: SupabaseClient, payload: unknown): Promise<Ziel> {
  const eingabe = pruefeZiel(payload);
  await requireUserId(client);
  const { data, error } = await client.rpc("set_member_goal", {
    p_kind: eingabe.kind,
    p_value: eingabe.targetValue,
  });
  if (error || !data) throw new DomainError("internal", "Das Ziel konnte nicht gespeichert werden.");
  // PostgREST liefert eine Zeile eines Composite-Rueckgabetyps als Objekt;
  // ein Array kaeme nur vorgelagert von einer SETOF-Funktion.
  const zeile = Array.isArray(data) ? data[0] : data;
  return zuZiel(zeile);
}

/** Aufgeben, nicht loeschen. Kein aktives Ziel ist kein Fehler. */
export async function dropGoal(client: SupabaseClient, kindRoh: unknown): Promise<void> {
  const kind = z.enum(GOAL_KINDS).safeParse(kindRoh);
  if (!kind.success) throw new DomainError("validation_failed", "Keine bekannte Zielsorte.");
  const userId = await requireUserId(client);
  const { error } = await client
    .from("member_goals")
    .update({ status: "dropped" })
    .eq("user_id", userId)
    .eq("kind", kind.data)
    .eq("status", "active");
  if (error) throw new DomainError("internal", "Das Ziel konnte nicht aufgegeben werden.");
}

/** Die aktiven Ziele -- fuer Bootstrap, /me/sessions und die Zielpruefung. */
export async function aktiveZiele(client: SupabaseClient, userId: string): Promise<AktiveZiele> {
  const { data, error } = await client
    .from("member_goals")
    .select("id, kind, target_value, created_at")
    .eq("user_id", userId)
    .eq("status", "active");
  if (error) throw new DomainError("internal", "Die Ziele konnten nicht gelesen werden.");

  const zeilen = (data ?? []) as Array<{
    id: string;
    kind: string;
    target_value: number | string;
    created_at: string;
  }>;
  const weeklyDaysRow = zeilen.find((row) => row.kind === "weekly_days");
  const targetWeightRow = zeilen.find((row) => row.kind === "target_weight");
  return {
    weeklyDays: weeklyDaysRow ? zuZiel(weeklyDaysRow) : null,
    targetWeight: targetWeightRow ? zuZiel(targetWeightRow) : null,
  };
}

export async function markiereErreicht(client: SupabaseClient, zielId: string): Promise<void> {
  const { error } = await client
    .from("member_goals")
    .update({ status: "reached", reached_at: new Date().toISOString() })
    .eq("id", zielId)
    .eq("status", "active");
  if (error) throw new DomainError("internal", "Das Ziel konnte nicht abgeschlossen werden.");
}
