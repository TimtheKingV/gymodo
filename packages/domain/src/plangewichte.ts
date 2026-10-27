// Zielgewichte je Planposition laden, rechnen und schreiben (Trainingsplan
// Etappe 4, Task 4; Spec 2026-10-25 G2-G5, G9, G12-G16, G21).
//
// Die Regeln selbst sind rein (plangewicht.ts, plangewicht-start.ts); hier
// wird nur gelesen, zugeordnet und ueber die SECURITY-DEFINER-Funktionen aus
// 0064 geschrieben (set_plan_gewichte, init_plan_gewichte). Alles laeuft mit
// dem Client des Mitglieds: die Funktionen nehmen den Nutzer aus auth.uid().
//
// Zuordnung immer ueber Uebung + Geraet, nie ueber Versions- oder
// Positionskennungen der Session: die Session kann an Planversion N haengen,
// waehrend nach einem dauerhaften Tausch N+1 aktiv ist (Uebergabe Punkt 5).
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { berechnePlanGewicht, PLANGEWICHT_ALGO_VERSION, type PlanGewichtGrund } from "./plangewicht.js";
import {
  abgerundet,
  schaetzeStartgewicht,
  startgewichtAusHistorie,
  uebertragungsFaktor,
  wiedereinstieg,
  type Geraetegrenzen,
} from "./plangewicht-start.js";
import { AGE_BANDS, SEX } from "./profil.js";
import { toBlocks, type BlockInput, type SatzZeile } from "./progression.js";
import type { PlanEinheit, PlanPosition } from "./trainingsplan-generator.js";
import type { Erfahrung } from "./trainingsplan-typen.js";
import type { TrainingPlan } from "./trainingsplan.js";

export type PositionsZiel = {
  load: number;
  secondaryLoad: number | null;
  /** Ziel minus letztes tatsaechlich benutztes Gewicht; null ohne Vorgaenger oder bei Gleichheit. */
  aenderung: number | null;
  /** null nur bei einer Zeile ohne Grund; erfunden wird keiner. */
  grund: PlanGewichtGrund | null;
};

/** Vorausschau nach einer Einheit (G3, G21). */
export const VORAUSSCHAU_EINHEITEN = 3;
/** Wie IDLE_HOURS_UNTIL_AUTO_COMPLETE in sessions.ts und 0064. */
const STILLSTAND_MS = 4 * 60 * 60 * 1000;
/** max_rows aus supabase/config.toml; eine so volle Antwort kann abgeschnitten sein. */
const POSTGREST_MAX_ROWS = 1000;
/**
 * Wie weit Historie zaehlt: ueber 42 Tage gilt eine Uebung wie ohne Historie (F18,
 * WIEDEREINSTIEG_STUFEN). Ein Tag Puffer, weil der Abstand abgerundet wird.
 */
export const HISTORIE_FENSTER_TAGE = 43;
const TAG_MS = 24 * 60 * 60 * 1000;

type Zeile = {
  positionKey: string;
  load: number;
  secondaryLoad: number | null;
  grund: PlanGewichtGrund | null;
  algoVersion: string;
};

type Grenzen = Geraetegrenzen & { loadStart: number | null };

type HistorieZeile = SatzZeile & { machine_id: string; exercise_id: string };

// ---------------------------------------------------------------------------
// Reine Helfer
// ---------------------------------------------------------------------------

export function paarSchluessel(machineId: string, exerciseId: string): string {
  return `${machineId}:${exerciseId}`;
}

/**
 * Die bis zu `anzahl` Einheiten nach `zuletzt` in Planreihenfolge, zyklisch und ohne
 * Doppelte. Bei hoechstens `anzahl` Einheiten sind das alle, auch die gerade
 * abgeschlossene selbst (ihr naechstes Vorkommen ist noch nicht begonnen; sonst
 * stuende ein Plan mit einer Einheit still). Unbekanntes `zuletzt` beginnt vorn
 * (wie naechsteEinheitKey).
 */
export function folgeEinheiten(keys: string[], zuletzt: string | null, anzahl = VORAUSSCHAU_EINHEITEN): string[] {
  const n = keys.length;
  const idx = zuletzt === null ? -1 : keys.indexOf(zuletzt);
  const ergebnis: string[] = [];
  for (let i = 1; i <= Math.min(anzahl, n); i++) {
    const key = keys[(((idx + i) % n) + n) % n]!;
    if (!ergebnis.includes(key)) ergebnis.push(key);
  }
  return ergebnis;
}

