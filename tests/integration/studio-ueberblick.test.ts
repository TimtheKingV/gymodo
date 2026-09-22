import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * studio_overview, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 4: die einzige Stelle, an der Trainingsdaten fuer Personal
 * ueberhaupt noch erreichbar sind -- ausschliesslich als Summe.
 *
 * Drei Studios: eines mit sechs Erfassenden, damit die Mindestzahl von
 * fuenf ueberschritten ist. Eines mit zweien fuer die Gegenrichtung. Und
 * eines, in dem fuenf Leute eine Einheit begonnen, aber nur einer davon
 * Saetze bestaetigt hat -- dort entscheidet sich, ob die Schwelle an der
 * richtigen Menge haengt.
 */

type Uebersicht = {
  days: number;
  active_members: number;
  sets: number | null;
  problem_reports: number | null;
  min_members: number;
  breakdown: boolean;
  top_machines: { machine_id: string; label: string; status: string; sets: number }[];
  problems: { machine_id: string; label: string; reason: string | null; count: number }[];
};

let studioId: string;
let kleinStudioId: string;
let antippStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let mitgliedId: string;
let fremdTrainerEmail: string;
let kleinTrainerEmail: string;
let antippTrainerEmail: string;
let beinpresseId: string;
let latzugId: string;

/**
 * `anzahlErfassende` trennt, was in der Datenbank zwei verschiedene Mengen
 * sind: wer eine Einheit begonnen hat (workout_sessions) und wer Saetze
 * bestaetigt hat (workout_sets). Ohne diese Trennung liesse sich nicht
 * pruefen, ueber welcher der beiden die Schwelle gebildet wird.
 */
async function studioMitDaten(
  admin: ReturnType<typeof serviceClient>,
  name: string,
  anzahlMitglieder: number,
  anzahlErfassende: number = anzahlMitglieder,
): Promise<{ studioId: string; machineIds: string[] }> {
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name })
    .select("id")
    .single();
  if (studioError) throw studioError;

  // Fuer die E-Mail-Adresse der Testnutzer wird der Studioname zu einem
  // Schlagwort ohne Leerzeichen verkuerzt -- "Kleines Ueberblick-Studio"
  // waere sonst eine ungueltige Adresse. Der Anzeigename selbst bleibt
  // unveraendert.
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-");

  const { data: modell, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Kraftgerät", load_step: 2.5 })
    .select("id")
    .single();
  if (modellError) throw modellError;

  // exercises haengt nicht am Modell -- die Zuordnung liegt in
  // equipment_model_exercises (0005). Fuer den Ueberblick reicht die
  // Uebung selbst, weil workout_sets direkt auf sie zeigt.
  const { data: uebung, error: uebungError } = await admin
    .from("exercises")
    .insert({
      studio_id: studio.id,
      name: "Zug",
      target_min: 8,
      target_max: 12,
    })
    .select("id")
    .single();
  if (uebungError) throw uebungError;

  const { data: geraeteZeilen, error: geraeteError } = await admin
    .from("machines")
    .insert([
      { studio_id: studio.id, equipment_model_id: modell.id, label: "Beinpresse 7" },
      { studio_id: studio.id, equipment_model_id: modell.id, label: "Latzug 13" },
    ])
    .select("id, label");
  if (geraeteError) throw geraeteError;

  // Nach Beschriftung nachschlagen statt nach Position: die Reihenfolge
  // eines mehrzeiligen Inserts ist nicht zugesichert, und ein Test, der
  // sie annimmt, faellt irgendwann ohne Grund aus.
  const geraete = ["Beinpresse 7", "Latzug 13"].map(
    (label) => geraeteZeilen.find((zeile) => zeile.label === label)!,
  );

  for (let i = 0; i < anzahlMitglieder; i += 1) {
    const email = uniqueEmail(`ueb-${slug}-m${i}`);
    const userId = await createTestUser(email);
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studio.id, user_id: userId, role: "member" });

    const sessionId = crypto.randomUUID();
    await admin.from("workout_sessions").insert({
      id: sessionId,
      studio_id: studio.id,
      user_id: userId,
    });

    // Wer ueber `anzahlErfassende` hinausgeht, hat nur angetippt: eine
    // begonnene Einheit, kein bestaetigter Satz.
    if (i >= anzahlErfassende) continue;

    // Zwei Saetze an der Beinpresse, einer am Latzug -- damit die
    // Rangliste eine Reihenfolge hat. Der Latzugsatz meldet ein Problem.
    //
    // problem_flag steht bei den ersten beiden Zeilen ausdruecklich auf
    // false: PostgREST erzeugt fuer einen Mehrzeilen-Insert eine gemeinsame
    // Spaltenliste ueber alle Objekte des Arrays, und eine Zeile, die ein
    // Feld nicht traegt, das eine andere Zeile im selben Array setzt,
    // bekommt dafuer ein ausdrueckliches NULL -- nicht den Tabellen-Default.
    // Ohne diese Zeile schluege der Insert an workout_sets_problem_flag
    // NOT NULL fehl.
    const { error: setError } = await admin.from("workout_sets").insert([
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[0]!.id,
        exercise_id: uebung.id,
        set_index: 1,
        load: 40,
        volume: 10,
        problem_flag: false,
      },
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[0]!.id,
        exercise_id: uebung.id,
        set_index: 2,
        load: 40,
        volume: 8,
        problem_flag: false,
      },
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[1]!.id,
        exercise_id: uebung.id,
        set_index: 1,
        load: 30,
        volume: 12,
        problem_flag: true,
        problem_reason: "schmerz",
      },
    ]);
    if (setError) throw setError;
  }

  return { studioId: studio.id, machineIds: geraete.map((g) => g.id) };
}

