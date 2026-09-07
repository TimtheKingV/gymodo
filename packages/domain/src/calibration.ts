import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Eigene Einstellwerte schreiben.
 *
 * Fehlte bis Sub-Projekt 2 vollstaendig: Tabelle und Insert-Policy stehen
 * seit Migration 0014, beide Lesepfade nutzen sie, aber es gab keinen
 * Schreibweg. M1-Spec SS8.3 Schritt 4 und der Kalibrierungs-Screen brauchen
 * ihn zwingend.
 *
 * Anfuegend, nie ueberschreibend -- die Tabelle hat bewusst weder Update-
 * noch Delete-Policy: eine Aenderung ist eine neue Zeile.
 */
export const recordCalibrationInputSchema = z.object({
  machineId: z.string().uuid(),
  exerciseId: z.string().uuid(),
  settingValues: z.record(z.union([z.number(), z.string()])),
  schemaVersion: z.number().int().min(1),
  source: z.enum(["self", "trainer_assisted"]).default("self"),
});

export type RecordCalibrationInput = z.infer<typeof recordCalibrationInputSchema>;

export type EinstellDefinition = {
  key: string;
  label: string;
  kind: string;
  min_value: number | null;
  max_value: number | null;
  step_value: number | null;
  allowed_values: string[] | null;
};

export type RecordedCalibration = {
  id: string;
  machineId: string;
  exerciseId: string;
  settingValues: unknown;
  schemaVersion: number;
  source: string;
  createdAt: string;
};

/** Toleranz beim Schrittvergleich -- numeric kommt als Gleitkomma zurueck. */
const SCHRITT_TOLERANZ = 1e-6;

/**
 * Prueft die Werte gegen die Einstellparameter des Geraetemodells
 * (designsystem.md SS7.4). Gibt eine Meldung zurueck oder null.
 *
 * Die Meldung nennt immer, was gilt -- nicht nur, dass etwas ungueltig ist
 * (designsystem.md SS5).
 */
export function pruefeEinstellwerte(
  definitionen: EinstellDefinition[],
  werte: Record<string, unknown>,
): string | null {
  const eintraege = Object.entries(werte);
  if (eintraege.length === 0) {
    return "Es wurde kein Einstellwert uebergeben.";
  }

  const nachKey = new Map(definitionen.map((d) => [d.key, d]));

  for (const [key, wert] of eintraege) {
    const definition = nachKey.get(key);
    if (!definition) {
      return `Unbekannter Einstellparameter: ${key}.`;
    }

    if (definition.kind === "enum") {
      if (typeof wert !== "string") {
        return `${definition.label} erwartet eine Auswahl, keinen Zahlenwert.`;
      }
      const erlaubt = definition.allowed_values ?? [];
      if (!erlaubt.includes(wert)) {
        return `${definition.label} erlaubt nur: ${erlaubt.join(", ")}.`;
      }
      continue;
    }

    if (typeof wert !== "number" || !Number.isFinite(wert)) {
      return `${definition.label} erwartet einen Zahlenwert.`;
    }
    if (definition.min_value !== null && wert < definition.min_value) {
      return `${definition.label} liegt unter dem Minimum ${definition.min_value}.`;
    }
    if (definition.max_value !== null && wert > definition.max_value) {
      return `${definition.label} liegt ueber dem Maximum ${definition.max_value}.`;
    }
    if (definition.step_value !== null && definition.step_value > 0) {
      const basis = definition.min_value ?? 0;
      const schritte = (wert - basis) / definition.step_value;
      if (Math.abs(schritte - Math.round(schritte)) > SCHRITT_TOLERANZ) {
        return `${definition.label} geht in Schritten von ${definition.step_value}.`;
      }
    }
  }

  return null;
}

export async function recordCalibration(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<RecordedCalibration> {
  const parsed = recordCalibrationInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const input = parsed.data;

  const userId = await requireUserId(client);

  // Das Studio kommt aus dem Geraet. RLS macht ein fremdes Geraet unsichtbar,
  // der Aufruf endet dann hier statt an einer Policy weiter unten.
  const { data: machine } = await client
    .from("machines")
    .select("studio_id, equipment_model_id")
    .eq("id", input.machineId)
    .maybeSingle<{ studio_id: string; equipment_model_id: string }>();
  if (!machine) {
    throw new DomainError("not_found", "Geraet nicht gefunden.");
  }

  const { data: exercise } = await client
    .from("exercises")
    .select("id")
    .eq("id", input.exerciseId)
    .eq("studio_id", machine.studio_id)
    .maybeSingle<{ id: string }>();
  if (!exercise) {
    throw new DomainError("not_found", "Uebung nicht gefunden.");
  }

  const { data: definitionen } = await client
    .from("equipment_setting_definitions")
    .select("key, label, kind, min_value, max_value, step_value, allowed_values")
    .eq("equipment_model_id", machine.equipment_model_id);

  const fehler = pruefeEinstellwerte(
    (definitionen ?? []) as EinstellDefinition[],
    input.settingValues,
  );
  if (fehler) {
    throw new DomainError("validation_failed", fehler);
  }

  const { data: row, error } = await client
    .from("member_machine_calibrations")
    .insert({
      studio_id: machine.studio_id,
      user_id: userId,
      machine_id: input.machineId,
      exercise_id: input.exerciseId,
      setting_values: input.settingValues,
      schema_version: input.schemaVersion,
      source: input.source,
      // recorded_by bleibt null: die Insert-Policy erzwingt
      // user_id = auth.uid(), ein Trainer weist sich in der Member-App
      // nicht aus. Der Schalter setzt nur die Quelle.
    })
    .select("id, machine_id, exercise_id, setting_values, schema_version, source, created_at")
    .single<{
      id: string;
      machine_id: string;
      exercise_id: string;
      setting_values: unknown;
      schema_version: number;
      source: string;
      created_at: string;
    }>();

  if (error || !row) {
    throw new DomainError(
      "internal",
      error?.message ?? "Einstellung konnte nicht gespeichert werden.",
    );
  }

  return {
    id: row.id,
    machineId: row.machine_id,
    exerciseId: row.exercise_id,
    settingValues: row.setting_values,
    schemaVersion: row.schema_version,
    source: row.source,
    createdAt: row.created_at,
  };
}
