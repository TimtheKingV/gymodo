import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 5.
// Das Gymtavo-Studio legt die Migration 0047 selbst an -- mit fester id,
// damit Import und Tests es ohne Suche finden.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";

let studioA: string;
let studioB: string;
let ohneStudioEmail: string;
let memberAEmail: string;
let trainerAEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Katalog Studio A" }, { name: "Katalog Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  ohneStudioEmail = uniqueEmail("katalog-ohne-studio");
  memberAEmail = uniqueEmail("katalog-member-a");
  trainerAEmail = uniqueEmail("katalog-trainer-a");
  await createTestUser(ohneStudioEmail);
  const memberAId = await createTestUser(memberAEmail);
  const trainerAId = await createTestUser(trainerAEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: trainerAId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;
});

describe("Gymtavo-Studio", () => {
  it("ein Nutzer ohne Studio sieht genau das Gymtavo-Studio", async () => {
    const client = await userClient(ohneStudioEmail);

    const { data, error } = await client.from("studios").select("id, is_catalog");

    expect(error).toBeNull();
    expect(data).toEqual([{ id: GYMTAVO, is_catalog: true }]);
  });

  it("ein Mitglied sieht sein Studio und Gymtavo, kein fremdes", async () => {
    const client = await userClient(memberAEmail);

    const { data, error } = await client.from("studios").select("id");

    expect(error).toBeNull();
    const ids = (data ?? []).map((zeile) => zeile.id).sort();
    expect(ids).toEqual([GYMTAVO, studioA].sort());
    expect(ids).not.toContain(studioB);
  });

  it("im Gymtavo-Studio gibt es keine Mitglieder", async () => {
    const admin = serviceClient();
    const userId = await createTestUser(uniqueEmail("katalog-kein-member"));

    const { error } = await admin
      .from("studio_memberships")
      .insert({ studio_id: GYMTAVO, user_id: userId, role: "member" });

    expect(error?.code).toBe("P0001");
    expect(error?.message).toContain("gymtavo_keine_mitglieder");
  });

  it("aus Personal im Gymtavo-Studio wird kein Mitglied", async () => {
    const admin = serviceClient();
    const userId = await createTestUser(uniqueEmail("katalog-herabstufen"));
    const { error: insertError } = await admin
      .from("studio_memberships")
      .insert({ studio_id: GYMTAVO, user_id: userId, role: "trainer" });
    expect(insertError).toBeNull();

    const { error } = await admin
      .from("studio_memberships")
      .update({ role: "member" })
      .eq("studio_id", GYMTAVO)
      .eq("user_id", userId);

    expect(error?.message).toContain("gymtavo_keine_mitglieder");
  });

  it("das Gymtavo-Studio bekommt einen Owner", async () => {
    const admin = serviceClient();
    const userId = await createTestUser(uniqueEmail("katalog-owner"));

    const { error } = await admin
      .from("studio_memberships")
      .insert({ studio_id: GYMTAVO, user_id: userId, role: "owner" });

    expect(error).toBeNull();
  });

  it("im Gymtavo-Studio gibt es keine Geraete mit QR-Code", async () => {
    const admin = serviceClient();
    const { data: modell, error: modellError } = await admin
      .from("equipment_models")
      .insert({ studio_id: GYMTAVO, name: "Waechter-Typ", load_step: 2.5 })
      .select("id")
      .single();
    if (modellError) throw modellError;

    const { error } = await admin
      .from("machines")
      .insert({ studio_id: GYMTAVO, equipment_model_id: modell.id, label: "01" });

    expect(error?.message).toContain("gymtavo_ohne_geraete");
  });

  it("im Gymtavo-Studio gibt es keine Marken", async () => {
    const admin = serviceClient();

    await expect(
      tagsAnlegen(admin, [{ studioId: GYMTAVO, kind: "studio", status: "active" }]),
    ).rejects.toMatchObject({ message: expect.stringContaining("gymtavo_ohne_geraete") });
  });

  it("dem Gymtavo-Studio tritt niemand per Code bei", async () => {
    const admin = serviceClient();
    const { data: studio, error: studioError } = await admin
      .from("studios")
      .select("join_code, join_code_active")
      .eq("id", GYMTAVO)
      .single();
    if (studioError) throw studioError;
    expect(studio.join_code_active).toBe(false);

    const client = await userClient(ohneStudioEmail);
    const { data, error } = await client.rpc("join_studio_by_code", { p_code: studio.join_code });

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ein Trainer kann sein Studio nicht zum Katalog machen", async () => {
    const client = await userClient(trainerAEmail);

    const { error } = await client.from("studios").update({ is_catalog: true }).eq("id", studioA);

    expect(error?.code).toBe("42501");
  });
});

