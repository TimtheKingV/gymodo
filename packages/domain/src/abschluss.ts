import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import type { LoadUnit } from "./belastung.js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextLoad,
  toBlocks,
  type ProgressionReasonCode,
  type ProgressionSuggestion,
  type SatzZeile,
} from "./progression.js";

/**
 * Belastungs- und Nebenbelastungseinheit eines Geraets -- der Screen soll
 * "+0,5 km/h bei 6 %" schreiben koennen, ohne das Modell nachzuladen
 * (M1-Spec SS6.3, screenorientiert).
 */
export type Blockeinheiten = {
  loadUnit: LoadUnit;
  secondaryUnit: LoadUnit | null;
};

/**
 * Was TrainingAbschluss unter "Beim naechsten Mal" je Block zeigt.
 *
 * deltaLoad ist der sichtbare Teil ("+2,5"), resultLoad der Wert dahinter.
 * Beide sind null, wenn es keinen Vorschlag gibt -- der reasonCode sagt
 * dann, warum. secondaryLoad ist die Nebenbelastung, bei der der Vorschlag
 * gilt (Cardio-Spec Abschnitt 3.1b); sie wird nie gesteigert, nur genannt.
 */
export type Blockvorschlag = {
  machineId: string;
  exerciseId: string;
  resultLoad: number | null;
  deltaLoad: number | null;
  secondaryLoad: number | null;
  loadUnit: LoadUnit;
  secondaryUnit: LoadUnit | null;
  reasonCode: ProgressionReasonCode;
  algoVersion: string;
};

/**
 * Die Paare aus Geraet und Uebung dieser Session, in der Reihenfolge ihres
 * ersten Auftretens -- dieselbe Blockdefinition wie im Training selbst
 * (M1-Spec SS5.3: ein Block ist ein Geraet plus eine Uebung).
 */
export function blockPaare(
  rows: Array<{ machine_id: string; exercise_id: string }>,
): Array<{ machineId: string; exerciseId: string }> {
  const gesehen = new Set<string>();
  const paare: Array<{ machineId: string; exerciseId: string }> = [];
  for (const row of rows) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    if (gesehen.has(schluessel)) continue;
    gesehen.add(schluessel);
    paare.push({ machineId: row.machine_id, exerciseId: row.exercise_id });
  }
  return paare;
}

/**
 * Das Delta ist die Zahl, die der Screen zeigt. Es entsteht nur, wenn es
 * beides gibt: einen Vorschlag und eine bisherige Belastung, gegen die er
 * sich vergleichen laesst.
 */
export function zuVorschlag(eingabe: {
  machineId: string;
  exerciseId: string;
  suggestion: ProgressionSuggestion;
  einheiten: Blockeinheiten;
}): Blockvorschlag {
  const { resultLoad, resultSecondaryLoad, reasonCode, algoVersion, inputs } =
    eingabe.suggestion;
  const bisher = inputs.currentLoad;
  const deltaLoad =
    resultLoad === null || bisher === null || bisher === undefined
      ? null
      : Number((resultLoad - bisher).toFixed(2));

  return {
    machineId: eingabe.machineId,
    exerciseId: eingabe.exerciseId,
    resultLoad,
    deltaLoad,
    secondaryLoad: resultSecondaryLoad,
    loadUnit: eingabe.einheiten.loadUnit,
    secondaryUnit: eingabe.einheiten.secondaryUnit,
    reasonCode,
    algoVersion,
  };
}

/** Eine Zeile aus progression_suggestions, so wie sie zurueckgelesen wird. */
export type GespeicherteVorschlagZeile = {
  machine_id: string;
  exercise_id: string;
  created_at: string;
  algo_version: string;
  result_load: number | string | null;
  reason_code: string;
  /**
   * Schluessel der Algorithmusversion 2.0.0. Eine Zeile aus 1.0.0 traegt
   * currentWeightKg statt currentLoad; ihr Delta bleibt dann offen, der
   * Vorschlag selbst wird trotzdem gezeigt. Alte Zeilen werden nie
   * umgeschrieben (Migration 0015: kein Update).
   */
  inputs: {
    currentLoad?: number | string | null;
    currentSecondaryLoad?: number | string | null;
  } | null;
};

