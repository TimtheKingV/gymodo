// Plaene im Bootstrap (Etappe 3, Task 6): Zaehler, naechste Einheit, Tauschkandidaten und
// das Angebot zum Ende der Anfaengerphase. Die Regeln laufen nur hier auf dem Server (F15);
// die App zeigt nur an, was hier steht. Die reine Zaehlregel ist vom Laden getrennt, damit
// sie ohne Datenbank testbar bleibt.
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { einheitZaehlt, naechsteEinheitKey, type PositionStatus } from "./trainingsplan-ablauf.js";
import { filtereKandidaten, type Kandidat } from "./trainingsplan-auswahl.js";
import type { PlanEinheit } from "./trainingsplan-generator.js";
import { ladeKandidaten } from "./trainingsplan-kandidaten.js";
import type { Baustein } from "./trainingsplan-typen.js";
// Nur der Typ: trainingsplan.ts importiert umgekehrt den Zaehler, ein Laufzeitzyklus waere unnoetig.
import type { TrainingPlan } from "./trainingsplan.js";
import type { TrainingLimits, TrainingProfile } from "./trainingsprofil.js";

/**
 * Wie IDLE_HOURS_UNTIL_AUTO_COMPLETE in sessions.ts: eine nie beendete Einheit gilt ab
 * dann als abgeschlossen. Dieselbe Zahl, damit Verlauf und Zaehler nicht auseinanderlaufen.
 */
const STILLSTAND_MS = 4 * 60 * 60 * 1000;
/** Mehr Einheiten braucht weder die Folge noch die Schwelle von 8; haelt den Abruf klein. */
const SESSION_LIMIT = 200;
/**
 * Sessions je Status-Abfrage. PostgREST liefert hoechstens 1000 Zeilen (config.toml
 * max_rows); bei 50 Sessions mit je unter 20 Positionen bleibt jede Abfrage darunter.
 */
const STATUS_CHUNK = 50;
/** Saetze je Abfrage fuer die letzte Satzzeit offener Sessions, siehe ladeLetzteSaetze. */
const SATZ_LIMIT = 1000;

export type GezaehlteEinheit = { sessionId: string; einheitKey: string; startedAt: string };

export type SessionFuerZaehler = {
  id: string;
  einheitKey: string;
  startedAt: string;
  completedAt: string | null;
  letzterSatzAm: string | null;
  /** Mindestens eine Position erledigt oder optional (einheitZaehlt). */
  zaehlt: boolean;
};

/**
 * Gezaehlte Einheiten, aufsteigend nach Start. Eine laufende Einheit zaehlt noch nicht,
 * sonst sprange die naechste Einheit mitten im Training weiter; ohne Satz und ohne Abschluss
 * ist nichts trainiert worden.
 */
export function gezaehlteEinheiten(sessions: SessionFuerZaehler[], jetzt: Date): GezaehlteEinheit[] {
  const abgeschlossen = (s: SessionFuerZaehler) =>
    s.completedAt !== null ||
    (s.letzterSatzAm !== null && jetzt.getTime() - new Date(s.letzterSatzAm).getTime() > STILLSTAND_MS);
  return sessions
    .filter((s) => s.zaehlt && abgeschlossen(s))
    .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime())
    .map((s) => ({ sessionId: s.id, einheitKey: s.einheitKey, startedAt: s.startedAt }));
}

/**
 * Statuszeilen als Ablaufzustand, damit die Zaehlregel genau die aus trainingsplan-ablauf.ts
 * ist. Bewusst nur der Status: die Zeilen koennen zu einer NEUEREN Planversion gehoeren als
 * workout_sessions.plan_id (Tausch waehrend der Einheit, 0063); die Schluessel gegen den
 * gebundenen Plan aufzuloesen, wuerde solche Einheiten verlieren.
 */
function zaehltNachStatus(stati: PositionStatus[]): boolean {
  return einheitZaehlt({
    positionen: stati.map((status, i) => ({
      key: String(i),
      exerciseId: "",
      hauptmuskeln: [],
      cardio: false,
      status,
      ersatzExerciseId: null,
    })),
    ungeplanteGesehen: [],
  });
}

function stuecke<T>(liste: T[], groesse: number): T[][] {
  const ergebnis: T[][] = [];
  for (let i = 0; i < liste.length; i += groesse) ergebnis.push(liste.slice(i, i + groesse));
  return ergebnis;
}

