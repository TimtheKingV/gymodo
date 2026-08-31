import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { requireStudioStaff } from "./studio.js";
import { createTagToken, hashTagToken } from "./tags.js";

/**
 * Der Geraetekatalog aus Sicht des Trainerportals -- Spec 8.2.
 *
 * Kein HTTP, keine Endpoints: das Web ruft diese Funktionen direkt ueber
 * Server Actions auf (Spec 6.1). Trainerfunktionen brauchen keine
 * REST-Vertragsflaeche, solange sie nur im Web laufen.
 *
 * Immer der nutzergebundene Client. Die Studio-Konsistenz -- dass ein Geraet
 * nur auf ein Modell desselben Studios zeigt, eine Uebung nur an ein Modell
 * desselben Studios -- lebt in den Policies, nicht im Schema. Mit dem
 * Service-Role-Schluessel fiele sie ersatzlos weg.
 */

/** Zod-Fehler tragen die Meldung, die der Trainer im Formular sieht. */
function parseOrThrow<T extends z.ZodTypeAny>(
  schema: T,
  input: unknown,
): z.infer<T> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  return parsed.data;
}

const uuid = z.string().uuid();

export const equipmentModelInputSchema = z
  .object({
    studioId: uuid,
    name: z.string().trim().min(1, "Das Geraetemodell braucht einen Namen."),
    manufacturer: z.string().trim().min(1).nullish(),
    weightStepKg: z
      .number()
      .positive("Der Gewichtsschritt muss groesser als null sein."),
    minWeightKg: z.number().min(0).default(0),
    maxWeightKg: z.number().positive().nullish(),
  })
  .refine(
    (werte) =>
      werte.maxWeightKg === null ||
      werte.maxWeightKg === undefined ||
      werte.maxWeightKg >= werte.minWeightKg,
    { message: "Das Maximum liegt unter dem Minimum." },
  );

export type EquipmentModelInput = z.input<typeof equipmentModelInputSchema>;

export async function createEquipmentModel(
  client: SupabaseClient,
  input: EquipmentModelInput,
): Promise<{ id: string }> {
  const werte = parseOrThrow(equipmentModelInputSchema, input);
  const userId = await requireUserId(client);
  await requireStudioStaff(client, werte.studioId, userId);

  const { data, error } = await client
    .from("equipment_models")
    .insert({
      studio_id: werte.studioId,
      name: werte.name,
      manufacturer: werte.manufacturer ?? null,
      weight_step_kg: werte.weightStepKg,
      min_weight_kg: werte.minWeightKg,
      max_weight_kg: werte.maxWeightKg ?? null,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Modell nicht angelegt.");
  }
  return { id: data.id };
}

export const equipmentModelPatchSchema = z.object({
  name: z.string().trim().min(1).optional(),
  manufacturer: z.string().trim().min(1).nullish(),
  weightStepKg: z.number().positive().optional(),
  minWeightKg: z.number().min(0).optional(),
  maxWeightKg: z.number().positive().nullish(),
});

export async function updateEquipmentModel(
  client: SupabaseClient,
  equipmentModelId: string,
  patch: z.input<typeof equipmentModelPatchSchema>,
): Promise<void> {
  const werte = parseOrThrow(equipmentModelPatchSchema, patch);
  const userId = await requireUserId(client);
  const { studioId } = await studioOfModel(client, equipmentModelId);
  await requireStudioStaff(client, studioId, userId);

  const zeile: Record<string, unknown> = {};
  if (werte.name !== undefined) zeile.name = werte.name;
  if (werte.manufacturer !== undefined) zeile.manufacturer = werte.manufacturer;
  if (werte.weightStepKg !== undefined) zeile.weight_step_kg = werte.weightStepKg;
  if (werte.minWeightKg !== undefined) zeile.min_weight_kg = werte.minWeightKg;
  if (werte.maxWeightKg !== undefined) zeile.max_weight_kg = werte.maxWeightKg;
  if (Object.keys(zeile).length === 0) return;

  const { error } = await client
    .from("equipment_models")
    .update(zeile)
    .eq("id", equipmentModelId);
  if (error) throw new DomainError("internal", error.message);
}

/** Studio eines Geraetemodells. RLS blendet fremde Modelle aus. */
async function studioOfModel(
  client: SupabaseClient,
  equipmentModelId: string,
): Promise<{ studioId: string }> {
  const { data } = await client
    .from("equipment_models")
    .select("studio_id")
    .eq("id", equipmentModelId)
    .maybeSingle<{ studio_id: string }>();
  if (!data) {
    throw new DomainError("not_found", "Dieses Geraetemodell gibt es nicht.");
  }
  return { studioId: data.studio_id };
}

export const settingDefinitionInputSchema = z
  .object({
    equipmentModelId: uuid,
    key: z.string().trim().min(1, "Der Parameter braucht einen Schluessel."),
    label: z.string().trim().min(1, "Der Parameter braucht eine Beschriftung."),
    kind: z.enum(["number", "enum"]),
    minValue: z.number().nullish(),
    maxValue: z.number().nullish(),
    stepValue: z.number().positive().nullish(),
    unit: z.string().trim().min(1).nullish(),
    allowedValues: z.array(z.string()).nullish(),
    sortOrder: z.number().int().min(0).default(0),
  })
  .superRefine((werte, ctx) => {
    // Dieselben Regeln wie der Constraint aus 0017 -- hier nur frueher und
    // mit einer Meldung, die im Formular etwas taugt.
    if (werte.kind === "enum") {
      const werteliste = werte.allowedValues ?? [];
      const sauber = werteliste.map((w) => w.trim()).filter((w) => w.length > 0);
      if (sauber.length < 2 || new Set(sauber).size !== sauber.length) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Eine Auswahl braucht mindestens zwei verschiedene Werte.",
        });
      }
    } else if (werte.allowedValues && werte.allowedValues.length > 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Ein Zahlenparameter traegt keine Werteliste.",
      });
    }
    if (
      werte.minValue != null &&
      werte.maxValue != null &&
      werte.maxValue < werte.minValue
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Das Maximum liegt unter dem Minimum.",
      });
    }
  });