/**
 * Wie weit `created_at` von `completed_at` abweichen darf, damit eine Zeile
 * noch als "von diesem Abschluss geschrieben" gilt.
 *
 * Der Abschluss schreibt seine Zeilen im selben Request, unmittelbar nach
 * dem Setzen von completed_at -- der Abstand ist im Normalfall
 * Millisekunden. Das Fenster muss trotzdem in BEIDE Richtungen reichen,
 * weil die beiden Zeitpunkte aus verschiedenen Uhren kommen: completed_at
 * aus der Node-Uhr (`new Date()`), created_at aus der Datenbank (`now()`).
 * Fuenf Minuten sind grosszuegig gegen jede realistische Uhrendifferenz
 * und immer noch weit weniger, als zwischen zwei Trainingseinheiten
 * desselben Mitglieds liegt.
 */
export const ABSCHLUSS_ZEITFENSTER_MS = 5 * 60 * 1000;

/**
 * Baut die Vorschlaege eines bereits abgeschlossenen Trainings aus den
 * festgehaltenen Zeilen -- ohne zu rechnen und ohne zu schreiben.
 *
 * Die Regel, und nur sie: eine Zeile gehoert zu diesem Abschluss, wenn sie
 * zum selben Block gehoert UND ihr `created_at` hoechstens
 * ABSCHLUSS_ZEITFENSTER_MS von `completedAt` entfernt liegt. Innerhalb des
 * Fensters gewinnt die aelteste Zeile ab `completedAt` -- der Abschluss
 * schreibt unmittelbar danach, spaetere Zeilen desselben Blocks stammen
 * von einem Geraetescan (tag-context schreibt in dieselbe Tabelle). Liegt
 * im Fenster nichts ab `completedAt`, gewinnt die juengste davor; das ist
 * der Uhrendifferenz-Fall.
 *
 * AUSSERHALB des Fensters wird NICHTS zugeordnet, und der Block faellt
 * weg. Ein frueherer Rueckfall auf "die neueste Zeile ueberhaupt" konnte
 * eine Zeile aus einer ANDEREN Einheit heranziehen -- der Screen zeigte
 * dann einen Vorschlag, den es fuer dieses Training nie gab. Ein fehlender
 * Vorschlag ist eine Luecke; ein fremder ist eine Falschaussage.
 *
 * `progression_suggestions` hat keine session_id; ohne die ist der
 * Zeitpunkt der einzige Beleg, den die Ablage hergibt. Die Schranke sagt
 * genau, wie weit dieser Beleg traegt.
 *
 * NICHT GEDECKT, ausdruecklich: eine SELBSTTAETIG beendete Einheit.
 * `listSessions` setzt dort completed_at auf den letzten Satz (Stunden
 * zurueck) und completed_reason auf "auto", schreibt aber keine
 * Vorschlagszeile -- es gibt also gar keine, die im Fenster liegen
 * koennte, und ein spaeterer POST /complete liefert fuer diese Einheit
 * keine Vorschlaege. Das ist Absicht: nachtraeglich zu rechnen und zu
 * schreiben hiesse, eine Nachweiszeile mit dem Datum von heute fuer einen
 * Abschluss von gestern anzulegen -- und zwei schnell aufeinander folgende
 * Aufrufe (der Client ruft aus einem `.task` ohne id) faenden beide ein
 * leeres Fenster und schrieben beide. Genau die Dublette, gegen die der
 * Frueheinstieg da ist.
 */
