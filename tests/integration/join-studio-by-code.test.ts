import { beforeAll, describe, expect, it } from "vitest";
import { anonClient, createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let joinCode: string;
let trainerEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitrittscode-Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;
  joinCode = studio.join_code;

  trainerEmail = uniqueEmail("code-trainer");
  trainerId = await createTestUser(trainerEmail);
  const { error: mitgliedError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainerId, role: "trainer" });
  if (mitgliedError) throw mitgliedError;
});

describe("join_studio_by_code", () => {
  it("macht ein fremdes Konto durch den Code zum Mitglied", async () => {
    const email = uniqueEmail("code-beitritt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_code", { p_code: joinCode });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].joined).toBe(true);
  });

  it("ist beim zweiten Beitritt wirkungslos und meldet joined = false", async () => {
    const email = uniqueEmail("code-doppelt");
    await createTestUser(email);
    const client = await userClient(email);
    await client.rpc("join_studio_by_code", { p_code: joinCode });
    const { data, error } = await client.rpc("join_studio_by_code", { p_code: joinCode });
    expect(error).toBeNull();
    expect(data[0].joined).toBe(false);
  });

  it("ignoriert Gross-/Kleinschreibung und umgebende Leerzeichen", async () => {
    const email = uniqueEmail("code-schreibweise");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_code", {
      p_code: `  ${joinCode.toLowerCase()}  `,
    });
    expect(error).toBeNull();
    expect(data[0].joined).toBe(true);
  });

  it("stuft einen Trainer nicht auf member zurueck", async () => {
    const client = await userClient(trainerEmail);
    await client.rpc("join_studio_by_code", { p_code: joinCode });

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", trainerId)
      .single();
    expect(data?.role).toBe("trainer");
  });

  it("liefert nichts fuer einen gesperrten Code", async () => {
    const admin = serviceClient();
    const { data: gesperrt } = await admin
      .from("studios")
      .insert({ name: "Gesperrtes Studio", join_code_active: false })
      .select("id, join_code")
      .single();

    const email = uniqueEmail("code-gesperrt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_code", {
      p_code: gesperrt!.join_code,
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("liefert nichts fuer einen unbekannten Code", async () => {
    const email = uniqueEmail("code-unbekannt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_code", { p_code: "UNBEKANNT" });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ist fuer anon nicht aufrufbar", async () => {
    const { error } = await anonClient().rpc("join_studio_by_code", { p_code: joinCode });
    expect(error).not.toBeNull();
  });
});

describe("regenerate_studio_join_code", () => {
  it("ein Trainer erneuert den Code, und der alte Code wirkt danach nicht mehr", async () => {
    const client = await userClient(trainerEmail);
    const { data: neuerCode, error } = await client.rpc("regenerate_studio_join_code", {
      p_studio_id: studioId,
    });
    expect(error).toBeNull();
    expect(neuerCode).not.toBe(joinCode);

    const alterVersuch = await client.rpc("join_studio_by_code", { p_code: joinCode });
    expect(alterVersuch.data).toEqual([]);

    const email = uniqueEmail("code-erneuert");
    await createTestUser(email);
    const neuerNutzer = await userClient(email);
    const { data: beitritt } = await neuerNutzer.rpc("join_studio_by_code", {
      p_code: neuerCode,
    });
    expect(beitritt[0].joined).toBe(true);

    joinCode = neuerCode as string; // fuer die folgenden Tests dieser Datei
  });

  it("ein Mitglied kann den Code nicht erneuern", async () => {
    const email = uniqueEmail("code-kein-staff");
    const userId = await createTestUser(email);
    const admin = serviceClient();
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });

    const client = await userClient(email);
    const { error } = await client.rpc("regenerate_studio_join_code", { p_studio_id: studioId });
    expect(error).not.toBeNull();
  });
});

describe("set_studio_join_code_active", () => {
  it("ein Trainer sperrt den Code, danach ist er wirkungslos", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: false,
    });
    expect(error).toBeNull();

    const email = uniqueEmail("code-nach-sperre");
    await createTestUser(email);
    const versuch = await userClient(email);
    const { data } = await versuch.rpc("join_studio_by_code", { p_code: joinCode });
    expect(data).toEqual([]);

    await client.rpc("set_studio_join_code_active", { p_studio_id: studioId, p_active: true });
  });

  it("ein Mitglied kann den Code nicht sperren", async () => {
    const email = uniqueEmail("code-sperr-kein-staff");
    const userId = await createTestUser(email);
    const admin = serviceClient();
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });

    const client = await userClient(email);
    const { error } = await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: false,
    });
    expect(error).not.toBeNull();
  });
});
