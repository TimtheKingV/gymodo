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
import {
  aktualisierePlanGewichte,
  initialisierePlanGewichte,
  ladeZielgewichte,
  ohneAbbruch,
  type Melde,
  type PositionsZiel,
} from "./plangewichte.js";
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
/** max_rows aus supabase/config.toml; eine so volle Antwort kann abgeschnitten sein. */
const POSTGREST_MAX_ROWS = 1000;
/** Saetze je Abfrage fuer die letzte Satzzeit offener Sessions, siehe ladeLetzteSaetze. */
const SATZ_LIMIT = POSTGREST_MAX_ROWS;

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
 * Gezaehlte Einheiten des Nutzers (alle Studios, der Plan gehoert dem Katalog) ueber ALLE Planversionen: der Zaehler
 * soll bei einem Tausch oder neuen Plan nicht von vorn beginnen. Gelesen werden die
 * neuesten SESSION_LIMIT Sessions mit Plan; Saetze nur fuer nie beendete, denn nur dort
 * entscheidet der letzte Satz.
 */
export async function ladeGezaehlteEinheiten(
  client: SupabaseClient,
  userId: string,
  jetzt: Date,
): Promise<GezaehlteEinheit[]> {
  const { data, error } = await client
    .from("workout_sessions")
    .select("id, plan_einheit_key, started_at, completed_at")
    .eq("user_id", userId)
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
  // Parallel: jede Abfrage ist ein Rundweg beim App-Start.
  const teile = await Promise.all(
    stuecke(sessions.map((s) => s.id), STATUS_CHUNK).map(async (teil) => {
      // Nur die Stati, die zaehlen koennen: haelt die Zeilenzahl klein.
      const { data: zeilen, error: e } = await client
        .from("session_plan_status")
        .select("session_id, status")
        .in("session_id", teil)
        .in("status", ["erledigt", "optional"]);
      if (e) throw new DomainError("internal", "Der Planstatus konnte nicht gelesen werden.");
      const liste = (zeilen ?? []) as Array<{ session_id: string; status: PositionStatus }>;
      // Volle Seite heisst: PostgREST hat womoeglich abgeschnitten. Lieber scheitern (der
      // Bootstrap liefert dann plans: []) als still Einheiten zu verlieren.
      if (liste.length >= POSTGREST_MAX_ROWS) {
        throw new DomainError("internal", "Zu viele Statuszeilen fuer eine Abfrage.");
      }
      return liste;
    }),
  );
  for (const z of teile.flat()) stati.set(z.session_id, [...(stati.get(z.session_id) ?? []), z.status]);

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

export type PlanAlternative = { exerciseId: string; modelId: string };

/**
 * Merkliste des Mitglieds fuer die App: je Ort die gesperrten Uebungs-IDs, "gefaellt nicht"
 * ueberall. Eine Angabe zur Person: nur an den Eigentuemer, nie geloggt.
 */
export type PlanMerkliste = { nichtVorhanden: Record<string, string[]>; gefaelltNicht: string[] };

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
  /** Zielgewicht je Positionsschluessel (G8, G17); Positionen ohne Ziel fehlen. */
  zielgewichte: Record<string, PositionsZiel>;
  merkliste: PlanMerkliste;
};

type MerklisteZeile = { exercise_id: string; art: string; studio_id: string | null };

/** Faltet die Zeilen von plan_merkliste; rein. */
export function merklisteFuerApp(zeilen: MerklisteZeile[]): PlanMerkliste {
  const ergebnis: PlanMerkliste = { nichtVorhanden: {}, gefaelltNicht: [] };
  for (const z of zeilen) {
    if (z.art === "nicht_vorhanden" && z.studio_id) (ergebnis.nichtVorhanden[z.studio_id] ??= []).push(z.exercise_id);
    else if (z.art === "gefaellt_nicht") ergebnis.gefaelltNicht.push(z.exercise_id);
  }
  return ergebnis;
}

async function ladeMerklisteFuerApp(client: SupabaseClient, userId: string): Promise<PlanMerkliste> {
  const { data, error } = await client
    .from("plan_merkliste")
    .select("exercise_id, art, studio_id")
    .eq("user_id", userId);
  // Feste Meldung: der Inhalt der Merkliste steht nie in einem Fehler oder Log.
  if (error) throw new DomainError("internal", "Die Merkliste konnte nicht gelesen werden.");
  return merklisteFuerApp((data ?? []) as MerklisteZeile[]);
}

