import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Studio-Einstellungen, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 7: `studios` hatte bis 0032 nur `studios_select` -- Speichern war
 * nicht moeglich. Diese Datei haelt fest, wer speichern darf und was dabei
 * unerreichbar bleibt.
 */

let studioId: string;
let fremdStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let fremdTrainerEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Einstellungen-Studio" }, { name: "Fremdes Einstellungen-Studio" }])
    .select("id");
  if (studioError) throw studioError;
  studioId = studios[0]!.id;
  fremdStudioId = studios[1]!.id;

  trainerEmail = uniqueEmail("einst-trainer");
  mitgliedEmail = uniqueEmail("einst-mitglied");
  fremdTrainerEmail = uniqueEmail("einst-fremd-trainer");

  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: fremdStudioId, user_id: fremdTrainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("Stornofrist als Spalte am Studio", () => {
  it("jedes Studio hat von Anfang an eine Frist -- kein NULL, das die Oberflaeche deuten muesste", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("studios")
      .select("cancellation_deadline_hours")
      .eq("id", studioId)
      .single();

    expect(error).toBeNull();
    expect(data!.cancellation_deadline_hours).toBe(2);
  });

  it("eine negative Frist ist keine Frist", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("studios")
      .update({ cancellation_deadline_hours: -1 })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("23514");
  });

  it("mehr als eine Woche Vorlauf ist ein Tippfehler, keine Studioregel", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("studios")
      .update({ cancellation_deadline_hours: 169 })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("23514");
  });
});

describe("studios_update_staff", () => {
  it("positiv: ein Trainer speichert Name, Zeitzone und Stornofrist", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client
      .from("studios")
      .update({
        name: "Kraftwerk Nord",
        timezone: "Europe/Vienna",
        cancellation_deadline_hours: 6,
      })
      .eq("id", studioId)
      .select("name, timezone, cancellation_deadline_hours");

    expect(error).toBeNull();
    expect(data).toEqual([
      { name: "Kraftwerk Nord", timezone: "Europe/Vienna", cancellation_deadline_hours: 6 },
    ]);
  });

  it("negativ: ein Mitglied speichert nicht", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client
      .from("studios")
      .update({ name: "Von einem Mitglied umbenannt" })
      .eq("id", studioId)
      .select("id");

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("cross-tenant: der Trainer eines anderen Studios speichert nicht", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data, error } = await client
      .from("studios")
      .update({ name: "Von aussen umbenannt" })
      .eq("id", studioId)
      .select("id");

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ein leerer Name bleibt abgelehnt -- die Pruefung aus 0001 gilt weiter", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ name: "   " })
      .eq("id", studioId);

    expect(error).not.toBeNull();
  });
});

describe("Der Beitrittscode bleibt den Funktionen aus 0030 vorbehalten", () => {
  it("ein Trainer setzt join_code nicht per UPDATE", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ join_code: "AAAAAAAA" })
      .eq("id", studioId);

    // Spaltenrecht, nicht Policy: die Ablehnung kommt als Fehler, nicht als
    // leere Treffermenge. Sonst waere die Retry-Schleife gegen
    // studios_join_code_unique in regenerate_studio_join_code umgehbar.
    expect(error).not.toBeNull();
    expect(error!.code).toBe("42501");
  });

  it("ein Trainer sperrt den Code nicht per UPDATE", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ join_code_active: false })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("42501");
  });

  it("set_studio_join_code_active bleibt der Weg -- und er wirkt", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: false,
    });
    expect(error).toBeNull();

    const { data } = await client
      .from("studios")
      .select("join_code_active")
      .eq("id", studioId)
      .single();
    expect(data!.join_code_active).toBe(false);

    await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: true,
    });
  });
});
