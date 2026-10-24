// Gespeicherte Trainingsplaene (Etappe 2, Task 7; Spec F14: Plaene sind stabil).
// Erzeugen liest Profil, Ziel und Kandidaten und speichert das Ergebnis; Lesen
// berechnet nie neu. Alles laeuft mit dem Client des Mitglieds, damit RLS
// entscheidet -- auch beim Laden der Kandidaten.
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { aktiveZiele } from "./goals.js";
import type { GeneratorEingabe, PlanEinheit } from "./trainingsplan-generator.js";
import { generierePlan } from "./trainingsplan-generator.js";
import { ladeKandidaten } from "./trainingsplan-kandidaten.js";
import { zielAusTrainingGoal } from "./trainingsplan-regeln.js";
import { getTrainingLimits, getTrainingProfile } from "./trainingsprofil.js";

export type PlanStatus = "vorschlag" | "aktiv" | "ersetzt" | "verworfen";

/**
 * Die Generator-Eingabe ohne Kandidatenliste (die verwendeten Uebungen stehen in
 * einheiten) und ohne die Beschwerden selbst: das sind Gesundheitsdaten (DSGVO
 * Art. 9), deren Widerruf training_limits loescht -- Planzeilen sind aber nicht
 * loeschbar, eine Kopie hier ueberlebte den Widerruf. Gespeichert wird nur, ob
 * Beschwerden beruecksichtigt wurden.
 */
export type PlanEingabe = Omit<GeneratorEingabe, "kandidaten" | "beschwerden"> & {
  beschwerdenBeruecksichtigt: boolean;
};

export type TrainingPlan = {
  id: string;
  studioId: string;
  version: number;
  status: PlanStatus;
  regelVersion: string;
  eingabe: PlanEingabe;
  struktur: string;
  einheiten: PlanEinheit[];
  gruende: string[];
  createdAt: string;
  acceptedAt: string | null;
};

type PlanZeile = {
  id: string;
  studio_id: string;
  version: number;
  status: PlanStatus;
  regel_version: string;
  eingabe: PlanEingabe;
  struktur: string;
  einheiten: PlanEinheit[];
  gruende: string[];
  created_at: string;
  accepted_at: string | null;
};

const SPALTEN =
  "id, studio_id, version, status, regel_version, eingabe, struktur, einheiten, gruende, created_at, accepted_at";

function zuPlan(z: PlanZeile): TrainingPlan {
  return {
    id: z.id,
    studioId: z.studio_id,
    version: z.version,
    status: z.status,
    regelVersion: z.regel_version,
    eingabe: z.eingabe,
    struktur: z.struktur,
    einheiten: z.einheiten,
    gruende: z.gruende,
    createdAt: z.created_at,
    acceptedAt: z.accepted_at,
  };
}

/**
 * Fremdes und unbekanntes Studio antworten gleich (not_found), damit die
 * Antwort nicht verraet, welche Studios es gibt (wie requireStudioStaff).
 */
async function requireMitglied(client: SupabaseClient, userId: string, studioId: string): Promise<void> {
  const { data, error } = await client
    .from("studio_memberships")
    .select("id")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new DomainError("internal", "Die Mitgliedschaft konnte nicht geprueft werden.");
  if (!data) throw new DomainError("not_found", "Studio nicht gefunden.");
}

async function leseTrainingGoal(client: SupabaseClient, userId: string): Promise<string | null> {
  const { data, error } = await client.from("profiles").select("training_goal").eq("id", userId).maybeSingle();
  if (error) throw new DomainError("internal", "Das Profil konnte nicht gelesen werden.");
  return (data?.training_goal as string | null | undefined) ?? null;
}

/** Ein Unique-Verstoss heisst: eine gleichzeitige Anfrage war schneller. */
function istUniqueVerstoss(error: { code?: string } | null): boolean {
  return error?.code === "23505";
}

