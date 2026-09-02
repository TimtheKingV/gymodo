import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * studio_overview, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 4: die einzige Stelle, an der Trainingsdaten fuer Personal
 * ueberhaupt noch erreichbar sind -- ausschliesslich als Summe.
 *
 * Das Studio bekommt sechs aktive Mitglieder, damit die Mindestzahl von
 * fuenf ueberschritten ist. Ein zweites Studio mit nur zwei aktiven
 * Mitgliedern prueft die Gegenrichtung.
 */

type Uebersicht = {
  days: number;
  active_members: number;
  sets: number;
  problem_reports: number;
  min_members: number;
  breakdown: boolean;
  top_machines: { machine_id: string; label: string; status: string; sets: number }[];
  problems: { machine_id: string; label: string; reason: string | null; count: number }[];
};

let studioId: string;
let kleinStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let fremdTrainerEmail: string;
let kleinTrainerEmail: string;
let beinpresseId: string;
let latzugId: string;

async function studioMitDaten(
  admin: ReturnType<typeof serviceClient>,
  name: string,
  anzahlMitglieder: number,
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
    .insert({ studio_id: studio.id, name: "Kraftgerät", weight_step_kg: 2.5 })
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
      target_reps_min: 8,
      target_reps_max: 12,
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
        weight_kg: 40,
        reps: 10,
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
        weight_kg: 40,
        reps: 8,
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
        weight_kg: 30,
        reps: 12,
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

  trainerEmail = uniqueEmail("ueb-trainer");
  mitgliedEmail = uniqueEmail("ueb-mitglied");
  fremdTrainerEmail = uniqueEmail("ueb-fremd-trainer");
  kleinTrainerEmail = uniqueEmail("ueb-klein-trainer");

  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);
  const kleinTrainerId = await createTestUser(kleinTrainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: kleinStudioId, user_id: kleinTrainerId, role: "trainer" },
    { studio_id: kleinStudioId, user_id: fremdTrainerId, role: "trainer" },
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
    expect(uebersicht.active_members).toBe(2);
    expect(uebersicht.sets).toBe(6);
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
  it("unter fuenf aktiven Mitgliedern gibt es keine Aufschluesselung je Geraet", async () => {
    const client = await userClient(kleinTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: kleinStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    // Die Summen bleiben -- sie sagen, OB das Studio benutzt wird.
    expect(uebersicht.sets).toBe(6);
    // Die Rangliste faellt weg: bei zwei Aktiven verraet sie, wer was
    // trainiert hat (Spec Abschnitt 4, Vorbehalt).
    expect(uebersicht.breakdown).toBe(false);
    expect(uebersicht.top_machines).toEqual([]);
    expect(uebersicht.problems).toEqual([]);
    // Die Schwelle reist mit, damit die Oberflaeche den Leer-Zustand
    // begruenden kann statt bloss leer zu sein.
    expect(uebersicht.min_members).toBe(5);
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
