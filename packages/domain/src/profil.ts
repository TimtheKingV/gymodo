import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Der Anzeigename eines Mitglieds. Sechzig Zeichen sind grosszuegig fuer
 * einen Vornamen und knapp genug, dass die Kopfkarte im Profil ihn nicht
 * umbrechen muss.
 */
export const anzeigenameSchema = z.object({
  displayName: z
    .string()
    .trim()
    .min(1, "Der Name darf nicht leer sein.")
    .max(60, "Der Name ist zu lang -- hoechstens 60 Zeichen.")
    .refine((wert) => !/[\r\n]/.test(wert), "Der Name darf keinen Zeilenumbruch enthalten."),
});

/** Wirft `DomainError("validation_failed")`, sonst der geputzte Name. */
export function pruefeAnzeigename(roh: unknown): string {
  const geprueft = anzeigenameSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data.displayName;
}

export const SEX = ["female", "male", "diverse"] as const;
export const AGE_BANDS = ["under_18", "18_24", "25_34", "35_44", "45_54", "55_64", "65_plus"] as const;
export const TRAINING_GOALS = ["lose_weight", "build_muscle", "stay_fit", "get_stronger"] as const;

/**
 * Ein Teilobjekt: was fehlt, bleibt; `null` loescht. `.strict()`, damit
 * ein mitgeschickter Abschlusszeitpunkt nicht still verschluckt wird --
 * den setzt ausschliesslich der Server ueber `onboardingDone`.
 */
export const profilSchema = z
  .object({
    displayName: anzeigenameSchema.shape.displayName.optional(),
    sex: z.enum(SEX, { message: "Kein bekanntes Geschlecht." }).nullable().optional(),
    ageBand: z.enum(AGE_BANDS, { message: "Keine bekannte Altersspanne." }).nullable().optional(),
    heightCm: z
      .number()
      .int("Die Groesse ist eine ganze Zahl in Zentimetern.")
      .min(100, "Die Groesse liegt zwischen 100 und 250 cm.")
      .max(250, "Die Groesse liegt zwischen 100 und 250 cm.")
      .nullable()
      .optional(),
    trainingGoal: z.enum(TRAINING_GOALS, { message: "Keine bekannte Richtung." }).nullable().optional(),
    onboardingDone: z.literal(true).optional(),
  })
  .strict();

export type ProfilEingabe = z.infer<typeof profilSchema>;

export type Profil = {
  displayName: string | null;
  sex: (typeof SEX)[number] | null;
  ageBand: (typeof AGE_BANDS)[number] | null;
  heightCm: number | null;
  trainingGoal: (typeof TRAINING_GOALS)[number] | null;
  onboardingCompletedAt: string | null;
};

export function pruefeProfil(roh: unknown): ProfilEingabe {
  const geprueft = profilSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data;
}

/**
 * Der einzige Schreibweg des Profils -- Registrierung (Name), Onboarding
 * (alles auf einmal), Profil (ein Feld, oder eins auf null).
 *
 * `upsert` wie bisher: fuer ein Bestandskonto gibt es keine Zeile. Nur die
 * gesendeten Felder landen im Update -- ein `undefined` darf keine
 * Spalte anfassen, sonst loeschte "Groesse aendern" den Namen.
 */
export async function updateProfile(client: SupabaseClient, payload: unknown): Promise<Profil> {
  const eingabe = pruefeProfil(payload);
  const userId = await requireUserId(client);

  const zeile: Record<string, unknown> = { id: userId };
  if (eingabe.displayName !== undefined) zeile.display_name = eingabe.displayName;
  if (eingabe.sex !== undefined) zeile.sex = eingabe.sex;
  if (eingabe.ageBand !== undefined) zeile.age_band = eingabe.ageBand;
  if (eingabe.heightCm !== undefined) zeile.height_cm = eingabe.heightCm;
  if (eingabe.trainingGoal !== undefined) zeile.training_goal = eingabe.trainingGoal;
  if (eingabe.onboardingDone) zeile.onboarding_completed_at = new Date().toISOString();

  const { data, error } = await client
    .from("profiles")
    .upsert(zeile, { onConflict: "id" })
    .select("display_name, sex, age_band, height_cm, training_goal, onboarding_completed_at")
    .single();

  // Woertlich durchgereicht verriete das die Tabelle "profiles" (siehe
  // respond.ts) -- z. B. genau dann, wenn eine Migration auf dem Server
  // noch fehlt und die RLS-Policy den Insert ablehnt.
  if (error || !data) throw new DomainError("internal", "Das Profil konnte nicht gespeichert werden.");
  return zuProfil(data);
}

export function zuProfil(row: {
  display_name: string | null; sex: string | null; age_band: string | null;
  height_cm: number | null; training_goal: string | null; onboarding_completed_at: string | null;
}): Profil {
  return {
    displayName: row.display_name,
    sex: row.sex as Profil["sex"],
    ageBand: row.age_band as Profil["ageBand"],
    heightCm: row.height_cm,
    trainingGoal: row.training_goal as Profil["trainingGoal"],
    onboardingCompletedAt: row.onboarding_completed_at,
  };
}
