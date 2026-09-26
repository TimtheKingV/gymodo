import { createHash } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";
import { anonClient, createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Mitarbeiter einladen per Link (0045, Testnotiz 25.09., #6 --
 * Moeglichkeit 2). Ein Token je Einladung, einmal gueltig, sieben Tage.
 */

let studioId: string;
let trainerEmail: string;
let ownerEmail: string;
let ownerId: string;

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error } = await admin
    .from("studios")
    .insert({ name: "Einladungs-Studio" })
    .select("id")
    .single();
  if (error) throw error;
  studioId = studio.id;

  trainerEmail = uniqueEmail("einladung-trainer");
  const trainerId = await createTestUser(trainerEmail);
  ownerEmail = uniqueEmail("einladung-inhaber");
  ownerId = await createTestUser(ownerEmail);
  const { error: mFehler } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: ownerId, role: "owner" },
  ]);
  if (mFehler) throw mFehler;
});

async function einladen(): Promise<string> {
  const client = await userClient(trainerEmail);
  const { data, error } = await client.rpc("create_staff_invite", { p_studio_id: studioId });
  expect(error).toBeNull();
  return data as string;
}

async function rolle(userId: string): Promise<string | undefined> {
  const { data } = await serviceClient()
    .from("studio_memberships")
    .select("role")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle();
  return data?.role;
}

describe("create_staff_invite", () => {
  it("liefert einen langen Token und speichert nur dessen Hash", async () => {
    const token = await einladen();
    expect(token).toMatch(/^[0-9a-f]{64}$/);

    const hash = createHash("sha256").update(token).digest("hex");
    const { data } = await serviceClient()
      .from("staff_invites")
      .select("token_hash")
      .eq("studio_id", studioId);
    const hashes = (data ?? []).map((zeile) => zeile.token_hash);
    expect(hashes).toContain(hash);
    expect(hashes).not.toContain(token);
  });

  it("ein Mitglied darf nicht einladen", async () => {
    const email = uniqueEmail("einladung-mitglied");
    const userId = await createTestUser(email);
    await serviceClient()
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });
    const client = await userClient(email);
    const { error } = await client.rpc("create_staff_invite", { p_studio_id: studioId });
    expect(error).not.toBeNull();
  });

  it("anon darf nicht einladen", async () => {
    const { error } = await anonClient().rpc("create_staff_invite", { p_studio_id: studioId });
    expect(error).not.toBeNull();
  });
});

describe("staff_invite_info", () => {
  it("nennt auch ohne Anmeldung das Studio", async () => {
    const token = await einladen();
    const { data, error } = await anonClient().rpc("staff_invite_info", { p_token: token });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data[0].studio_name).toBe("Einladungs-Studio");
  });

  it("liefert nichts fuer einen unbekannten Token", async () => {
    const { data, error } = await anonClient().rpc("staff_invite_info", { p_token: "0".repeat(64) });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });
});

describe("accept_staff_invite", () => {
  it("macht ein fremdes Konto zum Trainer, genau einmal", async () => {
    const token = await einladen();
    const email = uniqueEmail("einladung-neu");
    const userId = await createTestUser(email);
    const client = await userClient(email);

    const { data, error } = await client.rpc("accept_staff_invite", { p_token: token });
    expect(error).toBeNull();
    expect(data).toEqual([{ studio_id: studioId }]);
    expect(await rolle(userId)).toBe("trainer");

    const zweiter = uniqueEmail("einladung-zweiter");
    await createTestUser(zweiter);
    const nochmal = await (await userClient(zweiter)).rpc("accept_staff_invite", { p_token: token });
    expect(nochmal.data).toEqual([]);
    const info = await anonClient().rpc("staff_invite_info", { p_token: token });
    expect(info.data).toEqual([]);
  });

  it("stuft ein Mitglied zum Trainer hoch", async () => {
    const token = await einladen();
    const email = uniqueEmail("einladung-mitglied-hoch");
    const userId = await createTestUser(email);
    await serviceClient()
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });

    const client = await userClient(email);
    await client.rpc("accept_staff_invite", { p_token: token });
    expect(await rolle(userId)).toBe("trainer");
  });

  it("stuft den Inhaber nicht herab", async () => {
    const token = await einladen();
    const client = await userClient(ownerEmail);
    const { data } = await client.rpc("accept_staff_invite", { p_token: token });
    expect(data).toEqual([{ studio_id: studioId }]);
    expect(await rolle(ownerId)).toBe("owner");
  });

  it("eine abgelaufene Einladung gilt nicht", async () => {
    const token = await einladen();
    const hash = createHash("sha256").update(token).digest("hex");
    await serviceClient()
      .from("staff_invites")
      .update({ expires_at: new Date(Date.now() - 1000).toISOString() })
      .eq("token_hash", hash);

    const email = uniqueEmail("einladung-abgelaufen");
    const userId = await createTestUser(email);
    const { data } = await (await userClient(email)).rpc("accept_staff_invite", { p_token: token });
    expect(data).toEqual([]);
    expect(await rolle(userId)).toBeUndefined();
  });

  it("anon kann nicht annehmen", async () => {
    const token = await einladen();
    const { error } = await anonClient().rpc("accept_staff_invite", { p_token: token });
    expect(error).not.toBeNull();
  });
});

describe("revoke_staff_invite und Lesen", () => {
  it("eine zurueckgezogene Einladung gilt nicht mehr", async () => {
    const token = await einladen();
    const hash = createHash("sha256").update(token).digest("hex");
    const client = await userClient(trainerEmail);
    const { data: zeile } = await client
      .from("staff_invites")
      .select("id")
      .eq("token_hash", hash)
      .single();

    const { error } = await client.rpc("revoke_staff_invite", { p_invite_id: zeile!.id });
    expect(error).toBeNull();
    const info = await anonClient().rpc("staff_invite_info", { p_token: token });
    expect(info.data).toEqual([]);
  });

  it("ein Mitglied sieht keine Einladungen und kann keine zurueckziehen", async () => {
    await einladen();
    const email = uniqueEmail("einladung-neugierig");
    const userId = await createTestUser(email);
    await serviceClient()
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });
    const client = await userClient(email);

    const { data } = await client.from("staff_invites").select("id").eq("studio_id", studioId);
    expect(data).toEqual([]);

    const { data: eine } = await serviceClient()
      .from("staff_invites")
      .select("id")
      .eq("studio_id", studioId)
      .limit(1)
      .single();
    const { error } = await client.rpc("revoke_staff_invite", { p_invite_id: eine!.id });
    expect(error).not.toBeNull();
  });

  it("niemand schreibt direkt in die Tabelle", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("staff_invites")
      .insert({ studio_id: studioId, token_hash: "x".repeat(64) });
    expect(error).not.toBeNull();
  });
});
