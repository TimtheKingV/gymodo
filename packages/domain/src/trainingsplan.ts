// Gespeicherte Trainingsplaene (Etappe 2, Task 7; Spec F14: Plaene sind stabil).
// Erzeugen liest Profil, Ziel und Kandidaten und speichert das Ergebnis; Lesen
// berechnet nie neu. Alles laeuft mit dem Client des Mitglieds, damit RLS
// entscheidet -- auch beim Laden der Kandidaten. Geschrieben wird nur ueber die
// Funktionen create_training_plan/accept_training_plan (0062), die den Plan pruefen.
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { aktiveZiele } from "./goals.js";
import type { GeneratorEingabe, PlanEinheit } from "./trainingsplan-generator.js";
import type { Struktur } from "./trainingsplan-regeln.js";
import { generierePlan, tauschVorgaben } from "./trainingsplan-generator.js";
import { anfaengerphaseVorbei, ladeGezaehlteEinheiten } from "./trainingsplan-bootstrap.js";
import { ladeKandidaten, ladeKatalogStudioId, ladeMerkliste } from "./trainingsplan-kandidaten.js";
import { initialisierePlanGewichte, ohneAbbruch, uebernehmePlanGewichte } from "./plangewichte.js";
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
  struktur: Struktur["key"];
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
  struktur: Struktur["key"];
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
 * Nur fuer den Ort der Merkliste; der Plan selbst gehoert dem Katalog-Studio.
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
  ortId?: string,
): Promise<TrainingPlan> {
  // Der Plan gehoert immer dem Katalog-Studio; der Ort bestimmt nur die Merkliste.
  const katalogId = await ladeKatalogStudioId(client);
  const ort = ortId ?? katalogId;
  if (ort !== katalogId) await requireMitglied(client, userId, ort);

  const [goal, ziele, profil, limits, gezaehlt] = await Promise.all([
    leseTrainingGoal(client, userId),
    aktiveZiele(client, userId),
    getTrainingProfile(client, userId),
    getTrainingLimits(client, userId),
    // Derselbe Zaehler wie im Bootstrap, damit Angebot und neuer Plan zusammenpassen.
    ladeGezaehlteEinheiten(client, userId, new Date()),
  ]);
  const ziel = zielAusTrainingGoal(goal);
  const tage = ziele.weeklyDays ? Number(ziele.weeklyDays.targetValue) : null;
  const fehlt = [!ziel && "ziel", tage === null && "tage", !profil && "trainingsprofil"].filter(
    (x): x is string => Boolean(x),
  );
  if (!ziel || tage === null || !profil) {
    // Der Code steht auch in der Meldung, damit Logs ohne detail lesbar bleiben.
    // Eigener Code statt validation_failed, damit die App gezielt ins Profil leiten kann;
    // detail.fehlt sagt, welche Angaben fehlen.
    throw new DomainError(
      "profil_unvollstaendig",
      "Für einen Plan fehlen noch Angaben im Profil (profil_unvollstaendig).",
      { fehlt },
    );
  }

  // Ohne Einwilligung (keine Zeile) gibt es keine Beschwerden -- nie raten.
  const beschwerden = limits?.areas ?? {};
  // Vom Server aus dem Zaehler des Paars, nie aus der App (F15). Steht in eingabe, damit
  // der Bootstrap das Angebot nach Annahme dieses Plans nicht noch einmal zeigt.
  const anfaengerBeendet = anfaengerphaseVorbei(profil, gezaehlt.length);
  const eingabe: PlanEingabe = {
    ziel,
    tage,
    minuten: profil.minutes,
    fokus: profil.focus,
    erfahrung: profil.experience,
    anfaengerBeendet,
    beschwerdenBeruecksichtigt: Object.keys(beschwerden).length > 0,
  };
  // PlanNichtMoeglichError laeuft unveraendert durch; er traegt baustein/grund im detail.
  const ergebnis = generierePlan({
    ziel,
    tage,
    minuten: profil.minutes,
    fokus: profil.focus,
    erfahrung: profil.experience,
    anfaengerBeendet,
    beschwerden,
    kandidaten: await ladeKandidaten(client, await ladeMerkliste(client, userId, ort)),
  });

  // Pruefen, alten Vorschlag verwerfen, Version vergeben und einfuegen erledigt die
  // Funktion in einer Transaktion (0062); direkt schreiben darf das Mitglied nicht.
  const { data, error } = await client
    .rpc("create_training_plan", {
      p_studio_id: katalogId,
      p_regel_version: ergebnis.regelVersion,
      p_eingabe: eingabe,
      p_struktur: ergebnis.struktur,
      p_einheiten: ergebnis.einheiten,
      p_gruende: ergebnis.gruende,
    })
    .single();
  // plan_ungueltig hiesse: der Generator nannte ein Geraet oder eine Uebung, die das
  // Studio nicht (mehr) hat -- etwa gleichzeitig stillgelegt.
  if (error?.code === "P0001" && error.message === "plan_ungueltig") {
    throw new DomainError("validation_failed", "Der Plan passt nicht zum Katalog.");
  }
  // 42501: zwischen Pruefung und Speichern ausgetreten -- wie oben not_found.
  if (error?.code === "42501") throw new DomainError("not_found", "Studio nicht gefunden.");
  if (istUniqueVerstoss(error)) {
    throw new DomainError("conflict", "Gerade wird schon ein Plan erstellt. Bitte noch einmal versuchen.");
  }
  if (error || !data) throw new DomainError("internal", "Der Plan konnte nicht gespeichert werden.");
  return zuPlan(data as PlanZeile);
}

