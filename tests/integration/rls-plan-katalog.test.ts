import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";
import {
  GYMTAVO,
  aktiverKatalogPlan,
  erzeugeKatalogPlan,
  katalogEinheiten,
  katalogPlanParameter,
  legeMitgliedAn,
  legePlanStudiosAn,
  machineVon,
  nimmKatalogPlanAn,
  type PlanStudios,
} from "./helpers/plan-studio.js";
import { tauschVorgaben } from "@fitretro/domain";

// Trainingsplan aus dem Katalog (0066): der Plan gehoert dem Katalog-Studio,
// das Mitglied braucht dafuer keine Mitgliedschaft. Positionen nennen
// exerciseId + modelId eines Katalogmodells. Normale Studios sind fuer Plaene
// abgelehnt; die Session kann in jedem Studio laufen.
const admin = serviceClient();
let s: PlanStudios;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
});

/** Ersetzt in der ersten Position Felder (und entfernt solche mit undefined). */
function mitErsterPosition(aenderung: Record<string, unknown>) {
  const einheiten = structuredClone(katalogEinheiten(s)) as unknown as Array<{ positionen: Array<Record<string, unknown>> }>;
  const pos = einheiten[0]!.positionen[0]!;
  for (const [k, v] of Object.entries(aenderung)) {
    if (v === undefined) delete pos[k];
    else pos[k] = v;
  }
  return einheiten;
}

describe("Katalog-Plan (0066)", () => {
  it("legt Plan fuer das Katalog-Studio an und nimmt ihn an", async () => {
    const m = await legeMitgliedAn("katalog-ok", { studios: [] });
    const vorschlag = await erzeugeKatalogPlan(m, s);
    expect(vorschlag).toMatchObject({ studioId: GYMTAVO, version: 1, status: "vorschlag" });
    const aktiv = await nimmKatalogPlanAn(m, vorschlag.id);
    expect(aktiv).toMatchObject({ id: vorschlag.id, status: "aktiv" });
  });

  it("lehnt ein normales Studio ab", async () => {
    const m = await legeMitgliedAn("katalog-studio", { studios: [s.voll] });
    const { error } = await m.client.rpc("create_training_plan", katalogPlanParameter(s, { studioId: s.voll }));
    expect(error).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    const { data } = await admin.from("training_plans").select("id").eq("user_id", m.userId);
    expect(data).toEqual([]);
  });

  it("lehnt Position mit machineId oder fremdem Modell ab", async () => {
    const m = await legeMitgliedAn("katalog-pos", { studios: [s.voll] });
    const geraet = await machineVon(s.voll);
    const faelle: Record<string, unknown> = {
      "ohne modelId": mitErsterPosition({ modelId: undefined }),
      "nur machineId": mitErsterPosition({ modelId: undefined, machineId: geraet.id }),
      "Modell eines normalen Studios": mitErsterPosition({ modelId: s.studioModelle.voll }),
      "kein uuid": mitErsterPosition({ modelId: "kein-uuid" }),
      "Uebung fehlt am Modell": mitErsterPosition({ exerciseId: crypto.randomUUID() }),
    };
    for (const [name, einheiten] of Object.entries(faelle)) {
      const { error } = await m.client.rpc("create_training_plan", katalogPlanParameter(s, { einheiten }));
      expect(error, name).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    }
    const { data } = await admin.from("training_plans").select("id").eq("user_id", m.userId);
    expect(data).toEqual([]);
  });

  it("swap tauscht ohne Mitgliedschaft", async () => {
    const m = await legeMitgliedAn("katalog-swap", { studios: [] });
    const plan = await aktiverKatalogPlan(m, s);
    const stelle = plan.einheiten[0]!.positionen[0]!;
    // Zweites Katalogmodell mit derselben Uebung: das Modell der Position wechselt.
    const aufruf = (extra: Record<string, unknown>) =>
      m.client.rpc("swap_training_plan_position", {
        p_plan_id: plan.id,
        p_einheit_key: plan.einheiten[0]!.key,
        p_position_key: stelle.key,
        p_exercise_id: stelle.exerciseId,
        p_vorgaben: tauschVorgaben(plan.eingabe as never),
        ...extra,
      });
    const { data, error } = await aufruf({ p_model_id: s.katalogModellOhneDruck }).single();
    expect(error).toBeNull();
    const neu = data as { id: string; version: number; status: string; einheiten: Array<{ positionen: Array<{ modelId: string; machineId?: string }> }> };
    expect(neu).toMatchObject({ version: plan.version + 1, status: "aktiv" });
    expect(neu.einheiten[0]!.positionen[0]!.modelId).toBe(s.katalogModellOhneDruck);
    expect(neu.einheiten[0]!.positionen[0]).not.toHaveProperty("machineId");
    const { data: alt } = await admin.from("training_plans").select("status").eq("id", plan.id).single();
    expect(alt!.status).toBe("ersetzt");

    // Modell eines normalen Studios: abgelehnt.
    const fremd = await m.client.rpc("swap_training_plan_position", {
      p_plan_id: neu.id,
      p_einheit_key: plan.einheiten[0]!.key,
      p_position_key: stelle.key,
      p_exercise_id: stelle.exerciseId,
      p_model_id: s.studioModelle.voll,
      p_vorgaben: tauschVorgaben(plan.eingabe as never),
    });
    expect(fremd.error).toMatchObject({ code: "P0001", message: "plan_ungueltig" });

    // Die alte Fassung mit p_machine_id ist entfernt.
    const alte = await m.client.rpc("swap_training_plan_position", {
      p_plan_id: neu.id,
      p_einheit_key: plan.einheiten[0]!.key,
      p_position_key: stelle.key,
      p_exercise_id: stelle.exerciseId,
      p_machine_id: (await machineVon(s.voll)).id,
      p_vorgaben: tauschVorgaben(plan.eingabe as never),
    });
    expect(alte.error?.code).toBe("PGRST202");
  });

  it("record_session_plan verknuepft eine Studio-Session mit dem Katalogplan", async () => {
    const m = await legeMitgliedAn("katalog-session", { studios: [s.voll] });
    const plan = await aktiverKatalogPlan(m, s);
    const sessionId = crypto.randomUUID();
    const { error: e } = await admin.from("workout_sessions").insert({ id: sessionId, studio_id: s.voll, user_id: m.userId });
    if (e) throw e;
    const { error } = await m.client.rpc("record_session_plan", {
      p_session_id: sessionId,
      p_plan_id: plan.id,
      p_einheit_key: plan.einheiten[0]!.key,
      p_stand: 1,
      p_positionen: [{ key: plan.einheiten[0]!.positionen[0]!.key, status: "erledigt" }],
    });
    expect(error).toBeNull();
    const { data } = await admin.from("workout_sessions").select("plan_id, plan_stand").eq("id", sessionId).single();
    expect(data).toEqual({ plan_id: plan.id, plan_stand: 1 });
  });
});