/** Kraftpositionen tragen ein Zielgewicht; Cardio hat keine Progression. */
export function hatZielgewicht(p: PlanPosition): boolean {
  return p.rolle !== "cardio" && p.baustein !== "cardio" && p.wdhVon !== null && p.wdhBis !== null;
}

/** G17: Ziel minus letztes tatsaechlich benutztes Gewicht; null ohne Vorgaenger oder bei Gleichheit. */
export function aenderungZumLetzten(ziel: number, letzte: number | null): number | null {
  if (letzte === null) return null;
  const d = Number((ziel - letzte).toFixed(2));
  return d === 0 ? null : d;
}

/**
 * Block der Session und der Block davor aus der Historie eines Paars (absteigend
 * gelesen). `neuerVorhanden`: es gibt einen spaeteren Block einer anderen Session --
 * dann entscheidet der (G6, G14), und diese Session rechnet das Paar nicht.
 */
export function bloeckeUm(
  zeilen: SatzZeile[],
  sessionId: string,
): { block: BlockInput; vorher: BlockInput | null; neuerVorhanden: boolean } | null {
  const bloecke = toBlocks(zeilen);
  const idx = bloecke.findIndex((b) => b.sessionId === sessionId);
  if (idx < 0) return null;
  return { block: bloecke[idx]!, vorher: bloecke[idx + 1] ?? null, neuerVorhanden: idx > 0 };
}

// ---------------------------------------------------------------------------
// Laden
// ---------------------------------------------------------------------------

function positionenVon(einheiten: PlanEinheit[]): Map<string, PlanPosition> {
  return new Map(einheiten.flatMap((e) => e.positionen.map((p) => [p.key, p] as const)));
}

/** Geraetegrenzen und Startwert je Geraet, ueber sein Modell. */
async function ladeGrenzen(client: SupabaseClient, machineIds: string[]): Promise<Map<string, Grenzen>> {
  const ergebnis = new Map<string, Grenzen>();
  if (machineIds.length === 0) return ergebnis;
  const { data, error } = await client
    .from("machines")
    .select("id, equipment_models (load_step, load_min, load_max, load_start)")
    .in("id", [...new Set(machineIds)]);
  if (error) throw new DomainError("internal", error.message);
  for (const m of (data ?? []) as unknown as Array<{
    id: string;
    equipment_models: {
      load_step: number | string | null;
      load_min: number | string | null;
      load_max: number | string | null;
      load_start: number | string | null;
    } | null;
  }>) {
    const mod = m.equipment_models;
    const loadStep = Number(mod?.load_step);
    // Ohne einstellbare Stufe (Cardiomodell) gibt es kein Zielgewicht.
    if (!mod || !(loadStep > 0)) continue;
    ergebnis.set(m.id, {
      loadStep,
      loadMin: Number(mod.load_min ?? 0),
      // Wie vorschlaegeFuerAbschluss: ohne Obergrenze praktisch unbegrenzt.
      loadMax: Number(mod.load_max ?? 9999),
      loadStart: mod.load_start === null ? null : Number(mod.load_start),
    });
  }
  return ergebnis;
}

/** Hoechstens so viele Seiten je Satzabfrage; mehr waere kein Training mehr, sondern ein Fehler. */
export const MAX_SATZSEITEN = 10;

/**
 * Arbeitssaetze (bestaetigt, set_role = 'arbeit', mit Last) je Paar (Geraet,
 * Uebung) ab `ab`, absteigend -- EINE logische Abfrage ueber alle Paare, egal wie
 * viele. Das Zeitfenster begrenzt die Menge nach Trainingshaeufigkeit statt nach
 * Alter des Kontos; innerhalb des Fensters wird in Seiten der PostgREST-Grenze
 * geblaettert (stabil nach performed_at, dann id), bis eine Seite kurz ist. Erst
 * nach MAX_SATZSEITEN vollen Seiten wird geworfen.
 */