export async function createSettingDefinition(
  client: SupabaseClient,
  input: z.input<typeof settingDefinitionInputSchema>,
): Promise<{ id: string }> {
  const werte = parseOrThrow(settingDefinitionInputSchema, input);
  const userId = await requireUserId(client);
  const { studioId } = await studioOfModel(client, werte.equipmentModelId);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client
    .from("equipment_setting_definitions")
    .insert({
      equipment_model_id: werte.equipmentModelId,
      key: werte.key,
      label: werte.label,
      kind: werte.kind,
      min_value: werte.kind === "number" ? (werte.minValue ?? null) : null,
      max_value: werte.kind === "number" ? (werte.maxValue ?? null) : null,
      step_value: werte.kind === "number" ? (werte.stepValue ?? null) : null,
      unit: werte.unit ?? null,
      allowed_values:
        werte.kind === "enum"
          ? werte.allowedValues!.map((w) => w.trim()).filter((w) => w.length > 0)
          : null,
      sort_order: werte.sortOrder,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError(
      error?.code === "23505" ? "conflict" : "internal",
      error?.code === "23505"
        ? "Diesen Schluessel gibt es an dem Modell schon."
        : (error?.message ?? "Parameter nicht angelegt."),
    );
  }
  return { id: data.id };
}

export async function deleteSettingDefinition(
  client: SupabaseClient,
  settingDefinitionId: string,
): Promise<void> {
  const userId = await requireUserId(client);
  const { data } = await client
    .from("equipment_setting_definitions")
    .select("equipment_model_id")
    .eq("id", settingDefinitionId)
    .maybeSingle<{ equipment_model_id: string }>();
  if (!data) throw new DomainError("not_found", "Diesen Parameter gibt es nicht.");

  const { studioId } = await studioOfModel(client, data.equipment_model_id);
  await requireStudioStaff(client, studioId, userId);

  const { error } = await client
    .from("equipment_setting_definitions")
    .delete()
    .eq("id", settingDefinitionId);
  if (error) throw new DomainError("internal", error.message);
}

export const exerciseInputSchema = z
  .object({
    studioId: uuid,
    name: z.string().trim().min(1, "Die Uebung braucht einen Namen."),
    description: z.string().trim().min(1).nullish(),
    targetRepsMin: z.number().int().positive("Mindestens eine Wiederholung."),
    targetRepsMax: z.number().int().positive(),
  })
  .refine((werte) => werte.targetRepsMax >= werte.targetRepsMin, {
    message: "Die obere Wiederholungszahl liegt unter der unteren.",
  });

export async function createExercise(
  client: SupabaseClient,
  input: z.input<typeof exerciseInputSchema>,
): Promise<{ id: string }> {
  const werte = parseOrThrow(exerciseInputSchema, input);
  const userId = await requireUserId(client);
  await requireStudioStaff(client, werte.studioId, userId);

  const { data, error } = await client
    .from("exercises")
    .insert({
      studio_id: werte.studioId,
      name: werte.name,
      description: werte.description ?? null,
      target_reps_min: werte.targetRepsMin,
      target_reps_max: werte.targetRepsMax,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Uebung nicht angelegt.");
  }
  return { id: data.id };
}

/**
 * Uebung an ein Modell haengen. Die Policy aus 0005 erzwingt, dass beide
 * demselben Studio gehoeren -- eine fremde Uebung ist hier gar nicht sichtbar.
 */
export async function attachExerciseToModel(
  client: SupabaseClient,
  input: { equipmentModelId: string; exerciseId: string; sortOrder?: number },
): Promise<{ id: string }> {
  const userId = await requireUserId(client);
  const { studioId } = await studioOfModel(client, input.equipmentModelId);
  await requireStudioStaff(client, studioId, userId);

  const { data: uebung } = await client
    .from("exercises")
    .select("studio_id")
    .eq("id", input.exerciseId)
    .maybeSingle<{ studio_id: string }>();
  if (!uebung || uebung.studio_id !== studioId) {
    throw new DomainError("not_found", "Diese Uebung gibt es nicht.");
  }

  // Ans Ende, wenn keine Position angegeben ist: eine neue Uebung soll die
  // gepflegte Reihenfolge der bestehenden nicht durcheinanderbringen.
  let sortOrder = input.sortOrder;
  if (sortOrder === undefined) {
    const { data: letzte } = await client
      .from("equipment_model_exercises")
      .select("sort_order")
      .eq("equipment_model_id", input.equipmentModelId)
      .order("sort_order", { ascending: false })
      .limit(1)
      .maybeSingle<{ sort_order: number }>();
    sortOrder = (letzte?.sort_order ?? 0) + 1;
  }

  const { data, error } = await client
    .from("equipment_model_exercises")
    .insert({
      equipment_model_id: input.equipmentModelId,
      exercise_id: input.exerciseId,
      sort_order: sortOrder,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError(
      error?.code === "23505" ? "conflict" : "internal",
      error?.code === "23505"
        ? "Diese Uebung haengt schon an dem Modell."
        : (error?.message ?? "Zuordnung nicht angelegt."),
    );
  }
  return { id: data.id };
}

export async function reorderModelExercises(
  client: SupabaseClient,
  input: { equipmentModelId: string; orderedLinkIds: string[] },
): Promise<void> {
  const userId = await requireUserId(client);
  const { studioId } = await studioOfModel(client, input.equipmentModelId);
  await requireStudioStaff(client, studioId, userId);

  const { data: vorhanden } = await client
    .from("equipment_model_exercises")
    .select("id")
    .eq("equipment_model_id", input.equipmentModelId);
  const bekannt = new Set((vorhanden ?? []).map((zeile) => zeile.id));

  // Eine Reihenfolge, die eine fremde Verknuepfung enthaelt, wird ganz
  // abgelehnt -- halb angewendet waere sie schlimmer als gar nicht.
  if (input.orderedLinkIds.some((id) => !bekannt.has(id))) {
    throw new DomainError(
      "validation_failed",
      "Die Reihenfolge enthaelt eine fremde Zuordnung.",
    );
  }

  for (const [index, linkId] of input.orderedLinkIds.entries()) {
    const { error } = await client
      .from("equipment_model_exercises")
      .update({ sort_order: index + 1 })
      .eq("id", linkId);
    if (error) throw new DomainError("internal", error.message);
  }
}

export async function detachExercise(
  client: SupabaseClient,
  linkId: string,
): Promise<void> {
  const userId = await requireUserId(client);
  const { data } = await client
    .from("equipment_model_exercises")
    .select("equipment_model_id")
    .eq("id", linkId)
    .maybeSingle<{ equipment_model_id: string }>();
  if (!data) throw new DomainError("not_found", "Diese Zuordnung gibt es nicht.");

  const { studioId } = await studioOfModel(client, data.equipment_model_id);
  await requireStudioStaff(client, studioId, userId);

  const { error } = await client
    .from("equipment_model_exercises")
    .delete()
    .eq("id", linkId);

  // 0019 haelt das Einweisungsvideo fest: es muss zuerst bewusst weg.
  if (error?.code === "23503") {
    throw new DomainError(
      "conflict",
      "An dieser Uebung haengt ein Einweisungsvideo. Erst das Video loeschen.",
    );
  }
  if (error) throw new DomainError("internal", error.message);
}

export async function createMachine(
  client: SupabaseClient,
  input: {
    studioId: string;
    equipmentModelId: string;
    label: string;
    locationNote?: string | null;
  },
): Promise<{ id: string }> {
  const werte = parseOrThrow(
    z.object({
      studioId: uuid,
      equipmentModelId: uuid,
      label: z.string().trim().min(1, "Das Geraet braucht eine Bezeichnung."),
      locationNote: z.string().trim().min(1).nullish(),
    }),
    input,
  );
  const userId = await requireUserId(client);
  await requireStudioStaff(client, werte.studioId, userId);

  const { data, error } = await client
    .from("machines")
    .insert({
      studio_id: werte.studioId,
      equipment_model_id: werte.equipmentModelId,
      label: werte.label,
      location_note: werte.locationNote ?? null,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Geraet nicht angelegt.");
  }
  return { id: data.id };
}

/** Studio einer Geraeteinstanz. */
async function studioOfMachine(
  client: SupabaseClient,
  machineId: string,
): Promise<string> {
  const { data } = await client
    .from("machines")
    .select("studio_id")
    .eq("id", machineId)
    .maybeSingle<{ studio_id: string }>();
  if (!data) throw new DomainError("not_found", "Dieses Geraet gibt es nicht.");
  return data.studio_id;
}

/**
 * Stilllegen statt loeschen.
 *
 * Fuer ein Geraet, das je einen Tag getragen hat, gibt es keinen Loeschpfad:
 * der Fremdschluessel aus 0008 steht mit "on delete restrict" davor, und das
 * ist Absicht -- ein geloeschtes Geraet nimmt die Zuordnungshistorie mit.
 * Ein stillgelegtes Geraet verschwindet aus der Auswahl und bleibt lesbar.
 */
export async function deactivateMachine(
  client: SupabaseClient,
  machineId: string,
): Promise<void> {
  await setMachineStatus(client, machineId, "inactive");
}

export async function reactivateMachine(
  client: SupabaseClient,
  machineId: string,
): Promise<void> {
  await setMachineStatus(client, machineId, "active");
}

async function setMachineStatus(
  client: SupabaseClient,
  machineId: string,
  status: "active" | "inactive",
): Promise<void> {
  const userId = await requireUserId(client);
  const studioId = await studioOfMachine(client, machineId);
  await requireStudioStaff(client, studioId, userId);

  const { error } = await client
    .from("machines")
    .update({ status })
    .eq("id", machineId);
  if (error) throw new DomainError("internal", error.message);
}

/**
 * Einen Tag anlegen. Der Klartext-Token wird genau einmal zurueckgegeben --
 * gespeichert ist nur sein Hash, es gibt keinen Weg, ihn spaeter noch einmal
 * zu erfahren. Er darf deshalb nirgends protokolliert werden (Spec 10.4).
 *
 * Mit machineId entsteht der Tag sofort aktiv: der Check-Constraint aus 0008
 * laesst 'active' nur zusammen mit einem Geraet zu, ein zweistufiges "erst
 * anlegen, dann aktivieren" waere gar nicht speicherbar.
 */
export async function createTag(
  client: SupabaseClient,
  input: { studioId: string; machineId?: string | null },
): Promise<{ id: string; token: string }> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, input.studioId, userId);

  if (input.machineId) {
    const studioDesGeraets = await studioOfMachine(client, input.machineId);
    if (studioDesGeraets !== input.studioId) {
      throw new DomainError("not_found", "Dieses Geraet gibt es nicht.");
    }
  }

  const token = createTagToken();
  const { data, error } = await client
    .from("machine_tags")
    .insert({
      studio_id: input.studioId,
      machine_id: input.machineId ?? null,
      token_hash: hashTagToken(token),
      status: input.machineId ? "active" : "unassigned",
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Tag nicht angelegt.");
  }
  return { id: data.id, token };
}

export async function assignTag(
  client: SupabaseClient,
  input: { tagId: string; machineId: string },
): Promise<void> {
  const userId = await requireUserId(client);

  const { data: tag } = await client
    .from("machine_tags")
    .select("studio_id, status")
    .eq("id", input.tagId)
    .maybeSingle<{ studio_id: string; status: string }>();
  if (!tag) throw new DomainError("not_found", "Diesen Tag gibt es nicht.");
  await requireStudioStaff(client, tag.studio_id, userId);

  // Ein gesperrter Tag klebt physisch nicht mehr am Geraet oder gilt als
  // kompromittiert. Ihn wiederzubeleben wuerde die Sperre bedeutungslos machen.
  if (tag.status === "revoked") {
    throw new DomainError("conflict", "Ein gesperrter Tag wird nicht wieder vergeben.");
  }

  const studioDesGeraets = await studioOfMachine(client, input.machineId);
  if (studioDesGeraets !== tag.studio_id) {
    throw new DomainError("not_found", "Dieses Geraet gibt es nicht.");
  }

  const { error } = await client
    .from("machine_tags")
    .update({ machine_id: input.machineId, status: "active" })
    .eq("id", input.tagId);
  if (error) throw new DomainError("internal", error.message);
}

/**
 * Sperren, nicht loeschen. machine_id bleibt stehen: sonst waere hinterher
 * nicht mehr nachvollziehbar, an welchem Geraet der Tag geklebt hat.
 */
export async function revokeTag(
  client: SupabaseClient,
  tagId: string,
): Promise<void> {
  const userId = await requireUserId(client);
  const { data: tag } = await client
    .from("machine_tags")
    .select("studio_id")
    .eq("id", tagId)
    .maybeSingle<{ studio_id: string }>();
  if (!tag) throw new DomainError("not_found", "Diesen Tag gibt es nicht.");
  await requireStudioStaff(client, tag.studio_id, userId);

  const { error } = await client
    .from("machine_tags")
    .update({ status: "revoked", revoked_at: new Date().toISOString() })
    .eq("id", tagId);
  if (error) throw new DomainError("internal", error.message);
}

export type CatalogSettingDefinition = {
  id: string;
  key: string;
  label: string;
  kind: string;
  minValue: number | null;
  maxValue: number | null;
  stepValue: number | null;
  unit: string | null;
  allowedValues: string[] | null;
  sortOrder: number;
};

export type CatalogExercise = {
  linkId: string;
  exerciseId: string;
  name: string;
  description: string | null;
  targetRepsMin: number;
  targetRepsMax: number;
  sortOrder: number;
  hasVideo: boolean;
  videoAssetId: string | null;
  videoStoragePath: string | null;
  videoDurationS: number | null;
};

export type CatalogMachine = {
  id: string;
  label: string;
  locationNote: string | null;
  status: string;
  activeTagCount: number;
};

export type CatalogModel = {
  id: string;
  name: string;
  manufacturer: string | null;
  photoPath: string | null;
  weightStepKg: number;
  minWeightKg: number;
  maxWeightKg: number | null;
  settingDefinitions: CatalogSettingDefinition[];
  exercises: CatalogExercise[];
  machines: CatalogMachine[];
};

export type CatalogTag = {
  id: string;
  status: string;
  machineId: string | null;
  createdAt: string;
};

export type StudioCatalog = {
  studioId: string;
  studioName: string;
  models: CatalogModel[];
  tags: CatalogTag[];
};

/**
 * Der ganze Katalog eines Studios in zwei Abfragen.
 *
 * Das Portal zeigt links die Liste und rechts das gewaehlte Objekt mit allen
 * Bereichen -- wer dafuer je Bereich einzeln laedt, baut die Seite aus einem
 * Dutzend Roundtrips zusammen.
 */
export async function getStudioCatalog(
  client: SupabaseClient,
  studioId: string,
): Promise<StudioCatalog> {
  await requireUserId(client);

  const { data: studio } = await client
    .from("studios")
    .select("id, name")
    .eq("id", studioId)
    .maybeSingle<{ id: string; name: string }>();
  if (!studio) {
    throw new DomainError("not_found", "Dieses Studio gibt es nicht.");
  }

  const { data: modelle, error } = await client
    .from("equipment_models")
    .select(
      `id, name, manufacturer, photo_path, weight_step_kg, min_weight_kg, max_weight_kg,
       equipment_setting_definitions (id, key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order),
       equipment_model_exercises (id, sort_order, exercises (id, name, description, target_reps_min, target_reps_max), instruction_assets (id, storage_path, duration_s)),
       machines (id, label, location_note, status, machine_tags (id, status))`,
    )
    .eq("studio_id", studioId)
    .order("name", { ascending: true });
  if (error) throw new DomainError("internal", error.message);

  const { data: tags } = await client
    .from("machine_tags")
    .select("id, status, machine_id, created_at")
    .eq("studio_id", studioId)
    .order("created_at", { ascending: false });

  type ModelRow = {
    id: string;
    name: string;
    manufacturer: string | null;
    photo_path: string | null;
    weight_step_kg: number | string;
    min_weight_kg: number | string;
    max_weight_kg: number | string | null;
    equipment_setting_definitions: Array<{
      id: string;
      key: string;
      label: string;
      kind: string;
      min_value: number | string | null;
      max_value: number | string | null;
      step_value: number | string | null;
      unit: string | null;
      allowed_values: string[] | null;
      sort_order: number;
    }>;
    equipment_model_exercises: Array<{
      id: string;
      sort_order: number;
      exercises: {
        id: string;
        name: string;
        description: string | null;
        target_reps_min: number;
        target_reps_max: number;
      };
      instruction_assets: Array<{
        id: string;
        storage_path: string;
        duration_s: number;
      }>;
    }>;
    machines: Array<{
      id: string;
      label: string;
      location_note: string | null;
      status: string;
      machine_tags: Array<{ id: string; status: string }>;
    }>;
  };

  const zahl = (wert: number | string | null): number | null =>
    wert === null ? null : Number(wert);

  const models = ((modelle ?? []) as unknown as ModelRow[]).map((row) => ({
    id: row.id,
    name: row.name,
    manufacturer: row.manufacturer,
    photoPath: row.photo_path,
    weightStepKg: Number(row.weight_step_kg),
    minWeightKg: Number(row.min_weight_kg),
    maxWeightKg: zahl(row.max_weight_kg),
    settingDefinitions: [...row.equipment_setting_definitions]
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((setting) => ({
        id: setting.id,
        key: setting.key,
        label: setting.label,
        kind: setting.kind,
        minValue: zahl(setting.min_value),
        maxValue: zahl(setting.max_value),
        stepValue: zahl(setting.step_value),
        unit: setting.unit,
        allowedValues: setting.allowed_values,
        sortOrder: setting.sort_order,
      })),
    exercises: [...row.equipment_model_exercises]
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((link) => {
        const video = link.instruction_assets[0] ?? null;
        return {
          linkId: link.id,
          exerciseId: link.exercises.id,
          name: link.exercises.name,
          description: link.exercises.description,
          targetRepsMin: link.exercises.target_reps_min,
          targetRepsMax: link.exercises.target_reps_max,
          sortOrder: link.sort_order,
          // Nie erzwungen (Spec 6.8) -- nur sichtbar gemacht.
          hasVideo: video !== null,
          videoAssetId: video?.id ?? null,
          videoStoragePath: video?.storage_path ?? null,
          videoDurationS: video?.duration_s ?? null,
        };
      }),
    machines: [...row.machines]
      .sort((a, b) => a.label.localeCompare(b.label, "de", { numeric: true }))
      .map((machine) => ({
        id: machine.id,
        label: machine.label,
        locationNote: machine.location_note,
        status: machine.status,
        activeTagCount: machine.machine_tags.filter((tag) => tag.status === "active")
          .length,
      })),
  }));

  return {
    studioId: studio.id,
    studioName: studio.name,
    models,
    tags: (tags ?? []).map((tag) => ({
      id: tag.id,
      status: tag.status,
      machineId: tag.machine_id,
      createdAt: tag.created_at,
    })),
  };
}
