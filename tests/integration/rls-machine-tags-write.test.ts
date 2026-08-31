import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Schreibpfad auf machine_tags -- der offene Punkt 2 aus dem Plan.
// Bis 0016 hatte die Tabelle nur eine Select-Policy: Tags liessen sich weder
// anlegen noch zuweisen noch sperren, ohne direkt an der Datenbank zu sitzen.

let studioA: string;
let studioB: string;
let trainerA: string;
let memberA: string;
let trainerB: string;
let machineA: string;
let machineA2: string;
let machineB: string;

/** Legt einen Tag per Service-Role an und liefert seine id. */
async function seedTag(
  studioId: string,
  machineId: string | null,
  status: "unassigned" | "active" | "revoked",
): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin
    .from("machine_tags")
    .insert({
      studio_id: studioId,
      machine_id: machineId,
      token_hash: hashTagToken(createTagToken()),
      status,
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Tagschreib-Studio A" }, { name: "Tagschreib-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("tagw-trainer-a");
  memberA = uniqueEmail("tagw-member-a");
  trainerB = uniqueEmail("tagw-trainer-b");

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
      { studio_id: studioA, user_id: await createTestUser(memberA), role: "member" },
      { studio_id: studioB, user_id: await createTestUser(trainerB), role: "trainer" },
    ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Tagschreib-Modell A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Tagschreib-Modell B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "Geraet A1" },
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "Geraet A2" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "Geraet B1" },
    ])
    .select("id, label");
  if (machineError) throw machineError;
  machineA = machines.find((m) => m.label === "Geraet A1")!.id;
  machineA2 = machines.find((m) => m.label === "Geraet A2")!.id;
  machineB = machines.find((m) => m.label === "Geraet B1")!.id;
});

describe("machine_tags: Insert-Policy", () => {
  it("positiv: der Trainer legt einen unassigned Tag im eigenen Studio an", async () => {
    const client = await userClient(trainerA);
    const token = createTagToken();
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("id, status, machine_id")
      .eq("token_hash", hashTagToken(token));
    expect(data).toHaveLength(1);
    expect(data?.[0]?.status).toBe("unassigned");
  });

  it("positiv: anlegen und zuweisen in einer Anweisung -- der Check-Constraint aus 0008 laesst nichts anderes zu", async () => {
    const client = await userClient(trainerA);
    const token = createTagToken();
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      machine_id: machineA,
      token_hash: hashTagToken(token),
      status: "active",
    });
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("machine_id")
      .eq("token_hash", hashTagToken(token));
    expect(data?.[0]?.machine_id).toBe(machineA);
  });

  it("negativ: ein einfaches Mitglied legt keinen Tag an", async () => {
    const client = await userClient(memberA);
    const token = createTagToken();
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(data).toEqual([]);
  });

  it("cross-tenant: der Trainer aus A legt keinen Tag fuer Studio B an", async () => {
    const client = await userClient(trainerA);
    const token = createTagToken();
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioB,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(data).toEqual([]);
  });

  it("cross-tenant: ein Tag im eigenen Studio darf nicht auf ein fremdes Geraet zeigen", async () => {
    const client = await userClient(trainerA);
    const token = createTagToken();
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      machine_id: machineB,
      token_hash: hashTagToken(token),
      status: "active",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(data).toEqual([]);
  });

  it("Nebenlaeufigkeit: derselbe Token laesst sich kein zweites Mal vergeben", async () => {
    const client = await userClient(trainerA);
    const token = createTagToken();

    const first = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(first.error).toBeNull();

    const second = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(second.error).not.toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(data).toHaveLength(1);
  });
});