export async function erzeugePlanVorschlag(
  client: SupabaseClient,
  userId: string,
  studioId: string,
): Promise<TrainingPlan> {
  await requireMitglied(client, userId, studioId);

  const [goal, ziele, profil, limits] = await Promise.all([
    leseTrainingGoal(client, userId),
    aktiveZiele(client, userId),
    getTrainingProfile(client, userId),
    getTrainingLimits(client, userId),
  ]);
  const ziel = zielAusTrainingGoal(goal);
  const tage = ziele.weeklyDays ? Number(ziele.weeklyDays.targetValue) : null;
  const fehlt = [!ziel && "ziel", tage === null && "tage", !profil && "trainingsprofil"].filter(
    (x): x is string => Boolean(x),
  );
  if (!ziel || tage === null || !profil) {
    // Der Code steht auch in der Meldung, damit Logs ohne detail lesbar bleiben.
    throw new DomainError(
      "validation_failed",
      "Für einen Plan fehlen noch Angaben im Profil (profil_unvollstaendig).",
      { code: "profil_unvollstaendig", fehlt },
    );
  }

  // Ohne Einwilligung (keine Zeile) gibt es keine Beschwerden -- nie raten.
  const beschwerden = limits?.areas ?? {};
  const eingabe: PlanEingabe = {
    ziel,
    tage,
    minuten: profil.minutes,
    fokus: profil.focus,
    erfahrung: profil.experience,
    beschwerdenBeruecksichtigt: Object.keys(beschwerden).length > 0,
  };
  // PlanNichtMoeglichError laeuft unveraendert durch; er traegt baustein/grund im detail.
  const ergebnis = generierePlan({
    ziel,
    tage,
    minuten: profil.minutes,
    fokus: profil.focus,
    erfahrung: profil.experience,
    beschwerden,
    kandidaten: await ladeKandidaten(client, studioId),
  });

  const { error: verwerfFehler } = await client
    .from("training_plans")
    .update({ status: "verworfen" })
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .eq("status", "vorschlag");
  if (verwerfFehler) throw new DomainError("internal", "Der alte Vorschlag konnte nicht verworfen werden.");

  const { data: letzte, error: versionFehler } = await client
    .from("training_plans")
    .select("version")
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (versionFehler) throw new DomainError("internal", "Die Planversion konnte nicht gelesen werden.");

  const { data, error } = await client
    .from("training_plans")
    .insert({
      user_id: userId,
      studio_id: studioId,
      version: ((letzte?.version as number | undefined) ?? 0) + 1,
      status: "vorschlag",
      regel_version: ergebnis.regelVersion,
      eingabe,
      struktur: ergebnis.struktur,
      einheiten: ergebnis.einheiten,
      gruende: ergebnis.gruende,
    })
    .select(SPALTEN)
    .single();
  if (istUniqueVerstoss(error)) {
    throw new DomainError("conflict", "Gerade wird schon ein Plan erstellt. Bitte noch einmal versuchen.");
  }
  if (error || !data) throw new DomainError("internal", "Der Plan konnte nicht gespeichert werden.");
  return zuPlan(data as PlanZeile);
}

/** Nimmt einen Vorschlag an; alles andere (fremd, verworfen, schon aktiv) ist ein Konflikt. */
export async function acceptPlan(client: SupabaseClient, userId: string, planId: string): Promise<TrainingPlan> {
  const { data, error } = await client.rpc("accept_training_plan", { p_plan_id: planId }).single();
  // P0001: plan_nicht_annehmbar aus der Funktion; 23505: Teilindex, falls doch zwei gleichzeitig.
  if (error?.code === "P0001" || istUniqueVerstoss(error)) {
    throw new DomainError("conflict", "Dieser Plan kann nicht mehr angenommen werden.");
  }
  if (error || !data) throw new DomainError("internal", "Der Plan konnte nicht angenommen werden.");
  const zeile = data as PlanZeile & { user_id: string };
  // Die Funktion prueft auth.uid(); passt der Aufrufer nicht zur userId, ist das ein Programmierfehler.
  if (zeile.user_id !== userId) throw new DomainError("internal", "Der Plan gehoert nicht zum Aufrufer.");
  return zuPlan(zeile);
}

/** Alle Versionen des Paars, neueste zuerst. Liest nur, berechnet nie neu (F14). */
export async function listPlaene(client: SupabaseClient, userId: string, studioId: string): Promise<TrainingPlan[]> {
  const { data, error } = await client
    .from("training_plans")
    .select(SPALTEN)
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .order("version", { ascending: false });
  if (error) throw new DomainError("internal", "Die Plaene konnten nicht gelesen werden.");
  return ((data ?? []) as PlanZeile[]).map(zuPlan);
}