beforeAll(async () => {
  const admin = serviceClient();

  const gross = await studioMitDaten(admin, "Ueberblick-Studio", 6);
  studioId = gross.studioId;
  beinpresseId = gross.machineIds[0]!;
  latzugId = gross.machineIds[1]!;

  const klein = await studioMitDaten(admin, "Kleines Ueberblick-Studio", 2);
  kleinStudioId = klein.studioId;

  // Fuenf begonnene Einheiten, ein Erfassender: genau die Lage, in der die
  // Schwelle an der falschen Menge haengen wuerde.
  const antipp = await studioMitDaten(admin, "Antipp Ueberblick-Studio", 5, 1);
  antippStudioId = antipp.studioId;

  trainerEmail = uniqueEmail("ueb-trainer");
  mitgliedEmail = uniqueEmail("ueb-mitglied");
  fremdTrainerEmail = uniqueEmail("ueb-fremd-trainer");
  kleinTrainerEmail = uniqueEmail("ueb-klein-trainer");
  antippTrainerEmail = uniqueEmail("ueb-antipp-trainer");

  const trainerId = await createTestUser(trainerEmail);
  mitgliedId = await createTestUser(mitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);
  const kleinTrainerId = await createTestUser(kleinTrainerEmail);
  const antippTrainerId = await createTestUser(antippTrainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: kleinStudioId, user_id: kleinTrainerId, role: "trainer" },
    { studio_id: kleinStudioId, user_id: fremdTrainerId, role: "trainer" },
    { studio_id: antippStudioId, user_id: antippTrainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("studio_overview -- die Summen", () => {
  it("zaehlt aktive Mitglieder, Saetze und gemeldete Probleme", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    expect(error).toBeNull();
    const uebersicht = data as Uebersicht;
    expect(uebersicht.active_members).toBe(6);
    expect(uebersicht.sets).toBe(18);
    expect(uebersicht.problem_reports).toBe(6);
    expect(uebersicht.days).toBe(30);
  });

  it("zaehlt nur das eigene Studio", async () => {
    const client = await userClient(kleinTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: kleinStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    // Zwei, nicht dreizehn: die Aktiven der anderen beiden Studios sind
    // nicht mitgezaehlt. Die Satzzahl kann das hier nicht mehr zeigen --
    // sie ist unter der Schwelle verdeckt; dass sie im grossen Studio 18
    // ist und nicht die Summe aller drei Studios, beweist dasselbe.
    expect(uebersicht.active_members).toBe(2);
  });
});

describe("studio_overview -- die Aufschluesselung", () => {
  it("nennt die meistgenutzten Geraete mit Beschriftung und Anzahl", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    expect(uebersicht.breakdown).toBe(true);
    expect(uebersicht.top_machines[0]).toEqual({
      machine_id: beinpresseId,
      label: "Beinpresse 7",
      status: "active",
      sets: 12,
    });
    expect(uebersicht.top_machines[1]!.sets).toBe(6);
  });

  it("nennt gemeldete Probleme je Geraet und Grund -- ohne Namen", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    expect(uebersicht.problems).toEqual([
      { machine_id: latzugId, label: "Latzug 13", reason: "schmerz", count: 6 },
    ]);
    // Der Beweis, dass hier kein Personenbezug durchkommt: keine Zeile der
    // Antwort traegt ein Feld, das nach einem Nutzer aussieht.
    expect(JSON.stringify(uebersicht)).not.toMatch(/user_id|email/);
  });
});

describe("studio_overview -- die Mindestzahl", () => {
  it("unter fuenf Erfassenden gibt es weder Aufschluesselung noch Satzzahl", async () => {
    const client = await userClient(kleinTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: kleinStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    // Die Rangliste faellt weg: bei zwei Erfassenden verraet sie, wer was
    // trainiert hat (Spec Abschnitt 4, Vorbehalt).
    expect(uebersicht.breakdown).toBe(false);
    expect(uebersicht.top_machines).toEqual([]);
    expect(uebersicht.problems).toEqual([]);
    // Und die Skalare fallen mit weg: sechs Saetze auf zwei Personen sind
    // kein Studioprofil, sondern zwei Trainingsprotokolle. null, nicht 0
    // -- verdeckt ist nicht dasselbe wie keins.
    expect(uebersicht.sets).toBeNull();
    expect(uebersicht.problem_reports).toBeNull();
    // Die Kopfzahl bleibt: Abschnitt 4 zaehlt sie zum Sichtbaren, und die
    // Oberflaeche begruendet mit ihr, warum der Rest fehlt.
    expect(uebersicht.active_members).toBe(2);
    // Die Schwelle reist mit, damit die Oberflaeche den Leer-Zustand
    // begruenden kann statt bloss leer zu sein.
    expect(uebersicht.min_members).toBe(5);
  });

  it("fuenf begonnene Einheiten und ein Erfassender oeffnen nichts", async () => {
    const client = await userClient(antippTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: antippStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    // Fuenf haben angetippt, einer hat bestaetigt. Haenge die Schwelle an
    // den Begonnenen, waere sie erfuellt -- und die Rangliste gehoerte
    // vollstaendig dieser einen Person. Ein k-anonymer Satz muss ueber die
    // Zeilen gebildet werden, aus denen die Kennzahl entsteht.
    expect(uebersicht.active_members).toBe(5);
    expect(uebersicht.breakdown).toBe(false);
    expect(uebersicht.top_machines).toEqual([]);
    expect(uebersicht.problems).toEqual([]);
    expect(uebersicht.sets).toBeNull();
    expect(uebersicht.problem_reports).toBeNull();
  });

  it("ein Ein-Tages-Fenster wird auf sieben Tage aufgezogen", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 1,
    });

    // Die Funktion haengt an authenticated, also kann sie jeder Trainer
    // per RPC mit einem Fenster aufrufen, das die Oberflaeche nie benutzt.
    // Ein einzelner Tag waere ein Besuchsprotokoll, und die Differenz aus
    // N und N-1 ebenso.
    const uebersicht = data as Uebersicht;
    expect(uebersicht.days).toBe(7);
  });
});

