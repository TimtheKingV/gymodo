import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let emailA: string;
let emailB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Studio A" }, { name: "Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  emailA = uniqueEmail("a");
  emailB = uniqueEmail("b");
  const userA = await createTestUser(emailA);
  const userB = await createTestUser(emailB);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: userA, role: "member" },
      { studio_id: studioB, user_id: userB, role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

describe("RLS auf studios", () => {
  it("positiv: Nutzer A sieht sein eigenes Studio", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("studios").select("id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.id)).toEqual([studioA]);
  });

  it("cross-tenant: Nutzer A sieht Studio B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client.from("studios").select("id").eq("id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann kein Studio anlegen", async () => {
    const client = await userClient(emailA);
    const { error } = await client.from("studios").insert({ name: "Schwarz" });
    expect(error).not.toBeNull();
  });
});

describe("RLS auf studio_memberships", () => {
  it("positiv: Nutzer A sieht seine eigene Mitgliedschaft", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client
      .from("studio_memberships")
      .select("studio_id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.studio_id)).toEqual([studioA]);
  });

  it("cross-tenant: Nutzer A sieht die Mitgliedschaft von B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("studio_memberships")
      .select("studio_id")
      .eq("studio_id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann sich nicht selbst in Studio B eintragen", async () => {
    const client = await userClient(emailA);
    const { data: me } = await client.auth.getUser();
    const { error } = await client.from("studio_memberships").insert({
      studio_id: studioB,
      user_id: me.user?.id,
      role: "member",
    });
    expect(error).not.toBeNull();
  });
});
