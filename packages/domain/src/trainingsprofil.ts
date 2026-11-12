import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { DomainError } from "./errors.js";
import {
  BEREICHE,
  CARDIO_ARTEN,
  ERFAHRUNG,
  FOKUS_BEREICHE,
  MINUTEN,
  type Bereich,
  type CardioArt,
  type Erfahrung,
  type FokusBereich,
  type Minuten,
} from "./trainingsplan-typen.js";
import { setGoal } from "./goals.js";
import { pruefeWoche, type Wochentag } from "./trainingsplan-woche.js";

export type TrainingProfile = {
  minutes: Minuten;
  experience: Erfahrung;
  focus: FokusBereich[];
  // Wochenraster: feste Kurs- und Cardio-Tage, Krafttage als Wunsch (leer = Generator verteilt).
  kursTage: Wochentag[];
  cardioTage: Wochentag[];
  cardioArten: CardioArt[];
  kraftTage: Wochentag[];
  // Wochenziel als Zaehler (0072): wie oft, nicht wann. kraftProWoche null = noch nicht gesetzt.
  kraftProWoche: number | null;
  cardioProWoche: number;
  cardioMinuten: number;
};
type Zaehler = Pick<TrainingProfile, "kraftProWoche" | "cardioProWoche" | "cardioMinuten">;
const ZAEHLER_SPALTEN: Record<keyof Zaehler, string> = {
  kraftProWoche: "kraft_pro_woche",
  cardioProWoche: "cardio_pro_woche",
  cardioMinuten: "cardio_minuten",
};
type WochenFelder = Pick<TrainingProfile, "kursTage" | "cardioTage" | "cardioArten" | "kraftTage">;
const WOCHEN_FELDER = ["kursTage", "cardioTage", "cardioArten", "kraftTage"] as const;
// Spaltennamen in der Datenbank (0069), parallel zu WOCHEN_FELDER.
const WOCHEN_SPALTEN: Record<(typeof WOCHEN_FELDER)[number], string> = {
  kursTage: "kurs_tage",
  cardioTage: "cardio_tage",
  cardioArten: "cardio_arten",
  kraftTage: "kraft_tage",
};
export type LimitStufe = "meiden" | "vorsichtig";
export type TrainingLimits = { consentAt: string; areas: Partial<Record<Bereich, LimitStufe>> };

const profilSchema = z.object({
  minutes: z
    .number()
    .refine((m): m is Minuten => (MINUTEN as readonly number[]).includes(m), "Unbekannte Trainingsdauer."),
  experience: z.enum(ERFAHRUNG, { message: "Unbekannte Erfahrung." }),
  focus: z
    .array(z.enum(FOKUS_BEREICHE, { message: "Unbekannter Fokusbereich." }))
    .max(2, "Hoechstens zwei Fokusbereiche.")
    .refine((f) => new Set(f).size === f.length, "Ein Fokusbereich nur einmal."),
  // Die Wochenfelder sind optional: Aufrufer von vor dem Wochenraster senden sie nicht,
  // und ein fehlendes Feld heisst "unveraendert", nicht "leeren". Die Pruefung auf
  // Bereich 1..7, doppelte und sich ueberschneidende Tage macht pruefeWoche.
  kursTage: z.array(z.number()).optional(),
  cardioTage: z.array(z.number()).optional(),
  cardioArten: z
    .array(z.enum(CARDIO_ARTEN, { message: "Unbekannte Cardio-Art." }))
    .refine((a) => new Set(a).size === a.length, "Eine Cardio-Art nur einmal.")
    .optional(),
  kraftTage: z.array(z.number()).optional(),
  // Zaehler (0072): fehlend = unveraendert bzw. Standard; kraftProWoche null = nicht gesetzt.
  kraftProWoche: z.number().int().min(1).max(7).nullable().optional(),
  cardioProWoche: z.number().int().min(0).max(7).optional(),
  cardioMinuten: z.number().int().min(10).max(180).optional(),
});

// .strict(): ein unbekannter Bereich ist ein Fehler, kein stilles Verwerfen;
// Gesundheitsdaten sollen nur exakt die erlaubten Schluessel enthalten.
const limitsSchema = z.object({
  einwilligung: z.literal(true, { message: "Ohne ausdrueckliche Einwilligung keine Beschwerden." }),
  areas: z
    .object(
      Object.fromEntries(
        BEREICHE.map((b) => [b, z.enum(["meiden", "vorsichtig"], { message: "Unbekannte Stufe." }).optional()]),
      ),
    )
    .strict("Unbekannter Bereich."),
});

