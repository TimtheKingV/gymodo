import { beforeAll, describe, expect, it } from "vitest";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let memberAEmail: string;
let memberA2Email: string;
let trainerAEmail: string;
let memberAId: string;
let memberA2Id: string;
let trainerAId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Ziele Studio A" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("ziel-member-a");
  memberA2Email = uniqueEmail("ziel-member-a2");
  trainerAEmail = uniqueEmail("ziel-trainer-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(memberA2Email);
  trainerAId = await createTestUser(trainerAEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: memberA2Id, role: "member" },
    { studio_id: studioA, user_id: trainerAId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;
});

/**
 * Ein frisches Mitglied ohne jedes Ziel -- fuer Tests, die auf genau einem
 * aktiven Ziel bestehen. Der Sortenraum ist mit zwei Werten so klein, dass
 * ein geteiltes Mitglied ueber mehrere Tests hinweg den Teilindex
 * "hoechstens ein aktives Ziel je Sorte" verletzen wuerde.
 */
async function frischesMitglied(prefix: string): Promise<{ userId: string; email: string }> {
  const admin = serviceClient();
  const email = uniqueEmail(prefix);
  const userId = await createTestUser(email);
  const { error } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: userId, role: "member" });
  if (error) throw error;
  return { userId, email };
}

describe("RLS auf member_goals", () => {
  it("positiv: ein Mitglied legt eine Zeile an und liest sie", async () => {
    const client = await userClient(memberAEmail);

    const { error: insertError } = await client
      .from("member_goals")
      .insert({ user_id: memberAId, kind: "weekly_days", target_value: 3 });
    expect(insertError).toBeNull();

    const { data } = await client
      .from("member_goals")
      .select("target_value")
      .eq("user_id", memberAId)
      .eq("kind", "weekly_days");
    expect(data).toEqual([{ target_value: 3 }]);
  });

  it("negativ: ein anderes Mitglied desselben Studios sieht die Zeile nicht", async () => {
    const admin = serviceClient();
    const { error: seedError } = await admin
      .from("member_goals")
      .insert({ user_id: memberAId, kind: "target_weight", target_value: 78 });
    if (seedError) throw seedError;

    const client = await userClient(memberA2Email);
    const { data } = await client
      .from("member_goals")
      .select("id")
      .eq("user_id", memberAId)
      .eq("kind", "target_weight");

    expect(data).toEqual([]);
  });

  it("Datenschutzgrenze: ein Trainer desselben Studios sieht nichts", async () => {
    // Wie body_measurements (0042): kein studio_id, keine Staff-Klausel,
    // keine Mitgliedschaftspruefung und keine Oeffnung ueber eine
    // SECURITY-DEFINER-Funktion, auch nicht als Summe. Koerperdaten und
    // Ziele bekommen keine Stelle, an der Personal sie aggregiert sieht.
    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("member_goals")
      .select("id")
      .eq("user_id", memberAId);

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("genau ein aktives Ziel je Sorte: ein zweiter direkter Insert scheitert am Index", async () => {
    const { email } = await frischesMitglied("ziel-index");
    const client = await userClient(email);
    const userId = (await client.auth.getUser()).data.user!.id;

    const { error: firstError } = await client
      .from("member_goals")
      .insert({ user_id: userId, kind: "target_weight", target_value: 80 });
    if (firstError) throw firstError;

    const { error: secondError } = await client
      .from("member_goals")
      .insert({ user_id: userId, kind: "target_weight", target_value: 79 });
    expect(secondError).not.toBeNull();
  });

  it("set_member_goal legt an, ein zweiter Aufruf schliesst das erste ab und legt ein neues an", async () => {
    const { email } = await frischesMitglied("ziel-rpc");
    const client = await userClient(email);

    const { data: erstes, error: ersterFehler } = await client.rpc("set_member_goal", {
      p_kind: "weekly_days",
      p_value: 2,
    });
    if (ersterFehler) throw ersterFehler;
    const ersteZeile = (Array.isArray(erstes) ? erstes[0] : erstes) as {
      id: string;
      status: string;
      target_value: number;
    };
    expect(ersteZeile.status).toBe("active");
    expect(ersteZeile.target_value).toBe(2);

    const { data: zweites, error: zweiterFehler } = await client.rpc("set_member_goal", {
      p_kind: "weekly_days",
      p_value: 4,
    });
    if (zweiterFehler) throw zweiterFehler;
    const zweiteZeile = (Array.isArray(zweites) ? zweites[0] : zweites) as {
      id: string;
      status: string;
      target_value: number;
    };
    expect(zweiteZeile.status).toBe("active");
    expect(zweiteZeile.target_value).toBe(4);
    expect(zweiteZeile.id).not.toBe(ersteZeile.id);

    const { data: alteZeile } = await client
      .from("member_goals")
      .select("status")
      .eq("id", ersteZeile.id)
      .single();
    expect(alteZeile?.status).toBe("dropped");
  });

  it("is_valid_goal_value weist 8 Tage und 78,25 kg ab", async () => {
    // Direkt ueber die Funktion, nicht ueber einen Insert: die Spalte ist
    // numeric(6,1) und wuerde 78,25 schon beim Einfuegen auf 78,3 runden --
    // die Nachkommastellen-Regel liesse sich so gar nicht treffen.
    const client = await userClient(memberAEmail);

    const { data: achtTage, error: achtTageFehler } = await client.rpc("is_valid_goal_value", {
      p_kind: "weekly_days",
      p_value: 8,
    });
    if (achtTageFehler) throw achtTageFehler;
    expect(achtTage).toBe(false);

    const { data: feinesGewicht, error: feinesGewichtFehler } = await client.rpc("is_valid_goal_value", {
      p_kind: "target_weight",
      p_value: 78.25,
    });
    if (feinesGewichtFehler) throw feinesGewichtFehler;
    expect(feinesGewicht).toBe(false);
  });

  it("delete scheitert -- es gibt keine Delete-Policy", async () => {
    const { email, userId } = await frischesMitglied("ziel-delete");
    const admin = serviceClient();
    const { data: seed, error: seedError } = await admin
      .from("member_goals")
      .insert({ user_id: userId, kind: "weekly_days", target_value: 5 })
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(email);
    const { error, count } = await client
      .from("member_goals")
      .delete({ count: "exact" })
      .eq("id", seed.id);

    // Keine Policy heisst: kein Fehler, aber auch keine geloeschte Zeile --
    // RLS filtert die Zeilenmenge des Statements auf leer.
    expect(error).toBeNull();
    expect(count).toBe(0);

    const { data: nachher } = await admin
      .from("member_goals")
      .select("id")
      .eq("id", seed.id);
    expect(nachher).toEqual([{ id: seed.id }]);
  });

  it("anonClient() bekommt vom RPC einen Fehler", async () => {
    const client = anonClient();

    const { error } = await client.rpc("set_member_goal", {
      p_kind: "weekly_days",
      p_value: 3,
    });

    expect(error).not.toBeNull();
  });
});