describe("machine_tags: Update-Policy", () => {
  it("positiv: der Trainer weist einem unassigned Tag ein Geraet zu und aktiviert ihn", async () => {
    const tagId = await seedTag(studioA, null, "unassigned");
    const client = await userClient(trainerA);

    const { data, error } = await client
      .from("machine_tags")
      .update({ machine_id: machineA, status: "active" })
      .eq("id", tagId)
      .select("id, status, machine_id");
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data?.[0]?.status).toBe("active");
    expect(data?.[0]?.machine_id).toBe(machineA);
  });

  it("positiv: der Trainer sperrt einen aktiven Tag", async () => {
    const tagId = await seedTag(studioA, machineA, "active");
    const client = await userClient(trainerA);

    const { data, error } = await client
      .from("machine_tags")
      .update({ status: "revoked", revoked_at: new Date().toISOString() })
      .eq("id", tagId)
      .select("id, status");
    expect(error).toBeNull();
    expect(data?.[0]?.status).toBe("revoked");
  });

  it("positiv: ein Tag laesst sich auf ein anderes Geraet desselben Studios umhaengen", async () => {
    const tagId = await seedTag(studioA, machineA, "active");
    const client = await userClient(trainerA);

    const { data, error } = await client
      .from("machine_tags")
      .update({ machine_id: machineA2 })
      .eq("id", tagId)
      .select("machine_id");
    expect(error).toBeNull();
    expect(data?.[0]?.machine_id).toBe(machineA2);
  });

  it("negativ: ein einfaches Mitglied sperrt keinen Tag", async () => {
    const tagId = await seedTag(studioA, machineA, "active");
    const client = await userClient(memberA);

    const { data } = await client
      .from("machine_tags")
      .update({ status: "revoked" })
      .eq("id", tagId)
      .select("id");
    expect(data).toEqual([]);

    const admin = serviceClient();
    const { data: row } = await admin
      .from("machine_tags")
      .select("status")
      .eq("id", tagId)
      .single();
    expect(row?.status).toBe("active");
  });

  it("cross-tenant: der Trainer aus A aendert keinen Tag aus Studio B", async () => {
    const tagId = await seedTag(studioB, machineB, "active");
    const client = await userClient(trainerA);

    const { data } = await client
      .from("machine_tags")
      .update({ status: "revoked" })
      .eq("id", tagId)
      .select("id");
    expect(data).toEqual([]);

    const admin = serviceClient();
    const { data: row } = await admin
      .from("machine_tags")
      .select("status")
      .eq("id", tagId)
      .single();
    expect(row?.status).toBe("active");
  });

  it("cross-tenant: einem eigenen Tag laesst sich kein fremdes Geraet zuweisen", async () => {
    const tagId = await seedTag(studioA, null, "unassigned");
    const client = await userClient(trainerA);

    const { error } = await client
      .from("machine_tags")
      .update({ machine_id: machineB, status: "active" })
      .eq("id", tagId);
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: row } = await admin
      .from("machine_tags")
      .select("machine_id, status")
      .eq("id", tagId)
      .single();
    expect(row?.machine_id).toBeNull();
    expect(row?.status).toBe("unassigned");
  });

  it("cross-tenant: ein eigener Tag laesst sich nicht in ein fremdes Studio umhaengen", async () => {
    const tagId = await seedTag(studioA, null, "unassigned");
    const client = await userClient(trainerA);

    const { error } = await client
      .from("machine_tags")
      .update({ studio_id: studioB })
      .eq("id", tagId);
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: row } = await admin
      .from("machine_tags")
      .select("studio_id")
      .eq("id", tagId)
      .single();
    expect(row?.studio_id).toBe(studioA);
  });
});

describe("machine_tags: kein Loeschpfad", () => {
  it("negativ: auch der Trainer loescht keinen Tag -- die Zuordnungshistorie bleibt", async () => {
    const tagId = await seedTag(studioA, machineA, "active");
    const client = await userClient(trainerA);

    const { data } = await client
      .from("machine_tags")
      .delete()
      .eq("id", tagId)
      .select("id");
    expect(data).toEqual([]);

    const admin = serviceClient();
    const { data: row } = await admin
      .from("machine_tags")
      .select("id")
      .eq("id", tagId);
    expect(row).toHaveLength(1);
  });
});