function pruefe<T>(schema: z.ZodType<T>, roh: unknown): T {
  const r = schema.safeParse(roh);
  if (!r.success) throw new DomainError("validation_failed", r.error.issues[0]!.message);
  return r.data;
}

/** Geprueftes Profil, die gesendeten Wochenfelder bleiben als solche erkennbar (fehlend = undefined). */
export type TeilProfil = Omit<TrainingProfile, keyof WochenFelder | keyof Zaehler> &
  Partial<WochenFelder> &
  Partial<Zaehler>;

export function pruefeTeilprofil(roh: unknown): TeilProfil {
  const p = pruefe(profilSchema, roh) as TeilProfil;
  // Nur die gesendeten Felder pruefen; Ueberschneidung mit Gespeichertem prueft saveTrainingProfile.
  pruefeWoche({ kursTage: p.kursTage ?? [], cardioTage: p.cardioTage ?? [], kraftTage: p.kraftTage ?? [] });
  return p;
}

export function pruefeTrainingsprofil(roh: unknown): TrainingProfile {
  const p = pruefeTeilprofil(roh);
  return { ...p, kursTage: p.kursTage ?? [], cardioTage: p.cardioTage ?? [], cardioArten: p.cardioArten ?? [], kraftTage: p.kraftTage ?? [],
    kraftProWoche: p.kraftProWoche ?? null,
    cardioProWoche: p.cardioProWoche ?? 0,
    cardioMinuten: p.cardioMinuten ?? 30,
  };
}

/** Liefert nur die bereinigten areas; die Einwilligung ist damit bestaetigt. */
export function pruefeTrainingsLimits(roh: unknown): { areas: TrainingLimits["areas"] } {
  const g = pruefe(limitsSchema, roh);
  return { areas: g.areas as TrainingLimits["areas"] };
}

export async function getTrainingProfile(client: SupabaseClient, userId: string): Promise<TrainingProfile | null> {
  const { data, error } = await client
    .from("training_profiles")
    .select("minutes, experience, focus, kurs_tage, cardio_tage, cardio_arten, kraft_tage, kraft_pro_woche, cardio_pro_woche, cardio_minuten")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new DomainError("internal", "Das Trainingsprofil konnte nicht gelesen werden.");
  if (!data) return null;
  return {
    minutes: data.minutes,
    experience: data.experience,
    focus: data.focus,
    kursTage: data.kurs_tage,
    cardioTage: data.cardio_tage,
    cardioArten: data.cardio_arten,
    kraftTage: data.kraft_tage,
    kraftProWoche: data.kraft_pro_woche,
    cardioProWoche: data.cardio_pro_woche,
    cardioMinuten: data.cardio_minuten,
  };
}

/**
 * Fuehrt das gesendete Teilprofil mit dem gespeicherten zusammen und liefert die zu
 * schreibenden Wochen- und Zaehlerspalten (nur Gesendetes bzw. daraus Abgeleitetes).
 *
 * Alte App (nur Tagesfelder, ohne Zaehler): kraftProWoche = Anzahl Krafttage (nur wenn > 0,
 * sonst unveraendert -- leer hiess dort "Generator verteilt"), cardioProWoche = Anzahl
 * Cardiotage. So bleiben die Zaehler nach der Migration nicht stehen.
 *
 * pruefeWoche laeuft nur, wenn Tagesfelder mitkommen (Spec 7): ein PUT mit nur Zaehlern
 * darf nicht an gespeicherten Alt-Tagen scheitern. Mit Tagesfeldern wird gegen die
 * gespeicherten geprueft -- sonst kaeme statt validation_failed erst der DB-Check (internal).
 */