/**
 * Juengster Satz je Session. "Letzter Satz je Gruppe" geht ueber PostgREST nicht in einer
 * Abfrage (siehe SET_SCAN_LIMIT in bootstrap.ts); absteigend gelesen ist der erste Treffer
 * je Session der juengste. Nur wenn die Grenze erreicht wurde, kann eine fehlende Session
 * noch aeltere Saetze haben -- dann einzeln nachsehen, statt "keine Saetze" zu raten.
 */
async function ladeLetzteSaetze(client: SupabaseClient, sessionIds: string[]): Promise<Map<string, string>> {
  const letzte = new Map<string, string>();
  if (sessionIds.length === 0) return letzte;
  const { data, error } = await client
    .from("workout_sets")
    .select("session_id, performed_at")
    .in("session_id", sessionIds)
    .order("performed_at", { ascending: false })
    .limit(SATZ_LIMIT);
  if (error) throw new DomainError("internal", "Die Saetze konnten nicht gelesen werden.");
  const zeilen = (data ?? []) as Array<{ session_id: string; performed_at: string }>;
  for (const z of zeilen) if (!letzte.has(z.session_id)) letzte.set(z.session_id, z.performed_at);
  if (zeilen.length < SATZ_LIMIT) return letzte;

  for (const id of sessionIds.filter((x) => !letzte.has(x))) {
    const { data: einer, error: e } = await client
      .from("workout_sets")
      .select("performed_at")
      .eq("session_id", id)
      .order("performed_at", { ascending: false })
      .limit(1)
      .maybeSingle<{ performed_at: string }>();
    if (e) throw new DomainError("internal", "Die Saetze konnten nicht gelesen werden.");
    if (einer) letzte.set(id, einer.performed_at);
  }
  return letzte;
}

/**
 * Gezaehlte Einheiten des Paars (Nutzer, Studio) ueber ALLE Planversionen: der Zaehler
 * soll bei einem Tausch oder neuen Plan nicht von vorn beginnen. Gelesen werden die
 * neuesten SESSION_LIMIT Sessions mit Plan; Saetze nur fuer nie beendete, denn nur dort
 * entscheidet der letzte Satz.
 */
export async function ladeGezaehlteEinheiten(
  client: SupabaseClient,
  userId: string,
  studioId: string,
  jetzt: Date,
): Promise<GezaehlteEinheit[]> {
  const { data, error } = await client
    .from("workout_sessions")
    .select("id, plan_einheit_key, started_at, completed_at")
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .not("plan_id", "is", null)
    .order("started_at", { ascending: false })
    .limit(SESSION_LIMIT);
  if (error) throw new DomainError("internal", "Die Einheiten konnten nicht gelesen werden.");
  const sessions = (data ?? []) as Array<{
    id: string;
    plan_einheit_key: string;
    started_at: string;
    completed_at: string | null;
  }>;
  if (sessions.length === 0) return [];

  const stati = new Map<string, PositionStatus[]>();
  for (const teil of stuecke(sessions.map((s) => s.id), STATUS_CHUNK)) {
    // Nur die Stati, die zaehlen koennen: haelt die Zeilenzahl klein.
    const { data: zeilen, error: e } = await client
      .from("session_plan_status")
      .select("session_id, status")
      .in("session_id", teil)
      .in("status", ["erledigt", "optional"]);
    if (e) throw new DomainError("internal", "Der Planstatus konnte nicht gelesen werden.");
    for (const z of (zeilen ?? []) as Array<{ session_id: string; status: PositionStatus }>) {
      stati.set(z.session_id, [...(stati.get(z.session_id) ?? []), z.status]);
    }
  }

  const zaehlt = (id: string) => zaehltNachStatus(stati.get(id) ?? []);
  const offen = sessions.filter((s) => s.completed_at === null && zaehlt(s.id)).map((s) => s.id);
  const letzte = await ladeLetzteSaetze(client, offen);

  return gezaehlteEinheiten(
    sessions.map((s) => ({
      id: s.id,
      einheitKey: s.plan_einheit_key,
      startedAt: s.started_at,
      completedAt: s.completed_at,
      letzterSatzAm: letzte.get(s.id) ?? null,
      zaehlt: zaehlt(s.id),
    })),
    jetzt,
  );
}