async function ladeArbeitssaetze(
  client: SupabaseClient,
  userId: string,
  paare: Array<{ machineId: string; exerciseId: string }>,
  ab: Date,
): Promise<Map<string, HistorieZeile[]>> {
  const jePaar = new Map<string, HistorieZeile[]>();
  if (paare.length === 0) return jePaar;
  const maschinen = [...new Set(paare.map((p) => p.machineId))];
  const uebungen = [...new Set(paare.map((p) => p.exerciseId))];
  for (let seite = 0; ; seite++) {
    if (seite >= MAX_SATZSEITEN) {
      throw new DomainError("internal", "Zu viele Saetze fuer die Zielgewichte.");
    }
    const { data, error } = await client
      .from("workout_sets")
      .select("id, session_id, machine_id, exercise_id, performed_at, load, secondary_load, volume, rir, problem_flag")
      .eq("user_id", userId)
      .eq("set_role", "arbeit")
      .not("load", "is", null)
      .in("machine_id", maschinen)
      .in("exercise_id", uebungen)
      .gte("performed_at", ab.toISOString())
      .order("performed_at", { ascending: false })
      .order("id", { ascending: false })
      .range(seite * POSTGREST_MAX_ROWS, (seite + 1) * POSTGREST_MAX_ROWS - 1);
    if (error) throw new DomainError("internal", error.message);
    const zeilen = (data ?? []) as HistorieZeile[];
    for (const z of zeilen) {
      const k = paarSchluessel(z.machine_id, z.exercise_id);
      const liste = jePaar.get(k);
      if (liste) liste.push(z);
      else jePaar.set(k, [z]);
    }
    if (zeilen.length < POSTGREST_MAX_ROWS) return jePaar;
  }
}

/**
 * Sessions des Mitglieds, die gerade laufen: nicht beendet und letzte Aktivitaet
 * (letzter Satz, sonst Start) hoechstens 4 h her. Zwei begrenzte Abfragen: Saetze
 * der letzten 4 h, dann die offenen Sessions darunter oder mit Start in dem Fenster.
 */
async function laufendeSessions(client: SupabaseClient, userId: string, jetzt: number): Promise<Set<string>> {
  const seit = new Date(jetzt - STILLSTAND_MS).toISOString();
  const { data: saetze, error } = await client
    .from("workout_sets")
    .select("session_id")
    .eq("user_id", userId)
    .gte("performed_at", seit)
    .limit(POSTGREST_MAX_ROWS);
  if (error) throw new DomainError("internal", error.message);
  const ids = [...new Set(((saetze ?? []) as Array<{ session_id: string }>).map((s) => s.session_id))];
  const filter = [`started_at.gte."${seit}"`, ...(ids.length > 0 ? [`id.in.(${ids.join(",")})`] : [])].join(",");
  const { data, error: e } = await client
    .from("workout_sessions")
    .select("id")
    .eq("user_id", userId)
    .is("completed_at", null)
    .or(filter);
  if (e) throw new DomainError("internal", e.message);
  return new Set(((data ?? []) as Array<{ id: string }>).map((s) => s.id));
}

type ZielZeile = {
  position_key: string;
  load: number | string;
  secondary_load: number | string | null;
  grund: string | null;
};

async function ladeZielZeilen(client: SupabaseClient, userId: string, planId: string): Promise<Map<string, ZielZeile>> {
  const { data, error } = await client
    .from("plan_gewichte")
    .select("position_key, load, secondary_load, grund")
    .eq("plan_id", planId)
    .eq("user_id", userId);
  if (error) throw new DomainError("internal", error.message);
  return new Map(((data ?? []) as ZielZeile[]).map((z) => [z.position_key, z]));
}

type Person = {
  geschlecht: (typeof SEX)[number] | null;
  altersgruppe: (typeof AGE_BANDS)[number] | null;
  koerpergewichtKg: number | null;
};