/** Ein Plan im alten Format (Positionen mit machineId statt modelId) taugt nicht fuer die App. */
export function istKatalogPlan(plan: TrainingPlan): boolean {
  return plan.einheiten.every((e) => e.positionen.every((p) => typeof (p as { modelId?: unknown }).modelId === "string"));
}

/**
 * Tauschkandidaten je Baustein: "meiden" faellt heraus, "vorsichtig" steht hinten, sonst
 * die Reihenfolge von ladeKandidaten; Uebungen, die dem Mitglied nicht gefallen, ganz am Ende. Ausgegeben werden nur exerciseId und modelId --
 * kein Bereich und kein Vorsichtig-Kennzeichen, denn daraus liessen sich die Beschwerden
 * (Gesundheitsdaten) ablesen.
 */
export function alternativenJeBaustein(
  kandidaten: Kandidat[],
  beschwerden: TrainingLimits["areas"],
): PlanFuerApp["alternativen"] {
  const ergebnis: PlanFuerApp["alternativen"] = {};
  const erlaubt = filtereKandidaten(kandidaten, beschwerden);
  for (const k of [...erlaubt.filter((x) => !x.gefaelltNicht), ...erlaubt.filter((x) => x.gefaelltNicht)]) {
    (ergebnis[k.baustein] ??= []).push({ exerciseId: k.exerciseId, modelId: k.modelId });
  }
  return ergebnis;
}

/** Setzt den Plan fuer die App zusammen; rein, damit die Regeln ohne Datenbank pruefbar sind. */
export function planFuerApp(
  plan: TrainingPlan,
  gezaehlt: GezaehlteEinheit[],
  profil: TrainingProfile | null,
  alternativen: PlanFuerApp["alternativen"],
  zielgewichte: PlanFuerApp["zielgewichte"],
  merkliste: PlanMerkliste,
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
    zielgewichte,
    merkliste,
  };
}

/** Hoechstens so viele Einheiten rechnet ein Bootstrap nach (die juengsten). */
export const NACHHOLEN_HOECHSTENS = 5;
/** So viele juengste Einheiten werden auf Nachholbedarf geprueft. */
const NACHHOLEN_KANDIDATEN = 20;

export type SessionFuerNachholen = {
  id: string;
  startedAt: string;
  completedAt: string | null;
  letzterSatzAm: string | null;
  gewichteBerechnetAm: string | null;
};

/**
 * Einheiten, deren Zielgewichte nachzurechnen sind (G2, G13): abgeschlossen -- beendet oder
 * nach 4 h Stillstand, der Autoabschluss ist eine Leseregel und loest nichts aus -- und noch
 * nicht oder vor ihrem Abschluss berechnet. Das Zweite faengt eine wieder geoeffnete und
 * erneut beendete Einheit: die Marke bleibt beim Wiederoeffnen stehen. Der Stand ist der aus
 * set_plan_gewichte (completed_at, sonst letzte Aktivitaet). Aufsteigend nach Stand,
 * hoechstens die juengsten `hoechstens`.
 */
export function nachzuholendeSessions(
  sessions: SessionFuerNachholen[],
  jetzt: Date,
  hoechstens = NACHHOLEN_HOECHSTENS,
): string[] {
  const offen: Array<{ id: string; stand: number }> = [];
  for (const s of sessions) {
    let stand: number;
    if (s.completedAt !== null) {
      stand = Date.parse(s.completedAt);
    } else {
      stand = Date.parse(s.letzterSatzAm ?? s.startedAt);
      if (jetzt.getTime() - stand <= STILLSTAND_MS) continue;
    }
    if (s.gewichteBerechnetAm !== null && Date.parse(s.gewichteBerechnetAm) >= stand) continue;
    offen.push({ id: s.id, stand });
  }
  return offen
    .sort((a, b) => a.stand - b.stand)
    .slice(-hoechstens)
    .map((s) => s.id);
}