export function ausGespeichertenZeilen(
  paare: Array<{ machineId: string; exerciseId: string }>,
  zeilen: GespeicherteVorschlagZeile[],
  completedAt: string,
  einheitenJeGeraet: Map<string, Blockeinheiten>,
): Blockvorschlag[] {
  const grenze = Date.parse(completedAt);
  const fensterVon = grenze - ABSCHLUSS_ZEITFENSTER_MS;
  const fensterBis = grenze + ABSCHLUSS_ZEITFENSTER_MS;
  const nachBlock = new Map<string, GespeicherteVorschlagZeile[]>();
  for (const zeile of zeilen) {
    const wann = Date.parse(zeile.created_at);
    if (!(wann >= fensterVon && wann <= fensterBis)) continue;
    const schluessel = `${zeile.machine_id}:${zeile.exercise_id}`;
    const liste = nachBlock.get(schluessel) ?? [];
    liste.push(zeile);
    nachBlock.set(schluessel, liste);
  }

  const vorschlaege: Blockvorschlag[] = [];
  for (const paar of paare) {
    const liste = nachBlock.get(`${paar.machineId}:${paar.exerciseId}`);
    if (!liste || liste.length === 0) continue;
    // Ohne Einheit kein Vorschlag: "kg" zu raten waere an einem Laufband
    // eine Falschaussage. Kommt nicht vor, solange bloeckeDerSession die
    // Geraete mitliest -- die Schranke steht fuer den Fall, dass das mal
    // nicht mehr stimmt.
    const einheiten = einheitenJeGeraet.get(paar.machineId);
    if (!einheiten) continue;

    const sortiert = [...liste].sort(
      (a, b) => Date.parse(a.created_at) - Date.parse(b.created_at),
    );
    // Aelteste Zeile ab completedAt; sonst -- nur bei Uhrendifferenz --
    // die juengste davor. Beide liegen bereits im Fenster, die Liste
    // enthaelt nichts anderes mehr.
    const zeile =
      sortiert.find((k) => Date.parse(k.created_at) >= grenze) ??
      sortiert[sortiert.length - 1]!;

    const ergebnis =
      zeile.result_load === null || zeile.result_load === undefined
        ? null
        : Number(zeile.result_load);
    const bisherRoh = zeile.inputs?.currentLoad;
    const bisher =
      bisherRoh === null || bisherRoh === undefined ? null : Number(bisherRoh);
    const deltaLoad =
      ergebnis === null || bisher === null
        ? null
        : Number((ergebnis - bisher).toFixed(2));
    const nebenRoh = zeile.inputs?.currentSecondaryLoad;
    const secondaryLoad =
      ergebnis === null || nebenRoh === null || nebenRoh === undefined
        ? null
        : Number(nebenRoh);

    vorschlaege.push({
      machineId: paar.machineId,
      exerciseId: paar.exerciseId,
      resultLoad: ergebnis,
      deltaLoad,
      secondaryLoad,
      loadUnit: einheiten.loadUnit,
      secondaryUnit: einheiten.secondaryUnit,
      reasonCode: zeile.reason_code as ProgressionReasonCode,
      algoVersion: zeile.algo_version,
    });
  }
  return vorschlaege;
}

/**
 * Die Bloecke einer Session, in der Reihenfolge ihres ersten Auftretens,
 * samt Studio und den Einheiten je Geraet -- die eine Abfrage, die beide
 * Wege (rechnen und zuruecklesen) gleichermassen brauchen. Die Einheiten
 * kommen ueber den Join mit, damit der Rueckleseweg keinen zweiten
 * Roundtrip braucht.
 */