/** Nimmt einen Vorschlag an; alles andere (fremd, verworfen, schon aktiv) ist ein Konflikt. */
export async function acceptPlan(client: SupabaseClient, userId: string, planId: string): Promise<TrainingPlan> {
  const { data, error } = await client.rpc("accept_training_plan", { p_plan_id: planId }).single();
  // P0001: plan_nicht_annehmbar aus der Funktion (auch nach einem Austritt aus dem
  // Studio); 23505: Teilindex, falls doch zwei gleichzeitig.
  if (error?.code === "P0001" || istUniqueVerstoss(error)) {
    throw new DomainError("conflict", "Dieser Plan kann nicht mehr angenommen werden.");
  }
  if (error || !data) throw new DomainError("internal", "Der Plan konnte nicht angenommen werden.");
  const zeile = data as PlanZeile & { user_id: string };
  // Die Funktion prueft auth.uid(); passt der Aufrufer nicht zur userId, ist das ein Programmierfehler.
  if (zeile.user_id !== userId) throw new DomainError("internal", "Der Plan gehoert nicht zum Aufrufer.");
  const plan = zuPlan(zeile);
  // Startwerte (G12, G13). Scheitert das, ist der Plan trotzdem angenommen; fehlende Ziele
  // setzt der naechste Bootstrap oder Abschluss.
  await ohneAbbruch("Startwerte nach Annahme", () => initialisierePlanGewichte(client, userId, plan));
  return plan;
}

export type TauschGrund = "nicht_vorhanden" | "gefaellt_nicht";

export type PlanTausch = {
  einheitKey: string;
  positionKey: string;
  exerciseId: string;
  modelId: string;
  /** Warum die alte Uebung geht; sie kommt dann auf die Merkliste des Mitglieds. */
  grund?: TauschGrund;
  /** Ort fuer "nicht vorhanden"; fehlt er, gilt das Katalog-Studio (Freies Training). */
  ortId?: string;
};

/**
 * Traegt die alte Uebung in die Merkliste ein. Ein Fehler bricht den Tausch nicht ab
 * (der ist schon gespeichert) und wird mit fester Meldung protokolliert: weder Grund noch
 * Uebung noch Ort stehen im Text -- die Merkliste ist eine Angabe zur Person.
 */
async function merkeAlteUebung(
  client: SupabaseClient,
  userId: string,
  exerciseId: string,
  grund: TauschGrund,
  ortId: string | undefined,
): Promise<void> {
  try {
    const studioId = grund === "gefaellt_nicht" ? null : (ortId ?? (await ladeKatalogStudioId(client)));
    const { error } = await client
      .from("plan_merkliste")
      .insert({ user_id: userId, exercise_id: exerciseId, art: grund, studio_id: studioId });
    // 23505: steht schon auf der Liste -- dann ist alles wie gewuenscht.
    if (error && error.code !== "23505") throw new Error("insert");
  } catch {
    console.error("plan: Merkliste nach Tausch nicht gespeichert");
  }
}

/**
 * Tauscht eine Position (Uebung und Katalogmodell) dauerhaft: swap_training_plan_position legt sofort eine neue
 * aktive Version an (0062, Vorgaben des neuen Typs seit 0065). Fremd, nicht aktiv oder ausgetreten ist ein Konflikt
 * (plan_nicht_annehmbar), alles andere Ungueltige validation_failed.
 */