/** Angaben fuer die Startschaetzung; Unbekanntes zaehlt als null (Faktor 1). */
async function ladePerson(client: SupabaseClient, userId: string): Promise<Person> {
  const [profil, messung] = await Promise.all([
    client.from("profiles").select("sex, age_band").eq("id", userId).maybeSingle(),
    client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", userId)
      .order("measured_on", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  if (profil.error) throw new DomainError("internal", profil.error.message);
  if (messung.error) throw new DomainError("internal", messung.error.message);
  const sex = (profil.data as { sex: string | null } | null)?.sex ?? null;
  const band = (profil.data as { age_band: string | null } | null)?.age_band ?? null;
  const kg = (messung.data as { weight_kg: number | string } | null)?.weight_kg;
  return {
    geschlecht: (SEX as readonly string[]).includes(sex ?? "") ? (sex as Person["geschlecht"]) : null,
    altersgruppe: (AGE_BANDS as readonly string[]).includes(band ?? "") ? (band as Person["altersgruppe"]) : null,
    koerpergewichtKg: kg === undefined || kg === null ? null : Number(kg),
  };
}

function schaetzung(g: Grenzen, erfahrung: Erfahrung, person: Person): number {
  return schaetzeStartgewicht({ loadStart: g.loadStart, erfahrung, geraet: g, ...person });
}

// ---------------------------------------------------------------------------
// Neu rechnen nach einer Einheit
// ---------------------------------------------------------------------------

type SessionZeile = {
  id: string;
  studio_id: string;
  plan_id: string | null;
  plan_einheit_key: string | null;
  started_at: string;
};

type AktiverPlan = { id: string; einheiten: PlanEinheit[]; eingabe: { erfahrung: Erfahrung } };

/**
 * Einheiten aus `keys`, die gerade laufen (G15: eine Session existiert und ist weder
 * beendet noch nach 4 h Stillstand automatisch abgeschlossen). Deren Ziele bleiben
 * eingefroren, damit sich die Zahl nicht unter dem Mitglied aendert.
 */
async function laufendeEinheiten(
  client: SupabaseClient,
  userId: string,
  studioId: string,
  keys: string[],
  ausser: string,
  jetzt: number,
): Promise<Set<string>> {
  if (keys.length === 0) return new Set();
  const { data, error } = await client
    .from("workout_sessions")
    .select("id, plan_einheit_key, started_at")
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .in("plan_einheit_key", keys)
    .is("completed_at", null)
    .neq("id", ausser);
  if (error) throw new DomainError("internal", error.message);
  const offen = (data ?? []) as Array<{ id: string; plan_einheit_key: string; started_at: string }>;
  if (offen.length === 0) return new Set();

  const { data: saetze, error: e } = await client
    .from("workout_sets")
    .select("session_id, performed_at")
    .in("session_id", offen.map((s) => s.id))
    .order("performed_at", { ascending: false })
    .limit(POSTGREST_MAX_ROWS);
  if (e) throw new DomainError("internal", e.message);
  const letzter = new Map<string, string>();
  for (const s of (saetze ?? []) as Array<{ session_id: string; performed_at: string }>) {
    if (!letzter.has(s.session_id)) letzter.set(s.session_id, s.performed_at);
  }
  const laufend = new Set<string>();
  for (const s of offen) {
    // Fehlt der letzte Satz (Antwort abgeschnitten), zaehlt die Session als laufend:
    // lieber eine Einheit einmal nicht anpassen als unter dem Mitglied aendern.
    const aktivitaet = Math.max(Date.parse(s.started_at), Date.parse(letzter.get(s.id) ?? s.started_at));
    if (jetzt - aktivitaet <= STILLSTAND_MS || (saetze ?? []).length >= POSTGREST_MAX_ROWS) {
      laufend.add(s.plan_einheit_key);
    }
  }
  return laufend;
}

/**
 * Nach einer abgeschlossenen Einheit (G2): rechnet die Zielgewichte der naechsten
 * drei noch nicht begonnenen Einheiten der AKTIVEN Planversion neu und schreibt sie
 * ueber set_plan_gewichte. Positionen mit derselben Uebung am selben Geraet wie ein
 * Block der Session rechnen mit berechnePlanGewicht gegen ihren eigenen Bereich
 * (G4); Positionen ohne eigene Historie mit gemeinsamem Hauptmuskel bekommen die
 * Uebertragung (G5, G16). Wiederholbar: gleiche Session, gleiches Ergebnis; ob eine
 * Zeile sich aendert, entscheidet der Stand in der Datenbank (G10, G14).
 *
 * Wirft bei jedem Lese- oder Schreibfehler (auch plan_ungueltig, etwa wenn die
 * Session noch laeuft); der Aufrufer entscheidet, ob er nur protokolliert.
 */
export async function aktualisierePlanGewichte(
  client: SupabaseClient,
  userId: string,
  sessionId: string,
): Promise<void> {
  const jetzt = Date.now();
  const { data: sessionDaten, error: sessionFehler } = await client
    .from("workout_sessions")
    .select("id, studio_id, plan_id, plan_einheit_key, started_at")
    .eq("id", sessionId)
    .eq("user_id", userId)
    .maybeSingle();
  if (sessionFehler) throw new DomainError("internal", sessionFehler.message);
  if (!sessionDaten) throw new DomainError("not_found", "Einheit nicht gefunden.");
  const session = sessionDaten as SessionZeile;
  // Freies Training gehoert zu keiner Planeinheit; es gibt keine Reihenfolge, nach der
  // sich "die naechsten Einheiten" bestimmen liessen.
  if (session.plan_id === null || session.plan_einheit_key === null) return;

  const { data: planDaten, error: planFehler } = await client
    .from("training_plans")
    .select("id, einheiten, eingabe")
    .eq("user_id", userId)
    .eq("studio_id", session.studio_id)
    .eq("status", "aktiv")
    .maybeSingle();
  if (planFehler) throw new DomainError("internal", planFehler.message);
  if (!planDaten) return;
  const plan = planDaten as AktiverPlan;

  // Nur Arbeitssaetze an einem Geraet zaehlen (Aufwaermsaetze nie, Spec Anti-Ziele).
  const { data: satzDaten, error: satzFehler } = await client
    .from("workout_sets")
    .select("machine_id, exercise_id")
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .eq("set_role", "arbeit")
    .not("load", "is", null)
    .not("machine_id", "is", null);
  if (satzFehler) throw new DomainError("internal", satzFehler.message);
  const sessionPaare = new Map(
    ((satzDaten ?? []) as Array<{ machine_id: string; exercise_id: string }>).map((s) => [
      paarSchluessel(s.machine_id, s.exercise_id),
      { machineId: s.machine_id, exerciseId: s.exercise_id },
    ]),
  );

  const zeilen: Zeile[] = [];
  if (sessionPaare.size > 0) {
    const folge = folgeEinheiten(
      plan.einheiten.map((e) => e.key),
      session.plan_einheit_key,
    );
    const [laufend, ziele, uebungen] = await Promise.all([
      laufendeEinheiten(client, userId, session.studio_id, folge, sessionId, jetzt),
      ladeZielZeilen(client, userId, plan.id),
      ladeHauptmuskeln(client, [...new Set([...sessionPaare.values()].map((p) => p.exerciseId))]),
    ]);
    const ziel = plan.einheiten
      .filter((e) => folge.includes(e.key) && !laufend.has(e.key))
      .flatMap((e) => e.positionen)
      .filter(hatZielgewicht);

    // Fenster ab Sessionstart: Block, Vorgaenger (aelter als 42 Tage zaehlt nicht,
    // F18), spaetere Bloecke und "eigene Historie" fuer die Uebertragung (ebenfalls
    // F18: ueber 42 Tage wie ohne Historie).
    const ab = new Date(Date.parse(session.started_at) - HISTORIE_FENSTER_TAGE * TAG_MS);
    const [grenzen, historie] = await Promise.all([
      ladeGrenzen(client, ziel.map((p) => p.machineId)),
      ladeArbeitssaetze(client, userId, [...sessionPaare.values(), ...ziel], ab),
    ]);

    // Messungen fuer die Uebertragung: Bloecke dieser Session mit Reserve am letzten
    // Satz und einer Planposition (Bereich, Zielreserve). Die juengste zuerst.
    const alle = positionenVon(plan.einheiten);
    const eigeneEinheit = plan.einheiten.find((e) => e.key === session.plan_einheit_key)?.positionen ?? [];
    const messungen = [...sessionPaare.entries()]
      .flatMap(([k, paar]) => {
        const um = bloeckeUm(historie.get(k) ?? [], sessionId);
        const letzter = um?.block.sets.at(-1);
        const position =
          eigeneEinheit.find((p) => p.machineId === paar.machineId && p.exerciseId === paar.exerciseId) ??
          [...alle.values()].find((p) => p.machineId === paar.machineId && p.exerciseId === paar.exerciseId);
        if (!um || !letzter || letzter.rir === null || !position || !hatZielgewicht(position)) return [];
        const zuletzt = (historie.get(k) ?? []).find((z) => z.session_id === sessionId)!.performed_at;
        return [
          {
            zuletzt,
            muskeln: uebungen.get(paar.exerciseId) ?? [],
            faktor: uebertragungsFaktor({
              gemacht: letzter.volume,
              reserve: letzter.rir,
              wdhMitte: (position.wdhVon! + position.wdhBis!) / 2,
              zielreserve: position.reserveVon,
            }),
          },
        ];
      })
      .sort((a, b) => Date.parse(b.zuletzt) - Date.parse(a.zuletzt));

    let person: Person | null = null;
    for (const p of ziel) {
      const g = grenzen.get(p.machineId);
      if (!g) continue;
      const k = paarSchluessel(p.machineId, p.exerciseId);
      const vorhanden = ziele.get(p.key);

      if (sessionPaare.has(k)) {
        const um = bloeckeUm(historie.get(k) ?? [], sessionId);
        if (!um || um.neuerVorhanden) continue;
        const r = berechnePlanGewicht({
          position: { wdhVon: p.wdhVon!, wdhBis: p.wdhBis!, reserveVon: p.reserveVon },
          geraet: g,
          block: um.block.sets,
          vorher: um.vorher?.sets ?? null,
          aktuellesZiel: vorhanden
            ? {
                load: Number(vorhanden.load),
                secondaryLoad: vorhanden.secondary_load === null ? null : Number(vorhanden.secondary_load),
              }
            : null,
        });
        if (r.load === null) continue;
        zeilen.push({
          positionKey: p.key,
          load: r.load,
          secondaryLoad: r.secondaryLoad,
          grund: r.grund,
          algoVersion: PLANGEWICHT_ALGO_VERSION,
        });
        continue;
      }

      // Uebertragung nur ohne eigene Historie (Haupt-Spec Abschnitt 6).
      if ((historie.get(k) ?? []).length > 0) continue;
      const messung = messungen.find((m) => m.muskeln.some((x) => p.hauptmuskeln.includes(x)));
      if (!messung) continue;
      person ??= await ladePerson(client, userId);
      zeilen.push({
        positionKey: p.key,
        load: abgerundet(schaetzung(g, plan.eingabe.erfahrung, person) * messung.faktor, g),
        secondaryLoad: null,
        grund: "uebertragung",
        algoVersion: PLANGEWICHT_ALGO_VERSION,
      });
    }
  }

  // Auch ohne Zeilen: setzt gewichte_berechnet_at (Marke fuer das Nachholen, Task 5).
  const { error } = await client.rpc("set_plan_gewichte", {
    p_session_id: sessionId,
    p_plan_id: plan.id,
    p_zeilen: zeilen,
  });
  if (error?.code === "P0001" && error.message === "plan_ungueltig") {
    throw new DomainError("conflict", "Die Zielgewichte passen nicht zu dieser Einheit (plan_ungueltig).");
  }
  if (error) throw new DomainError("internal", error.message);
}

/** Hauptmuskeln (role primary) je Uebung, wie ladeKandidaten. */
async function ladeHauptmuskeln(client: SupabaseClient, exerciseIds: string[]): Promise<Map<string, string[]>> {
  if (exerciseIds.length === 0) return new Map();
  const { data, error } = await client.from("exercises").select("id, muscles").in("id", exerciseIds);
  if (error) throw new DomainError("internal", error.message);
  return new Map(
    ((data ?? []) as Array<{ id: string; muscles: Array<{ key: string; role: string }> | null }>).map((u) => [
      u.id,
      (u.muscles ?? []).filter((m) => m.role === "primary").map((m) => m.key),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Startwerte (G12, G13)
// ---------------------------------------------------------------------------

/**
 * Startwerte fuer alle Kraftpositionen des Plans ohne Zeile: mit Historie die Last des
 * letzten Blocks (G12), nach dem Abstand zu ihm gemildert (F18: bis 14 Tage halten,
 * nie steigern; 15-42 Tage abschlagen; darueber wie ohne Historie), sonst die
 * Startschaetzung. Bestehende Zeilen bleiben (init_plan_gewichte schreibt nur fehlende).
 */
export async function initialisierePlanGewichte(
  client: SupabaseClient,
  userId: string,
  plan: TrainingPlan,
): Promise<void> {
  const jetzt = Date.now();
  const vorhanden = await ladeZielZeilen(client, userId, plan.id);
  const fehlend = plan.einheiten.flatMap((e) => e.positionen).filter((p) => hatZielgewicht(p) && !vorhanden.has(p.key));
  if (fehlend.length === 0) return;

  const [grenzen, historie] = await Promise.all([
    ladeGrenzen(client, fehlend.map((p) => p.machineId)),
    ladeArbeitssaetze(client, userId, fehlend, new Date(jetzt - HISTORIE_FENSTER_TAGE * TAG_MS)),
  ]);

  let person: Person | null = null;
  const zeilen: Zeile[] = [];
  for (const p of fehlend) {
    const g = grenzen.get(p.machineId);
    if (!g) continue;
    const saetze = historie.get(paarSchluessel(p.machineId, p.exerciseId)) ?? [];
    const letzterBlock = toBlocks(saetze)[0];
    let load: number | null = null;
    let grund: PlanGewichtGrund = "startschaetzung";
    if (letzterBlock) {
      const start = startgewichtAusHistorie(letzterBlock.sets, g)!;
      const tage = Math.floor((jetzt - Date.parse(saetze[0]!.performed_at)) / TAG_MS);
      const w = wiedereinstieg(tage, start, g);
      // grund null: bis 14 Tage -- die Last des letzten Blocks gilt, eine Steigerung gibt
      // es beim Start ohnehin nie (G12), auch nicht nach 8-14 Tagen (F18).
      if (w.load !== null) {
        load = w.load;
        grund = w.grund ?? "letztes_gewicht";
      }
    }
    if (load === null) {
      person ??= await ladePerson(client, userId);
      load = schaetzung(g, plan.eingabe.erfahrung, person);
      grund = "startschaetzung";
    }
    zeilen.push({ positionKey: p.key, load, secondaryLoad: null, grund, algoVersion: PLANGEWICHT_ALGO_VERSION });
  }
  if (zeilen.length === 0) return;

  const { error } = await client.rpc("init_plan_gewichte", { p_plan_id: plan.id, p_zeilen: zeilen });
  if (error?.code === "P0001" && error.message === "plan_ungueltig") {
    throw new DomainError("conflict", "Der Plan nimmt keine Startwerte an (plan_ungueltig).");
  }
  if (error) throw new DomainError("internal", error.message);
}

// ---------------------------------------------------------------------------
// Lesen fuer Bootstrap und Geraet (G17)
// ---------------------------------------------------------------------------

/**
 * Zielgewichte des Plans je Positionsschluessel, mit Aenderung gegenueber dem letzten
 * tatsaechlich benutzten Gewicht (letzter Arbeitssatz) an diesem Geraet und dieser
 * Uebung. Positionen ohne Zeile fehlen im Ergebnis (App: wie freies Training).
 */
export async function ladeZielgewichte(
  client: SupabaseClient,
  userId: string,
  plan: TrainingPlan,
): Promise<Record<string, PositionsZiel>> {
  const zeilen = await ladeZielZeilen(client, userId, plan.id);
  if (zeilen.size === 0) return {};
  const positionen = positionenVon(plan.einheiten);
  const mitZiel = [...zeilen.keys()].flatMap((k) => {
    const p = positionen.get(k);
    return p ? [p] : [];
  });
  const jetzt = Date.now();
  // Verglichen wird nur mit abgeschlossenen Einheiten: in der laufenden darf sich der
  // Hinweis nicht unter dem Mitglied aendern (G17). Ohne Satz in den letzten 42 Tagen
  // (F18: wie ohne Historie): null.
  const [historie, laufend] = await Promise.all([
    ladeArbeitssaetze(client, userId, mitZiel, new Date(jetzt - HISTORIE_FENSTER_TAGE * TAG_MS)),
    laufendeSessions(client, userId, jetzt),
  ]);

  const ergebnis: Record<string, PositionsZiel> = {};
  for (const p of mitZiel) {
    const z = zeilen.get(p.key)!;
    const letzter = historie
      .get(paarSchluessel(p.machineId, p.exerciseId))
      ?.find((s) => !laufend.has(s.session_id));
    const load = Number(z.load);
    ergebnis[p.key] = {
      load,
      secondaryLoad: z.secondary_load === null ? null : Number(z.secondary_load),
      aenderung: aenderungZumLetzten(load, letzter ? Number(letzter.load) : null),
      grund: z.grund as PlanGewichtGrund | null,
    };
  }
  return ergebnis;
}