async function bloeckeDerSession(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<{
  paare: Array<{ machineId: string; exerciseId: string }>;
  studioId: string | null;
  einheitenJeGeraet: Map<string, Blockeinheiten>;
}> {
  const { data: sessionSaetze, error } = await client
    .from("workout_sets")
    .select(
      "machine_id, exercise_id, studio_id, machines (equipment_models (load_unit, secondary_unit))",
    )
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .order("performed_at", { ascending: true });
  if (error) throw new DomainError("internal", error.message);

  const zeilen = (sessionSaetze ?? []) as unknown as Array<{
    machine_id: string;
    exercise_id: string;
    studio_id: string;
    machines: {
      equipment_models: { load_unit: LoadUnit; secondary_unit: LoadUnit | null };
    } | null;
  }>;
  const paare = blockPaare(zeilen);
  const einheitenJeGeraet = new Map<string, Blockeinheiten>();
  for (const zeile of zeilen) {
    const modell = zeile.machines?.equipment_models;
    if (!modell || einheitenJeGeraet.has(zeile.machine_id)) continue;
    einheitenJeGeraet.set(zeile.machine_id, {
      loadUnit: modell.load_unit,
      secondaryUnit: modell.secondary_unit,
    });
  }
  return { paare, studioId: zeilen[0]?.studio_id ?? null, einheitenJeGeraet };
}

/**
 * Die Vorschlaege einer SCHON abgeschlossenen Session -- nur lesend.
 *
 * Der idempotente Frueheinstieg von completeSession ist genau dafuer da,
 * nichts noch einmal zu tun. Neu zu rechnen hiesse, ein zweites Mal nach
 * progression_suggestions zu schreiben, und die Tabelle hat keinen
 * eindeutigen Index -- jeder Wiederholer erzeugte Dubletten in genau der
 * Ablage, die die Nachvollziehbarkeit tragen soll (M1-Spec SS8.4).
 */
export async function gespeicherteVorschlaege(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
  completedAt: string,
): Promise<Blockvorschlag[]> {
  const { paare, einheitenJeGeraet } = await bloeckeDerSession(
    client,
    sessionId,
    userId,
  );
  if (paare.length === 0) return [];

  const machineIds = [...new Set(paare.map((p) => p.machineId))];
  const exerciseIds = [...new Set(paare.map((p) => p.exerciseId))];

  // Dieselbe Zeitschranke wie in ausGespeichertenZeilen, schon in der
  // Abfrage: ohne sie koennte `limit` die gemeinte Zeile aus dem Ergebnis
  // draengen, sobald ein Block viele juengere Vorschlaege hat (jeder
  // Geraetescan schreibt einen). Das Fenster ist zehn Minuten breit --
  // mehr als eine Handvoll Zeilen je Block passt da nicht hinein.
  const grenze = Date.parse(completedAt);
  const fensterVon = new Date(grenze - ABSCHLUSS_ZEITFENSTER_MS).toISOString();
  const fensterBis = new Date(grenze + ABSCHLUSS_ZEITFENSTER_MS).toISOString();

  const { data: zeilen, error } = await client
    .from("progression_suggestions")
    .select(
      "machine_id, exercise_id, created_at, algo_version, result_load, reason_code, inputs",
    )
    .eq("user_id", userId)
    .in("machine_id", machineIds)
    .in("exercise_id", exerciseIds)
    .gte("created_at", fensterVon)
    .lte("created_at", fensterBis)
    .order("created_at", { ascending: true })
    .limit(paare.length * 8);
  if (error) throw new DomainError("internal", error.message);

  return ausGespeichertenZeilen(
    paare,
    (zeilen ?? []) as GespeicherteVorschlagZeile[],
    completedAt,
    einheitenJeGeraet,
  );
}

/**
 * Vorschlaege fuer alle Bloecke einer beendeten Session.
 *
 * Fuenf Abfragen, unabhaengig von der Blockzahl -- Saetze der Session,
 * Uebungen, Geraetemodelle, Historie ueber alle betroffenen Geraete, und
 * ein Sammel-Insert. Ein Aufruf je Block waere N+1 auf einem Pfad, den
 * jedes beendete Training nimmt.
 *
 * Wird in derselben Anfrage festgehalten wie berechnet (M1-Spec SS8.4):
 * Nachvollziehbarkeit ohne Queue, genau wie beim Geraetevorschlag.
 *
 * SCHREIBT. Gehoert deshalb ausschliesslich in den Zweig, der die Session
 * tatsaechlich abschliesst; ein wiederholter Abschluss liest ueber
 * gespeicherteVorschlaege zurueck, statt neu zu rechnen.
 *
 * Jede Abfrage UND der Insert pruefen ihr `error` und werfen. Ein `?? []` auf einem
 * Transportfehler waere hier keine Vorsicht, sondern eine Aussage ueber
 * das Mitglied, die niemand geprueft hat -- und eine davon wuerde
 * festgeschrieben (siehe die Historie unten). Faellt der Abschluss
 * deshalb aus, bleibt die Session trotzdem beendet: der Screen zeigt
 * seine Zahlen (die sind lokal) und sagt, dass der Blick nach vorn
 * fehlt.
 */
export async function vorschlaegeFuerAbschluss(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<Blockvorschlag[]> {
  const { paare, studioId, einheitenJeGeraet } = await bloeckeDerSession(
    client,
    sessionId,
    userId,
  );
  if (paare.length === 0 || studioId === null) return [];

  const machineIds = [...new Set(paare.map((p) => p.machineId))];
  const exerciseIds = [...new Set(paare.map((p) => p.exerciseId))];

  const { data: uebungen, error: uebungenFehler } = await client
    .from("exercises")
    .select("id, target_min, target_max")
    .in("id", exerciseIds);
  if (uebungenFehler) throw new DomainError("internal", uebungenFehler.message);

  const { data: geraete, error: geraeteFehler } = await client
    .from("machines")
    .select(
      "id, equipment_models (load_step, load_min, load_max)",
    )
    .in("id", machineIds);
  if (geraeteFehler) throw new DomainError("internal", geraeteFehler.message);

  // Die Historie aller betroffenen Geraete in einer Abfrage. Groesseres
  // Fenster als in tag-context (dort HISTORY_DAYS * 6 = 36 Zeilen fuer EIN
  // Geraet): hier teilen sich alle Uebungen an derselben Maschine eine
  // gemeinsame Abfrage, und ein Block muss auch dann noch genug Zeilen
  // abbekommen, wenn ein anderer Block an derselben Maschine haengt.
  // Deshalb 60 Zeilen je Block statt 36.
  const { data: historie, error: historieFehler } = await client
    .from("workout_sets")
    .select(
      "machine_id, exercise_id, performed_at, load, secondary_load, volume, rir, problem_flag",
    )
    .eq("user_id", userId)
    .in("machine_id", machineIds)
    .order("performed_at", { ascending: false })
    .limit(paare.length * 60);
  // Die folgenschwerste der fuenf Pruefungen. Ohne sie faellt ein
  // Transportfehler per `?? []` auf eine LEERE Historie zurueck,
  // suggestNextLoad liefert `kein_verlauf`, und der insert unten
  // schreibt das als Nachweiszeile fest: in der Ablage, die laut
  // M1-Spec SS8.4 dokumentiert, WARUM ein Vorschlag so ausfiel, staende
  // dann "keine Historie" fuer ein Mitglied, das Historie hat. Eine
  // dauerhaft unwahre Zeile in einer Tabelle, die nie aktualisiert wird
  // (Migration 0015: kein Update, kein Delete). Lieber gar kein
  // Vorschlag als ein falsch begruendeter.
  if (historieFehler) throw new DomainError("internal", historieFehler.message);

  const uebungNach = new Map(
    (uebungen ?? []).map((u) => {
      const row = u as { id: string; target_min: number; target_max: number };
      return [row.id, row];
    }),
  );
  const modellNach = new Map(
    (geraete ?? []).map((g) => {
      const row = g as unknown as {
        id: string;
        equipment_models: {
          load_step: number | string;
          load_min: number | string;
          load_max: number | string | null;
        };
      };
      return [row.id, row.equipment_models];
    }),
  );

  const historieNach = new Map<string, SatzZeile[]>();
  for (const row of (historie ?? []) as Array<SatzZeile & {
    machine_id: string;
    exercise_id: string;
  }>) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    const liste = historieNach.get(schluessel) ?? [];
    liste.push(row);
    historieNach.set(schluessel, liste);
  }

  const vorschlaege: Blockvorschlag[] = [];
  // inputs steht mit im Insert -- die Spalte ist not null (Migration 0015)
  // und will fuer die Nachvollziehbarkeit ohnehin die echten Eingaben, nicht
  // ein leeres Objekt.
  const zeilenFuerInsert: Array<{
    studio_id: string;
    user_id: string;
    machine_id: string;
    exercise_id: string;
    algo_version: string;
    inputs: ProgressionSuggestion["inputs"];
    result_load: number | null;
    reason_code: ProgressionReasonCode;
  }> = [];

  for (const paar of paare) {
    const uebung = uebungNach.get(paar.exerciseId);
    const modell = modellNach.get(paar.machineId);
    const einheiten = einheitenJeGeraet.get(paar.machineId);
    if (!uebung || !modell || !einheiten) continue;

    const suggestion = suggestNextLoad({
      targetMin: uebung.target_min,
      targetMax: uebung.target_max,
      loadStep: Number(modell.load_step),
      loadMin: Number(modell.load_min),
      loadMax: Number(modell.load_max ?? 9999),
      history: toBlocks(
        historieNach.get(`${paar.machineId}:${paar.exerciseId}`) ?? [],
      ),
    });

    const vorschlag = zuVorschlag({ ...paar, suggestion, einheiten });
    vorschlaege.push(vorschlag);
    zeilenFuerInsert.push({
      studio_id: studioId,
      user_id: userId,
      machine_id: vorschlag.machineId,
      exercise_id: vorschlag.exerciseId,
      algo_version: PROGRESSION_ALGO_VERSION,
      inputs: suggestion.inputs,
      result_load: vorschlag.resultLoad,
      reason_code: vorschlag.reasonCode,
    });
  }

  if (zeilenFuerInsert.length > 0) {
    // Auch der Insert prueft sein error -- ein stiller Fehlschlag hiesse,
    // dass der Screen Vorschlaege zeigt, die nirgends festgehalten sind.
    // Der naechste Aufruf faende im Zeitfenster dann nichts und liesse die
    // Bloecke weg: dieselbe Zahl waere einmal da und einmal nicht, ohne
    // dass irgendwo stuende, warum.
    const { error: insertFehler } = await client
      .from("progression_suggestions")
      .insert(zeilenFuerInsert);
    if (insertFehler) throw new DomainError("internal", insertFehler.message);
  }

  return vorschlaege;
}
