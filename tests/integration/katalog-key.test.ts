import { afterAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const admin = serviceClient();
const angelegt: { tabelle: "equipment_models" | "exercises"; id: string }[] = [];
const studios: string[] = [];

function schluessel(rest: string): string {
  return `t_${crypto.randomUUID().slice(0, 8)}_${rest}`;
}

async function modell(studioId: string, catalogKey: string | null) {
  const ergebnis = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Schluesseltest", load_step: 1, catalog_key: catalogKey })
    .select("id")
    .maybeSingle();
  if (ergebnis.data) angelegt.push({ tabelle: "equipment_models", id: ergebnis.data.id });
  return ergebnis;
}

async function uebung(studioId: string, catalogKey: string | null) {
  const ergebnis = await admin
    .from("exercises")
    .insert({ studio_id: studioId, name: "Schluesseltest", target_min: 8, target_max: 12, catalog_key: catalogKey })
    .select("id")
    .maybeSingle();
  if (ergebnis.data) angelegt.push({ tabelle: "exercises", id: ergebnis.data.id });
  return ergebnis;
}

afterAll(async () => {
  for (const { tabelle, id } of angelegt) await admin.from(tabelle).delete().eq("id", id);
  if (studios.length > 0) await admin.from("studios").delete().in("id", studios);
});

describe("catalog_key", () => {
  it("ist je Studio eindeutig", async () => {
    const key = schluessel("doppelt");
    expect((await modell(GYMTAVO, key)).error).toBeNull();
    expect((await modell(GYMTAVO, key)).error?.code).toBe("23505");
    expect((await uebung(GYMTAVO, key)).error).toBeNull();
    expect((await uebung(GYMTAVO, key)).error?.code).toBe("23505");
  });

  it("erlaubt denselben Schluessel in einem anderen Studio", async () => {
    const { data, error } = await admin.from("studios").insert({ name: "Schluessel Studio" }).select("id").single();
    if (error) throw error;
    studios.push(data.id);
    const key = schluessel("anderes_studio");

    expect((await modell(GYMTAVO, key)).error).toBeNull();
    expect((await modell(data.id, key)).error).toBeNull();
  });

  it("erlaubt beliebig viele Zeilen ohne Schluessel", async () => {
    expect((await modell(GYMTAVO, null)).error).toBeNull();
    expect((await modell(GYMTAVO, null)).error).toBeNull();
  });

  it("lehnt einen Schluessel ausserhalb des Musters ab", async () => {
    expect((await modell(GYMTAVO, "Brust-Presse")).error?.code).toBe("23514");
    expect((await uebung(GYMTAVO, "bank drücken")).error?.code).toBe("23514");
  });
});