/** Die juengsten Planeinheiten des Mitglieds mit Nachholbedarf, siehe oben. */
async function ladeNachzuholende(
  client: SupabaseClient,
  userId: string,
  jetzt: Date,
): Promise<string[]> {
  const { data, error } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, gewichte_berechnet_at")
    .eq("user_id", userId)
    .not("plan_id", "is", null)
    .not("plan_einheit_key", "is", null)
    .order("started_at", { ascending: false })
    .limit(NACHHOLEN_KANDIDATEN);
  if (error) throw new DomainError("internal", "Die Einheiten konnten nicht gelesen werden.");
  const sessions = (data ?? []) as Array<{
    id: string;
    started_at: string;
    completed_at: string | null;
    gewichte_berechnet_at: string | null;
  }>;
  const letzte = await ladeLetzteSaetze(
    client,
    sessions.filter((s) => s.completed_at === null).map((s) => s.id),
  );
  return nachzuholendeSessions(
    sessions.map((s) => ({
      id: s.id,
      startedAt: s.started_at,
      completedAt: s.completed_at,
      letzterSatzAm: letzte.get(s.id) ?? null,
      gewichteBerechnetAm: s.gewichte_berechnet_at,
    })),
    jetzt,
  );
}

/**
 * Zielgewichte des Plans fuer die App. Vorher, ohne den Bootstrap je scheitern zu lassen:
 * liegengebliebene Abschluesse nachrechnen (nacheinander, aelteste zuerst) und fehlende
 * Ziele setzen -- so bekommt ein Bestandsplan aus Etappe 1-3 seine Ziele beim ersten
 * Bootstrap (G13). Nur das Lesen selbst wirft; dann gibt es plans: [] wie bei jedem
 * anderen Fehler im Planteil.
 */
async function ladeZielgewichteFuerApp(
  client: SupabaseClient,
  userId: string,
  plan: TrainingPlan,
  jetzt: Date,
  melde: Melde,
): Promise<PlanFuerApp["zielgewichte"]> {
  await ohneAbbruch(
    "Nachholen im Bootstrap",
    async () => {
      for (const sessionId of await ladeNachzuholende(client, userId, jetzt)) {
        await ohneAbbruch(
          "Nachholen einer Einheit",
          () => aktualisierePlanGewichte(client, userId, sessionId),
          melde,
        );
      }
    },
    melde,
  );
  await ohneAbbruch("Startwerte im Bootstrap", () => initialisierePlanGewichte(client, userId, plan), melde);
  return ladeZielgewichte(client, userId, plan);
}

/**
 * Der aktive Katalogplan (hoechstens einer) fuer die App: Zaehler, Kandidaten, Zielgewichte
 * und die Merkliste des Mitglieds. Die Beschwerden wirken nur auf die Kandidaten und
 * verlassen diese Funktion nicht. Ein Plan im alten Format (machineId) wird ausgelassen
 * und ohne Inhalt protokolliert.
 */
export async function ladePlaeneFuerApp(
  client: SupabaseClient,
  userId: string,
  plan: TrainingPlan | null,
  profil: TrainingProfile | null,
  limits: TrainingLimits | null,
  jetzt: Date,
  melde: Melde = (n) => console.error(n),
): Promise<PlanFuerApp[]> {
  if (!plan) return [];
  if (!istKatalogPlan(plan)) {
    melde("bootstrap: Plan im alten Format ausgelassen");
    return [];
  }
  // Ohne Einwilligung (keine Zeile) gibt es keine Beschwerden -- nie raten.
  const beschwerden = limits?.areas ?? {};
  const merkliste = await ladeMerklisteFuerApp(client, userId);
  const [gezaehlt, kandidaten, zielgewichte] = await Promise.all([
    ladeGezaehlteEinheiten(client, userId, jetzt),
    // Ohne Filter der Merkliste: die App entfernt "nicht vorhanden" je Ort selbst;
    // "gefaellt nicht" sortiert ans Ende.
    ladeKandidaten(client, { nichtVorhanden: [], gefaelltNicht: merkliste.gefaelltNicht }),
    ladeZielgewichteFuerApp(client, userId, plan, jetzt, melde),
  ]);
  return [planFuerApp(plan, gezaehlt, profil, alternativenJeBaustein(kandidaten, beschwerden), zielgewichte, merkliste)];
}
