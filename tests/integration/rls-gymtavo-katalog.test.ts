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