describe("Gymtavo-Katalog lesen", () => {
  let katalogModell: string;
  let katalogUebung: string;
  let katalogVerknuepfung: string;
  let katalogVideoPfad: string;
  let studioModellA: string;
  let studioUebungA: string;
  let gymtavoOwnerEmail: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const kennung = crypto.randomUUID();

    const { data: modelle, error: modellError } = await admin
      .from("equipment_models")
      .insert([
        { studio_id: GYMTAVO, name: `Langhantel ${kennung}`, load_step: 2.5 },
        { studio_id: studioA, name: `Studio-Presse ${kennung}`, load_step: 5 },
      ])
      .select("id");
    if (modellError) throw modellError;
    katalogModell = modelle[0]!.id;
    studioModellA = modelle[1]!.id;

    const { error: einstellungError } = await admin.from("equipment_setting_definitions").insert({
      equipment_model_id: katalogModell,
      key: "griffbreite",
      label: "Griffbreite",
      kind: "number",
      min_value: 1,
      max_value: 5,
      step_value: 1,
    });
    if (einstellungError) throw einstellungError;

    const { data: uebungen, error: uebungError } = await admin
      .from("exercises")
      .insert([
        { studio_id: GYMTAVO, name: `Bankdruecken ${kennung}`, target_min: 6, target_max: 10 },
        { studio_id: studioA, name: `Studio-Uebung ${kennung}`, target_min: 8, target_max: 12 },
      ])
      .select("id");
    if (uebungError) throw uebungError;
    katalogUebung = uebungen[0]!.id;
    studioUebungA = uebungen[1]!.id;

    const { data: verknuepfung, error: verknuepfungError } = await admin
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: katalogModell, exercise_id: katalogUebung })
      .select("id")
      .single();
    if (verknuepfungError) throw verknuepfungError;
    katalogVerknuepfung = verknuepfung.id;

    katalogVideoPfad = `${GYMTAVO}/${katalogVerknuepfung}/${kennung}.mp4`;
    const { error: uploadError } = await admin.storage
      .from("instruction-videos")
      .upload(katalogVideoPfad, new Blob([new Uint8Array(16)], { type: "video/mp4" }), {
        contentType: "video/mp4",
      });
    if (uploadError) throw uploadError;

    const { error: assetError } = await admin.from("instruction_assets").insert({
      equipment_model_exercise_id: katalogVerknuepfung,
      kind: "video",
      storage_path: katalogVideoPfad,
      duration_s: 20,
    });
    if (assetError) throw assetError;

    gymtavoOwnerEmail = uniqueEmail("katalog-pflege");
    const ownerId = await createTestUser(gymtavoOwnerEmail);
    const { error: ownerError } = await admin
      .from("studio_memberships")
      .insert({ studio_id: GYMTAVO, user_id: ownerId, role: "owner" });
    if (ownerError) throw ownerError;
  });

  it("ein Nutzer ohne Studio liest Geraetetyp, Einstellung, Uebung, Verknuepfung und Video", async () => {
    const client = await userClient(ohneStudioEmail);

    const modell = await client.from("equipment_models").select("id").eq("id", katalogModell);
    const einstellung = await client
      .from("equipment_setting_definitions")
      .select("key")
      .eq("equipment_model_id", katalogModell);
    const uebung = await client.from("exercises").select("id").eq("id", katalogUebung);
    const verknuepfung = await client
      .from("equipment_model_exercises")
      .select("id")
      .eq("id", katalogVerknuepfung);
    const video = await client
      .from("instruction_assets")
      .select("storage_path")
      .eq("equipment_model_exercise_id", katalogVerknuepfung);
    const signiert = await client.storage
      .from("instruction-videos")
      .createSignedUrl(katalogVideoPfad, 60);

    expect(modell.data).toHaveLength(1);
    expect(einstellung.data).toEqual([{ key: "griffbreite" }]);
    expect(uebung.data).toHaveLength(1);
    expect(verknuepfung.data).toHaveLength(1);
    expect(video.data).toEqual([{ storage_path: katalogVideoPfad }]);
    expect(signiert.error).toBeNull();
    expect(signiert.data?.signedUrl).toBeTruthy();
  });

  it("ein Nutzer ohne Studio sieht von Studio A weder Modell noch Uebung", async () => {
    const client = await userClient(ohneStudioEmail);

    const modell = await client.from("equipment_models").select("id").eq("id", studioModellA);
    const uebung = await client.from("exercises").select("id").eq("id", studioUebungA);

    expect(modell.data).toEqual([]);
    expect(uebung.data).toEqual([]);
  });

  it("ein Nutzer ohne Studio aendert am Katalog nichts", async () => {
    const client = await userClient(ohneStudioEmail);

    const neuesModell = await client
      .from("equipment_models")
      .insert({ studio_id: GYMTAVO, name: "Eingeschmuggelt", load_step: 1 });
    const neueUebung = await client
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: "Eingeschmuggelt", target_min: 1, target_max: 2 });
    const umbenannt = await client
      .from("exercises")
      .update({ name: "Umbenannt" })
      .eq("id", katalogUebung)
      .select("id");
    const geloescht = await client
      .from("equipment_model_exercises")
      .delete()
      .eq("id", katalogVerknuepfung)
      .select("id");

    expect(neuesModell.error?.code).toBe("42501");
    expect(neueUebung.error?.code).toBe("42501");
    expect(umbenannt.data).toEqual([]);
    expect(geloescht.data).toEqual([]);
  });

  it("der Gymtavo-Owner pflegt den Katalog", async () => {
    const client = await userClient(gymtavoOwnerEmail);

    const { error } = await client
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: `Kreuzheben ${crypto.randomUUID()}`, target_min: 3, target_max: 6 });

    expect(error).toBeNull();
  });
});