/** Ab so vielen gezaehlten Einheiten endet die Anfaengerphase bei Erfahrung "neu". */
export const ANFAENGER_EINHEITEN = 8;

/** Ob die Anfaengerphase vorbei ist; Grundlage fuer Angebot und neuen Plan. */
export function anfaengerphaseVorbei(profil: TrainingProfile | null, einheitenErledigt: number): boolean {
  return profil?.experience === "neu" && einheitenErledigt >= ANFAENGER_EINHEITEN;
}

export type PlanAlternative = { exerciseId: string; machineId: string };

export type PlanFuerApp = {
  planId: string;
  studioId: string;
  version: number;
  regelVersion: string;
  struktur: string;
  einheiten: PlanEinheit[];
  gruende: string[];
  naechsteEinheitKey: string;
  zuletztEinheitKey: string | null;
  einheitenErledigt: number;
  anfaengerUebergang: boolean;
  alternativen: Partial<Record<Baustein, PlanAlternative[]>>;
};

/**
 * Tauschkandidaten je Baustein: "meiden" faellt heraus, "vorsichtig" steht hinten, sonst
 * die Reihenfolge von ladeKandidaten. Ausgegeben werden nur exerciseId und machineId --
 * kein Bereich und kein Vorsichtig-Kennzeichen, denn daraus liessen sich die Beschwerden
 * (Gesundheitsdaten) ablesen.
 */
export function alternativenJeBaustein(
  kandidaten: Kandidat[],
  beschwerden: TrainingLimits["areas"],
): PlanFuerApp["alternativen"] {
  const ergebnis: PlanFuerApp["alternativen"] = {};
  for (const k of filtereKandidaten(kandidaten, beschwerden)) {
    (ergebnis[k.baustein] ??= []).push({ exerciseId: k.exerciseId, machineId: k.machineId });
  }
  return ergebnis;
}

/** Setzt den Plan fuer die App zusammen; rein, damit die Regeln ohne Datenbank pruefbar sind. */
export function planFuerApp(
  plan: TrainingPlan,
  gezaehlt: GezaehlteEinheit[],
  profil: TrainingProfile | null,
  alternativen: PlanFuerApp["alternativen"],
): PlanFuerApp {
  const zuletzt = gezaehlt.at(-1)?.einheitKey ?? null;
  return {
    planId: plan.id,
    studioId: plan.studioId,
    version: plan.version,
    regelVersion: plan.regelVersion,
    struktur: plan.struktur,
    einheiten: plan.einheiten,
    gruende: plan.gruende,
    naechsteEinheitKey: naechsteEinheitKey(plan.einheiten.map((e) => e.key), zuletzt),
    zuletztEinheitKey: zuletzt,
    einheitenErledigt: gezaehlt.length,
    // Wer schon einen Plan mit beendeter Anfaengerphase angenommen hat, bekommt das
    // Angebot nicht noch einmal.
    anfaengerUebergang:
      anfaengerphaseVorbei(profil, gezaehlt.length) && plan.eingabe.anfaengerBeendet !== true,
    alternativen,
  };
}

/**
 * Die aktiven Plaene (aus aktivePlaeneDerMitgliedschaften) fuer die App: Zaehler und
 * Kandidaten je Studio. Die Beschwerden wirken nur auf die Kandidaten und verlassen
 * diese Funktion nicht.
 */
export async function ladePlaeneFuerApp(
  client: SupabaseClient,
  userId: string,
  plaene: TrainingPlan[],
  profil: TrainingProfile | null,
  limits: TrainingLimits | null,
  jetzt: Date,
): Promise<PlanFuerApp[]> {
  // Ohne Einwilligung (keine Zeile) gibt es keine Beschwerden -- nie raten.
  const beschwerden = limits?.areas ?? {};
  return Promise.all(
    plaene.map(async (plan) => {
      const [gezaehlt, kandidaten] = await Promise.all([
        ladeGezaehlteEinheiten(client, userId, plan.studioId, jetzt),
        ladeKandidaten(client, plan.studioId),
      ]);
      return planFuerApp(plan, gezaehlt, profil, alternativenJeBaustein(kandidaten, beschwerden));
    }),
  );
}