export async function tauschePlanPosition(
  client: SupabaseClient,
  userId: string,
  planId: string,
  input: PlanTausch,
): Promise<TrainingPlan> {
  // Die Vorgaben haengen am Ziel des Plans (eingabe, je Version unveraendert kopiert);
  // die Funktion waehlt nach dem Typ der neuen Uebung (Uebergabe Punkt 2, 0065).
  const { data: alt, error: e } = await client
    .from("training_plans")
    .select("eingabe, einheiten")
    .eq("id", planId)
    .eq("user_id", userId)
    .maybeSingle();
  if (e) throw new DomainError("internal", "Die Übung konnte nicht getauscht werden.");
  if (!alt) throw new DomainError("conflict", "Dieser Plan kann nicht mehr geändert werden.");
  const { data, error } = await client
    .rpc("swap_training_plan_position", {
      p_plan_id: planId,
      p_einheit_key: input.einheitKey,
      p_position_key: input.positionKey,
      p_exercise_id: input.exerciseId,
      p_model_id: input.modelId,
      p_vorgaben: tauschVorgaben((alt as { eingabe: PlanEingabe }).eingabe),
    })
    .single();
  if (error?.code === "P0001" && error.message === "plan_nicht_annehmbar") {
    throw new DomainError("conflict", "Dieser Plan kann nicht mehr geändert werden.");
  }
  if (error?.code === "P0001" && error.message === "plan_ungueltig") {
    throw new DomainError("validation_failed", "Diese Übung passt nicht an diese Stelle im Plan.");
  }
  // Absichtlich nicht ueber den Code 42501: der steht auch fuer ein verlorenes
  // EXECUTE-Recht ("permission denied for function"), und das ist ein Fehler
  // des Servers, kein "nicht gefunden". 23505: gleichzeitige Anfrage war schneller.
  if (istUniqueVerstoss(error)) {
    throw new DomainError("conflict", "Der Plan wurde gerade geändert. Bitte noch einmal versuchen.");
  }
  if (error || !data) throw new DomainError("internal", "Die Übung konnte nicht getauscht werden.");
  const zeile = data as PlanZeile & { user_id: string };
  if (zeile.user_id !== userId) throw new DomainError("internal", "Der Plan gehoert nicht zum Aufrufer.");
  const plan = zuPlan(zeile);
  if (input.grund) {
    const alteUebung = (alt as { einheiten: PlanEinheit[] }).einheiten
      .find((e) => e.key === input.einheitKey)
      ?.positionen.find((p) => p.key === input.positionKey)?.exerciseId;
    if (alteUebung && alteUebung !== input.exerciseId) {
      await merkeAlteUebung(client, userId, alteUebung, input.grund, input.ortId);
    }
  }
  // G9: unveraenderte Positionen behalten ihr Ziel, die getauschte bekommt einen Startwert.
  await ohneAbbruch("Ziele nach Tausch", async () => {
    await uebernehmePlanGewichte(client, userId, planId, plan);
    await initialisierePlanGewichte(client, userId, plan);
  });
  return plan;
}

/** Alle Versionen des Mitglieds, neueste zuerst. Liest nur, berechnet nie neu (F14). */
export async function listPlaene(client: SupabaseClient, userId: string): Promise<TrainingPlan[]> {
  const { data, error } = await client
    .from("training_plans")
    .select(SPALTEN)
    .eq("user_id", userId)
    .order("version", { ascending: false });
  if (error) throw new DomainError("internal", "Die Plaene konnten nicht gelesen werden.");
  return ((data ?? []) as PlanZeile[]).map(zuPlan);
}

/**
 * Der aktive Plan des Mitglieds (hoechstens einer, im Katalog-Studio), oder null.
 * Kein Filter ueber Mitgliedschaften: der Plan haengt nicht an einem Studio.
 */
export async function aktiverKatalogPlan(client: SupabaseClient, userId: string): Promise<TrainingPlan | null> {
  // Nur das Katalog-Studio: ein Altbestand mit aktiven Plaenen normaler Studios
  // (Prod vor Migration 0066) liesse maybeSingle sonst an zwei Zeilen scheitern.
  const katalogId = await ladeKatalogStudioId(client);
  const { data, error } = await client
    .from("training_plans")
    .select(SPALTEN)
    .eq("user_id", userId)
    .eq("studio_id", katalogId)
    .eq("status", "aktiv")
    .maybeSingle();
  if (error) throw new DomainError("internal", "Der Plan konnte nicht gelesen werden.");
  return data ? zuPlan(data as PlanZeile) : null;
}