describe("Zuordnung zum Gymtavo-Typ und Verweis auf Gymtavo-Uebungen", () => {
  let katalogTyp: string;
  let katalogUebung: string;
  let modellA: string;
  let modellB: string;
  let uebungA: string;
  let uebungB: string;
  let doppelrolleEmail: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const kennung = crypto.randomUUID();

    const { data: modelle, error: modellError } = await admin
      .from("equipment_models")
      .insert([
        { studio_id: GYMTAVO, name: `Kabelzug ${kennung}`, load_step: 2.5 },
        { studio_id: studioA, name: `Kabelturm A ${kennung}`, load_step: 5 },
        { studio_id: studioB, name: `Kabelturm B ${kennung}`, load_step: 5 },
      ])
      .select("id");
    if (modellError) throw modellError;
    katalogTyp = modelle[0]!.id;
    modellA = modelle[1]!.id;
    modellB = modelle[2]!.id;

    const { data: uebungen, error: uebungError } = await admin
      .from("exercises")
      .insert([
        { studio_id: GYMTAVO, name: `Face Pull ${kennung}`, target_min: 12, target_max: 15 },
        { studio_id: studioA, name: `Eigene Uebung A ${kennung}`, target_min: 8, target_max: 12 },
        { studio_id: studioB, name: `Eigene Uebung B ${kennung}`, target_min: 8, target_max: 12 },
      ])
      .select("id");
    if (uebungError) throw uebungError;
    katalogUebung = uebungen[0]!.id;
    uebungA = uebungen[1]!.id;
    uebungB = uebungen[2]!.id;

    // Gymtavo-Owner und zugleich Trainer in Studio A: der Fall, in dem eine
    // Person beide Seiten lesen darf und die Regel trotzdem halten muss.
    doppelrolleEmail = uniqueEmail("katalog-doppelrolle");
    const doppelrolleId = await createTestUser(doppelrolleEmail);
    const { error: rollenError } = await admin.from("studio_memberships").insert([
      { studio_id: GYMTAVO, user_id: doppelrolleId, role: "owner" },
      { studio_id: studioA, user_id: doppelrolleId, role: "trainer" },
    ]);
    if (rollenError) throw rollenError;
  });

  it("ein Trainer ordnet sein Modell einem Gymtavo-Typ zu", async () => {
    const client = await userClient(trainerAEmail);

    const { data, error } = await client
      .from("equipment_models")
      .update({ catalog_model_id: katalogTyp })
      .eq("id", modellA)
      .select("catalog_model_id");

    expect(error).toBeNull();
    expect(data).toEqual([{ catalog_model_id: katalogTyp }]);
  });

  it("eine Zuordnung auf das Modell eines anderen Studios wird abgewiesen", async () => {
    const client = await userClient(trainerAEmail);

    const { error } = await client
      .from("equipment_models")
      .update({ catalog_model_id: modellB })
      .eq("id", modellA);

    expect(error?.message).toContain("gymtavo_zuordnung_ungueltig");
  });

  it("ein Gymtavo-Typ verweist nicht auf einen anderen", async () => {
    const admin = serviceClient();
    const { data: zweiterTyp, error: typError } = await admin
      .from("equipment_models")
      .insert({ studio_id: GYMTAVO, name: `Zweiter Typ ${crypto.randomUUID()}`, load_step: 1 })
      .select("id")
      .single();
    if (typError) throw typError;

    const { error } = await admin
      .from("equipment_models")
      .update({ catalog_model_id: katalogTyp })
      .eq("id", zweiterTyp.id);

    expect(error?.message).toContain("gymtavo_zuordnung_ungueltig");
  });

  it("ein Trainer haengt eine Gymtavo-Uebung an sein Geraet, und Mitglieder sehen sie", async () => {
    const trainer = await userClient(trainerAEmail);
    const { error } = await trainer
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: modellA, exercise_id: katalogUebung });
    expect(error).toBeNull();

    const mitglied = await userClient(memberAEmail);
    const { data } = await mitglied
      .from("equipment_model_exercises")
      .select("exercise_id")
      .eq("equipment_model_id", modellA);

    expect(data).toEqual([{ exercise_id: katalogUebung }]);
  });

  it("die Uebung eines dritten Studios laesst sich nicht anhaengen", async () => {
    const client = await userClient(trainerAEmail);

    const { error } = await client
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: modellA, exercise_id: uebungB });

    expect(error?.code).toBe("42501");
  });

  it("an einen Gymtavo-Typ kommt keine Studio-Uebung, auch nicht durch eine Doppelrolle", async () => {
    const client = await userClient(doppelrolleEmail);

    const { error } = await client
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: katalogTyp, exercise_id: uebungA });

    expect(error?.code).toBe("42501");
  });

  it("ein Studio ergaenzt ein eigenes Video zur Gymtavo-Uebung, das nur seine Mitglieder sehen", async () => {
    const trainer = await userClient(trainerAEmail);
    const { data: verknuepfung } = await trainer
      .from("equipment_model_exercises")
      .select("id")
      .eq("equipment_model_id", modellA)
      .eq("exercise_id", katalogUebung)
      .single();
    expect(verknuepfung).not.toBeNull();

    const { error } = await trainer.from("instruction_assets").insert({
      equipment_model_exercise_id: verknuepfung!.id,
      kind: "video",
      storage_path: `${studioA}/${verknuepfung!.id}/${crypto.randomUUID()}.mp4`,
      duration_s: 30,
    });
    expect(error).toBeNull();

    const fremd = await userClient(ohneStudioEmail);
    const { data } = await fremd
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", verknuepfung!.id);
    expect(data).toEqual([]);
  });
});