export function fuehreProfilZusammen(
  teil: TeilProfil,
  alt: TrainingProfile | null,
): { profil: TrainingProfile; spalten: Record<string, unknown> } {
  const abgeleitet: Partial<Zaehler> = {};
  if (teil.kraftProWoche === undefined && teil.kraftTage !== undefined && teil.kraftTage.length > 0) {
    abgeleitet.kraftProWoche = teil.kraftTage.length;
  }
  if (teil.cardioProWoche === undefined && teil.cardioTage !== undefined) {
    abgeleitet.cardioProWoche = teil.cardioTage.length;
  }
  const z: Partial<Zaehler> = { ...abgeleitet };
  for (const feld of Object.keys(ZAEHLER_SPALTEN) as (keyof Zaehler)[]) {
    if (teil[feld] !== undefined) (z as Record<string, unknown>)[feld] = teil[feld];
  }
  const profil: TrainingProfile = {
    ...teil,
    kursTage: teil.kursTage ?? alt?.kursTage ?? [],
    cardioTage: teil.cardioTage ?? alt?.cardioTage ?? [],
    cardioArten: teil.cardioArten ?? alt?.cardioArten ?? [],
    kraftTage: teil.kraftTage ?? alt?.kraftTage ?? [],
    kraftProWoche: z.kraftProWoche !== undefined ? z.kraftProWoche : (alt?.kraftProWoche ?? null),
    cardioProWoche: z.cardioProWoche ?? alt?.cardioProWoche ?? 0,
    cardioMinuten: z.cardioMinuten ?? alt?.cardioMinuten ?? 30,
  };
  if (teil.kursTage !== undefined || teil.cardioTage !== undefined || teil.kraftTage !== undefined) {
    pruefeWoche(profil);
  }
  const spalten: Record<string, unknown> = {};
  for (const feld of WOCHEN_FELDER) if (teil[feld] !== undefined) spalten[WOCHEN_SPALTEN[feld]] = teil[feld];
  for (const feld of Object.keys(ZAEHLER_SPALTEN) as (keyof Zaehler)[]) {
    if (z[feld] !== undefined) spalten[ZAEHLER_SPALTEN[feld]] = z[feld];
  }
  return { profil, spalten };
}

export async function saveTrainingProfile(
  client: SupabaseClient,
  userId: string,
  input: unknown,
): Promise<TrainingProfile> {
  const teil = pruefeTeilprofil(input);
  // Gespeicherte Felder dazuholen: ein PUT ohne sie laesst sie unveraendert.
  const alt = await getTrainingProfile(client, userId);
  const { profil, spalten: wochen } = fuehreProfilZusammen(teil, alt);
  const { error } = await client.from("training_profiles").upsert(
    {
      user_id: userId,
      minutes: profil.minutes,
      experience: profil.experience,
      focus: profil.focus,
      ...wochen,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id" },
  );
  if (error) throw new DomainError("internal", "Das Trainingsprofil konnte nicht gespeichert werden.");
  // Wochenziel abgleichen: nur wenn kraftProWoche ausdruecklich gesendet wurde und nicht null
  // ist. Aus Krafttagen abgeleitete Zaehler (alte App) gleichen nicht ab -- die alte App
  // setzt weekly_days selbst.
  if (teil.kraftProWoche != null) {
    await setGoal(client, {
      kind: "weekly_days",
      targetValue: Math.min(7, teil.kraftProWoche + profil.cardioProWoche),
    });
  }
  return profil;
}

export async function getTrainingLimits(client: SupabaseClient, userId: string): Promise<TrainingLimits | null> {
  const { data, error } = await client
    .from("training_limits")
    .select("consent_at, areas")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht gelesen werden.");
  if (!data) return null;
  return { consentAt: data.consent_at, areas: data.areas };
}

/**
 * consent_at kommt immer von `now`, nie aus der Eingabe. Jedes PUT erneuert die Einwilligung
 * bewusst: wer Beschwerden aendert, bestaetigt sie mit genau diesem Stand neu.
 */
export async function saveTrainingLimits(
  client: SupabaseClient,
  userId: string,
  input: unknown,
  now: Date,
): Promise<TrainingLimits> {
  const { areas } = pruefeTrainingsLimits(input);
  const stempel = now.toISOString();
  const { error } = await client.from("training_limits").upsert(
    { user_id: userId, consent_at: stempel, areas, updated_at: stempel },
    { onConflict: "user_id" },
  );
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht gespeichert werden.");
  return { consentAt: stempel, areas };
}

/**
 * Einwilligung widerrufen = Zeile loeschen; keine Zeile ist kein Fehler.
 * Die Plaene bereinigt der Trigger training_limits_widerruf (0062) in derselben
 * Transaktion: Flag beschwerdenBeruecksichtigt und die beschwerden_*-Gruende verraten
 * sonst weiter, dass es Beschwerden gab (DSGVO Art. 9) -- auch in Studios, die das
 * Mitglied verlassen hat und deren Zeilen es selbst nicht mehr aendern koennte.
 */
export async function deleteTrainingLimits(client: SupabaseClient, userId: string): Promise<void> {
  const { error } = await client.from("training_limits").delete().eq("user_id", userId);
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht geloescht werden.");
}
