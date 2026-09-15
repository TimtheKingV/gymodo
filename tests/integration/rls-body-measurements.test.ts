import { beforeAll, describe, expect, it } from "vitest";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberA2Email: string;
let trainerAEmail: string;
let memberBEmail: string;
let memberAId: string;
let memberA2Id: string;
let memberBId: string;
let trainerAId: string;
let membershipAId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Gewicht Studio A" }, { name: "Gewicht Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("gewicht-member-a");
  memberA2Email = uniqueEmail("gewicht-member-a2");
  trainerAEmail = uniqueEmail("gewicht-trainer-a");
  memberBEmail = uniqueEmail("gewicht-member-b");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(memberA2Email);
  memberBId = await createTestUser(memberBEmail);
  trainerAId = await createTestUser(trainerAEmail);

  const { data: memberships, error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
      { studio_id: studioB, user_id: memberBId, role: "member" },
      { studio_id: studioA, user_id: trainerAId, role: "trainer" },
    ])
    .select("id, user_id");
  if (membershipError) throw membershipError;
  membershipAId = memberships!.find((row) => row.user_id === memberAId)!.id;
});

describe("RLS auf body_measurements", () => {
  it("positiv: ein Mitglied legt eine Zeile an und liest sie", async () => {
    const client = await userClient(memberAEmail);

    const { error: insertError } = await client
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-01", weight_kg: 82.5 });
    expect(insertError).toBeNull();

    const { data } = await client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-01");
    expect(data).toEqual([{ weight_kg: 82.5 }]);
  });

  it("negativ: ein anderes Mitglied desselben Studios sieht die Zeile nicht", async () => {
    const admin = serviceClient();
    const { error: seedError } = await admin
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-02", weight_kg: 81.0 });
    if (seedError) throw seedError;

    const client = await userClient(memberA2Email);
    const { data } = await client
      .from("body_measurements")
      .select("id")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-02");

    expect(data).toEqual([]);
  });

  it("Datenschutzgrenze: ein Trainer desselben Studios sieht die Zeile nicht -- das ist der Kern dieses Bauabschnitts", async () => {
    // Migration 0042: keine Staff-Klausel, keine Mitgliedschaftspruefung
    // und keine Oeffnung ueber eine SECURITY-DEFINER-Funktion, auch nicht
    // als Summe. studio_overview (0034) bleibt die einzige Stelle, an der
    // Personal Trainingsdaten aggregiert sieht -- Koerperdaten bekommen
    // keine solche Stelle.
    const admin = serviceClient();
    const { error: seedError } = await admin
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-03", weight_kg: 80.5 });
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("body_measurements")
      .select("id")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-03");

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("negativ: ein Mitglied eines fremden Studios sieht die Zeile nicht", async () => {
    const admin = serviceClient();
    const { error: seedError } = await admin
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-04", weight_kg: 80.0 });
    if (seedError) throw seedError;

    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("body_measurements")
      .select("id")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-04");

    expect(data).toEqual([]);
  });

  it("negativ: eine Zeile mit fremder user_id kann nicht angelegt werden", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("body_measurements")
      .insert({ user_id: memberA2Id, measured_on: "2026-09-05", weight_kg: 80.0 });

    expect(error).not.toBeNull();
  });

  it("negativ: ein anderes Mitglied desselben Studios kann meine Zeile weder aendern noch loeschen", async () => {
    // Eigene zwei Mitglieder statt memberA/memberA2: der Austritt-Test
    // loescht memberAs Mitgliedschaft, und "desselben Studios" soll hier
    // unabhaengig von der Reihenfolge gelten.
    const admin = serviceClient();
    const eigeneEmail = uniqueEmail("gewicht-eigen");
    const andereEmail = uniqueEmail("gewicht-anderes");
    const eigeneId = await createTestUser(eigeneEmail);
    const andereId = await createTestUser(andereEmail);
    const { error: membershipError } = await admin.from("studio_memberships").insert([
      { studio_id: studioA, user_id: eigeneId, role: "member" },
      { studio_id: studioA, user_id: andereId, role: "member" },
    ]);
    if (membershipError) throw membershipError;

    const { data: seed, error: seedError } = await admin
      .from("body_measurements")
      .insert({ user_id: eigeneId, measured_on: "2026-09-10", weight_kg: 77.5 })
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(andereEmail);
    const { error: updateError, count: updateCount } = await client
      .from("body_measurements")
      .update({ weight_kg: 60.0 }, { count: "exact" })
      .eq("id", seed.id);
    // RLS filtert die Zeilenmenge des Statements auf leer -- kein Fehler,
    // aber auch keine getroffene Zeile.
    expect(updateError).toBeNull();
    expect(updateCount).toBe(0);

    const { error: deleteError, count: deleteCount } = await client
      .from("body_measurements")
      .delete({ count: "exact" })
      .eq("id", seed.id);
    expect(deleteError).toBeNull();
    expect(deleteCount).toBe(0);

    const { data: nachher } = await admin
      .from("body_measurements")
      .select("user_id, measured_on, weight_kg")
      .eq("id", seed.id);
    expect(nachher).toEqual([{ user_id: eigeneId, measured_on: "2026-09-10", weight_kg: 77.5 }]);
  });

  it("ein Wert je Tag: ein zweiter Insert scheitert, ein Upsert ersetzt", async () => {
    const client = await userClient(memberAEmail);

    const { error: firstError } = await client
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-06", weight_kg: 80.0 });
    if (firstError) throw firstError;

    const { error: secondInsertError } = await client
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-06", weight_kg: 79.5 });
    expect(secondInsertError).not.toBeNull();

    const { error: upsertError } = await client
      .from("body_measurements")
      .upsert(
        { user_id: memberAId, measured_on: "2026-09-06", weight_kg: 79.5 },
        { onConflict: "user_id,measured_on" },
      );
    expect(upsertError).toBeNull();

    const { data } = await client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-06");
    expect(data).toEqual([{ weight_kg: 79.5 }]);
  });

  it("Wertegrenze: 19,5 kg und 400,5 kg scheitern am Check", async () => {
    const client = await userClient(memberAEmail);

    const { error: zuLeicht } = await client
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-07", weight_kg: 19.5 });
    expect(zuLeicht).not.toBeNull();

    const { error: zuSchwer } = await client
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-08", weight_kg: 400.5 });
    expect(zuSchwer).not.toBeNull();
  });

  it("Austritt: nach Loeschen der Mitgliedschaft liest A weiterhin die eigene Zeile", async () => {
    const admin = serviceClient();
    const { error: seedError } = await admin
      .from("body_measurements")
      .insert({ user_id: memberAId, measured_on: "2026-09-09", weight_kg: 79.0 });
    if (seedError) throw seedError;

    const { error: deleteError } = await admin
      .from("studio_memberships")
      .delete()
      .eq("id", membershipAId);
    if (deleteError) throw deleteError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", memberAId)
      .eq("measured_on", "2026-09-09");

    // Es gibt kein Studio, das mitreden koennte -- die Zeile gehoert zur
    // Person, nicht zur Mitgliedschaft.
    expect(data).toEqual([{ weight_kg: 79.0 }]);
  });

  it("anonClient() liest nichts", async () => {
    const client = anonClient();

    const { data } = await client.from("body_measurements").select("id");

    expect(data).toEqual([]);
  });
});
