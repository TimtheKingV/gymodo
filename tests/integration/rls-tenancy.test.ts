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
let userIdA: string;
let userIdB: string;

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
  userIdA = await createTestUser(emailA);
  userIdB = await createTestUser(emailB);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: userIdA, role: "member" },
      { studio_id: studioB, user_id: userIdB, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  // `profiles` wird nicht automatisch bei Signup befuellt (kein Trigger in
  // dieser Migration) - fuer die RLS-Tests auf `profiles` legt der
  // Service-Client die Zeilen explizit an.
  const { error: profileError } = await admin.from("profiles").insert([
    { id: userIdA, display_name: "Nutzer A" },
    { id: userIdB, display_name: "Nutzer B" },
  ]);
  if (profileError) throw profileError;
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

describe("RLS auf profiles", () => {
  it("positiv: Nutzer A sieht sein eigenes Profil", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("profiles").select("id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.id)).toEqual([userIdA]);
  });

  it("cross-tenant: Nutzer A sieht das Profil von Nutzer B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("profiles")
      .select("id")
      .eq("id", userIdB);
    expect(data).toEqual([]);
  });

  it("positiv: Nutzer B sieht ebenfalls nur sein eigenes Profil", async () => {
    const client = await userClient(emailB);
    const { data, error } = await client.from("profiles").select("id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.id)).toEqual([userIdB]);
  });

  it("positiv: Nutzer A kann sein eigenes Profil aktualisieren", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client
      .from("profiles")
      .update({ display_name: "Nutzer A aktualisiert" })
      .eq("id", userIdA)
      .select("display_name");
    expect(error).toBeNull();
    expect(data).toEqual([{ display_name: "Nutzer A aktualisiert" }]);
  });

  it("negativ/cross-tenant: Nutzer A kann das Profil von Nutzer B nicht aktualisieren", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client
      .from("profiles")
      .update({ display_name: "Uebernommen von A" })
      .eq("id", userIdB)
      .select("display_name");
    // Die "using"-Klausel von profiles_update_own filtert die Zeile von B
    // vor dem Update weg - kein Fehler, aber null betroffene Zeilen.
    expect(error).toBeNull();
    expect(data).toEqual([]);

    const check = await serviceClient()
      .from("profiles")
      .select("display_name")
      .eq("id", userIdB)
      .single();
    expect(check.data?.display_name).toBe("Nutzer B");
  });
});
