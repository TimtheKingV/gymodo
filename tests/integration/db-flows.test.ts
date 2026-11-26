import { beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let flowA: string;
let flowB: string;
let userA: string;
let clientA: SupabaseClient;
let clientB: SupabaseClient;

async function neuesStudio(name: string): Promise<string> {
  const { data, error } = await serviceClient()
    .from("studios")
    .insert({ name, timezone: "Europe/Berlin" })
    .select("id")
    .single();
  if (error) throw error;
  return data!.id;
}

async function neuerNutzer(studioId: string, prefix: string): Promise<{ id: string; client: SupabaseClient }> {
  const email = uniqueEmail(prefix);
  const id = await createTestUser(email);
  const { error } = await serviceClient()
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: id, role: "member" });
  if (error) throw error;
  return { id, client: await userClient(email) };
}

async function neuerFlow(studioId: string, key: string): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin
    .from("flows")
    .insert({ studio_id: studioId, key, titel: `Flow ${key}` })
    .select("id")
    .single();
  if (error) throw error;
  const { error: e2 } = await admin
    .from("flow_steps")
    .insert([
      { flow_id: data!.id, position: 1, name: "Aufwaermen", work_s: 30, rest_s: 10, is_warmup: true },
      { flow_id: data!.id, position: 2, name: "Kniebeuge", work_s: 40, rest_s: 20, is_warmup: false },
    ]);
  if (e2) throw e2;
  return data!.id;
}

beforeAll(async () => {
  studioA = await neuesStudio("Flows A");
  studioB = await neuesStudio("Flows B");
  flowA = await neuerFlow(studioA, "flow-a");
  flowB = await neuerFlow(studioB, "flow-b");
  const a = await neuerNutzer(studioA, "flows-a");
  const b = await neuerNutzer(studioB, "flows-b");
  userA = a.id;
  clientA = a.client;
  clientB = b.client;
});

const lauf = (over: Record<string, unknown> = {}) => ({
  id: crypto.randomUUID(),
  flow_id: flowA,
  user_id: userA,
  studio_id: studioA,
  started_at: "2026-11-26T10:00:00Z",
  ended_at: "2026-11-26T10:10:00Z",
  last_step: 2,
  outcome: "finished",
  ...over,
});

describe("flows RLS", () => {
  it("(a) Mitglied sieht nur Flows und Schritte des eigenen Studios", async () => {
    const f = await clientA.from("flows").select("id").eq("id", flowA);
    expect(f.data).toHaveLength(1);
    const s = await clientA.from("flow_steps").select("position").eq("flow_id", flowA);
    expect(s.data).toHaveLength(2);
    const fremd = await clientB.from("flows").select("id").eq("id", flowA);
    expect(fremd.data).toHaveLength(0);
    const fremdS = await clientB.from("flow_steps").select("position").eq("flow_id", flowA);
    expect(fremdS.data).toHaveLength(0);
  });

  it("(b) authenticated kann flows und flow_steps weder einfuegen noch aendern", async () => {
    const ins = await clientA.from("flows").insert({ studio_id: studioA, key: "x", titel: "x" });
    expect(ins.error).not.toBeNull();
    const upd = await clientA.from("flows").update({ titel: "neu" }).eq("id", flowA);
    expect(upd.error).not.toBeNull();
    const insS = await clientA
      .from("flow_steps")
      .insert({ flow_id: flowA, position: 9, name: "x", work_s: 10, rest_s: 0 });
    expect(insS.error).not.toBeNull();
    const updS = await clientA.from("flow_steps").update({ name: "neu" }).eq("flow_id", flowA);
    expect(updS.error).not.toBeNull();
  });

  it("(c) eigener Lauf, doppeltes Upsert bleibt eine Zeile", async () => {
    const row = lauf();
    const r1 = await clientA.from("flow_runs").upsert(row, { onConflict: "id", ignoreDuplicates: true });
    expect(r1.error).toBeNull();
    const r2 = await clientA.from("flow_runs").upsert(row, { onConflict: "id", ignoreDuplicates: true });
    expect(r2.error).toBeNull();
    const sel = await clientA.from("flow_runs").select("id").eq("id", row.id);
    expect(sel.data).toHaveLength(1);
  });

  it("(d) fremder user_id oder fremdes Studio scheitert", async () => {
    const fremderUser = await clientA.from("flow_runs").insert(lauf({ user_id: crypto.randomUUID() }));
    expect(fremderUser.error).not.toBeNull();
    const fremdesStudio = await clientA.from("flow_runs").insert(lauf({ studio_id: studioB, flow_id: flowB }));
    expect(fremdesStudio.error).not.toBeNull();
    const flowAndererStudios = await clientA.from("flow_runs").insert(lauf({ flow_id: flowB }));
    expect(flowAndererStudios.error).not.toBeNull();
  });

  it("(e) work_s = 0 und position = 0 scheitern am Check", async () => {
    const admin = serviceClient();
    const w = await admin
      .from("flow_steps")
      .insert({ flow_id: flowA, position: 5, name: "x", work_s: 0, rest_s: 0 });
    expect(w.error).not.toBeNull();
    const p = await admin
      .from("flow_steps")
      .insert({ flow_id: flowA, position: 0, name: "x", work_s: 10, rest_s: 0 });
    expect(p.error).not.toBeNull();
  });
});