describe("studio_overview -- wer darf", () => {
  it("ein Mitglied bekommt nichts", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    // Leer, nicht Fehler -- sonst waere die Funktion ein Orakel darueber,
    // welche Studios es gibt.
    expect(error).toBeNull();
    expect(data).toBeNull();
  });

  it("cross-tenant: der Trainer eines anderen Studios bekommt nichts", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    expect(error).toBeNull();
    expect(data).toBeNull();
  });
});

/**
 * Koerperdaten-Woerter, deren blosses Vorkommen als Teilstring nichts
 * beweisen wuerde: "age" steckt auch in "average", "message" und "page".
 * Deshalb wird jeder Schluessel in seine Wortbestandteile zerlegt -- an
 * "_" und an camelCase-Grenzen -- und nur ein ganzes Wortsegment zaehlt
 * als Treffer.
 */
const KOERPERDATEN_WOERTER = new Set(["weight", "measurement", "goal", "sex", "age", "height"]);

function schluesselSegmente(schluessel: string): string[] {
  return schluessel
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

/** Rekursiv ueber Objekte und Arrays -- gibt die Pfade aller Treffer zurueck. */
function findeKoerperdatenSchluessel(wert: unknown, pfad = ""): string[] {
  if (Array.isArray(wert)) {
    return wert.flatMap((eintrag, i) => findeKoerperdatenSchluessel(eintrag, `${pfad}[${i}]`));
  }
  if (wert === null || typeof wert !== "object") {
    return [];
  }
  const treffer: string[] = [];
  for (const [schluessel, teilwert] of Object.entries(wert as Record<string, unknown>)) {
    const eigenerPfad = pfad ? `${pfad}.${schluessel}` : schluessel;
    if (schluesselSegmente(schluessel).some((segment) => KOERPERDATEN_WOERTER.has(segment))) {
      treffer.push(eigenerPfad);
    }
    treffer.push(...findeKoerperdatenSchluessel(teilwert, eigenerPfad));
  }
  return treffer;
}

describe("studio_overview -- Koerperdaten bleiben aussen vor", () => {
  it("Positivkontrolle: der Scan-Helfer erkennt Koerperdaten-Schluessel", () => {
    // Beweist, dass der Helfer unten wirklich etwas findet -- sonst koennte
    // der naechste Test nur bestehen, weil der Helfer selbst nichts findet.
    expect(findeKoerperdatenSchluessel({ breakdown: [{ latestWeight: 1 }] })).toEqual([
      "breakdown[0].latestWeight",
    ]);
    expect(findeKoerperdatenSchluessel({ age_band: "x" })).toEqual(["age_band"]);
    // Und die Gegenprobe zum Wortsegment-Vergleich: "average", "message"
    // und "page" enthalten "age" nur als Teilstring, kein eigenstaendiges
    // Wortsegment -- der Helfer darf hier nichts finden.
    expect(findeKoerperdatenSchluessel({ average: 1, message: "x", page: 2 })).toEqual([]);
  });

  it("traegt keinen Koerperdaten-Schluessel, auch nicht als Summe -- Spec Abschnitt 6", async () => {
    // Spec Abschnitt 6: Koerperdaten bekommen keine Oeffnung, auch nicht
    // als Summe. studio_overview ist nach Abschnitt 4 die einzige Stelle,
    // an der Personal ueberhaupt etwas aggregiert sieht -- dieser Test
    // belegt, dass Koerpermesswerte, Ziele und Profil-Stammdaten eines
    // Mitglieds des betrachteten Studios davon ausgenommen bleiben.
    const admin = serviceClient();

    const { error: profilError } = await admin.from("profiles").upsert({
      id: mitgliedId,
      sex: "female",
      age_band: "25_34",
      height_cm: 170,
    });
    if (profilError) throw profilError;

    const { error: messError } = await admin.from("body_measurements").insert([
      { user_id: mitgliedId, measured_on: "2026-09-01", weight_kg: 70.0 },
      { user_id: mitgliedId, measured_on: "2026-09-02", weight_kg: 69.5 },
      { user_id: mitgliedId, measured_on: "2026-09-03", weight_kg: 69.0 },
    ]);
    if (messError) throw messError;

    const { error: zielError } = await admin.from("member_goals").insert([
      { user_id: mitgliedId, kind: "weekly_days", target_value: 3 },
      { user_id: mitgliedId, kind: "target_weight", target_value: 65 },
    ]);
    if (zielError) throw zielError;

    const client = await userClient(trainerEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    expect(error).toBeNull();
    const uebersicht = data as Uebersicht;
    // Die Schwelle muss erreicht sein, sonst waere der Scan bedeutungslos:
    // ein fast leeres Objekt haette ohnehin keine Koerperdaten-Schluessel.
    // studioId liegt mit sechs Erfassenden ueber der Mindestzahl von fuenf.
    expect(uebersicht.breakdown).toBe(true);
    expect(findeKoerperdatenSchluessel(uebersicht)).toEqual([]);
  });
});
