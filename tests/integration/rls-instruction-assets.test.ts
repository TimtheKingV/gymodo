import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let staffAEmail: string;
let memberAEmail: string;
let memberBEmail: string;
let staffBEmail: string;
let linkId: string;
let linkBId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Assets Studio A" }, { name: "Assets Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  staffAEmail = uniqueEmail("assets-staff-a");
  memberAEmail = uniqueEmail("assets-member-a");
  memberBEmail = uniqueEmail("assets-member-b");
  staffBEmail = uniqueEmail("assets-staff-b");
  const staffAId = await createTestUser(staffAEmail);
  const memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(memberBEmail);
  const staffBId = await createTestUser(staffBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
    { studio_id: studioB, user_id: staffBId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinstrecker", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Beinstrecken",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;

  const { data: link, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: exercise.id })
    .select("id")
    .single();
  if (linkError) throw linkError;
  linkId = link.id;

  // Vollstaendiges Gegenstueck in Studio B: ohne eine echte Verknuepfung
  // dort wuerden die Cross-Tenant-Ablehnungen fuer staffB nur beweisen,
  // dass er nirgends relevant Staff ist -- nicht, dass die Policy das
  // Studio der Zeile selbst prueft.
  const { data: modelB, error: modelBError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: "Beinstrecker B", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelBError) throw modelBError;

  const { data: exerciseB, error: exerciseBError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioB,
      name: "Beinstrecken B",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseBError) throw exerciseBError;

  const { data: linkB, error: linkBError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: modelB.id, exercise_id: exerciseB.id })
    .select("id")
    .single();
  if (linkBError) throw linkBError;
  linkBId = linkB.id;
});

describe("RLS auf instruction_assets", () => {
  it("positiv: Staff kann ein Einweisungsvideo anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/beinstrecken.mp4",
      duration_s: 30,
    });
    expect(error).toBeNull();
  });

  it("negativ: Video ueber 45 Sekunden wird abgelehnt", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/zu-lang.mp4",
      duration_s: 60,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/zu-lang.mp4");
    expect(found).toEqual([]);
  });

  it("negativ: Mitglied kann kein Einweisungsvideo anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/verboten.mp4",
      duration_s: 20,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/verboten.mp4");
    expect(found).toEqual([]);
  });

  it("cross-tenant: Staff aus Studio B kann in Studio A kein Video anlegen", async () => {
    const client = await userClient(staffBEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/cross-verboten.mp4",
      duration_s: 20,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/cross-verboten.mp4");
    expect(found).toEqual([]);
  });

  it("positiv: Staff aus Studio B kann an eigener Verknuepfung ein Video anlegen", async () => {
    // Belegt, dass die insert-Policy ueberhaupt jemandem Zugriff gewaehrt --
    // erst dadurch sind die A-Ablehnungen fuer staffB oben aussagekraeftig
    // und nicht bloss Zufall, weil staffB nirgends Staff waere.
    const client = await userClient(staffBEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkBId,
      kind: "video",
      storage_path: "instructions/studio-b-eigenes-video.mp4",
      duration_s: 20,
    });
    expect(error).toBeNull();

    const admin = serviceClient();
    // Auf die Verknuepfung DIESES Laufs eingegrenzt. Der storage_path allein
    // reicht nicht: er ist fest verdrahtet, instruction_assets kennt darauf
    // keine Eindeutigkeit, und jeder Testlauf legt eine weitere Zeile an --
    // ab dem zweiten Lauf gegen dieselbe Datenbank zaehlte die Abfrage die
    // Zeilen aller Vorlaeufe mit.
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkBId)
      .eq("storage_path", "instructions/studio-b-eigenes-video.mp4");
    expect(found).toHaveLength(1);
  });

  it("positiv: Mitglied aus Studio A sieht das Video", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkId);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht das Video nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkId);
    expect(data).toEqual([]);
  });

  describe("update/delete", () => {
    let updateAssetId: string;
    let memberUpdateDenyAssetId: string;
    let crossUpdateDenyAssetId: string;
    let reassignDenyAssetId: string;
    let deleteAssetId: string;
    let memberDeleteDenyAssetId: string;
    let crossDeleteDenyAssetId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("instruction_assets")
        .insert([
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-ziel.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-mitglied-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-cross-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/reassign-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-ziel.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-mitglied-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-cross-verboten.mp4",
            duration_s: 15,
          },
        ])
        .select("id");
      if (error) throw error;
      updateAssetId = data[0]!.id;
      memberUpdateDenyAssetId = data[1]!.id;
      crossUpdateDenyAssetId = data[2]!.id;
      reassignDenyAssetId = data[3]!.id;
      deleteAssetId = data[4]!.id;
      memberDeleteDenyAssetId = data[5]!.id;
      crossDeleteDenyAssetId = data[6]!.id;
    });

    it("positiv: Staff kann ein Einweisungsvideo aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", updateAssetId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateAssetId);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", updateAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(22);
    });

    it("negativ: Mitglied kann kein Einweisungsvideo aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", memberUpdateDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", memberUpdateDenyAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(15);
    });

    it("cross-tenant: Staff aus Studio B kann ein Video in Studio A nicht aktualisieren", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", crossUpdateDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", crossUpdateDenyAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(15);
    });

    it("with check: Staff aus Studio A kann ein Asset nicht auf eine Verknuepfung in Studio B umhaengen", async () => {
      // Die using-Klausel allein liesse das durch (der Aufrufer ist Staff
      // in Studio A und die Zeile gehoert derzeit zu Studio A) -- nur die
      // with-check-Klausel prueft den *neuen* Zielwert und muss hier
      // greifen.
      // Anders als ein reiner using-Fehlschlag (der still auf 0 Zeilen
      // filtert): die Zeile ist fuer staffA sichtbar/eigenstaendig (using
      // greift), aber der neue Zielwert scheitert an with check -- Postgres
      // meldet das als expliziten RLS-Fehler, nicht als leeres Ergebnis.
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("instruction_assets")
        .update({ equipment_model_exercise_id: linkBId })
        .eq("id", reassignDenyAssetId)
        .select("id");
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("equipment_model_exercise_id")
        .eq("id", reassignDenyAssetId)
        .single();
      expect(reloaded?.equipment_model_exercise_id).toBe(linkId);
    });

    it("positiv: Staff kann ein Einweisungsvideo loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", deleteAssetId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", deleteAssetId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann kein Einweisungsvideo loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", memberDeleteDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", memberDeleteDenyAssetId);
      expect(remaining).toHaveLength(1);
    });

    it("cross-tenant: Staff aus Studio B kann ein Video in Studio A nicht loeschen", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", crossDeleteDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", crossDeleteDenyAssetId);
      expect(remaining).toHaveLength(1);
    });
  });

  describe("Loeschkette: ein Einweisungsvideo verschwindet nicht nebenbei", () => {
    // Bis 0019 kaskadierte das Loeschen einer Uebung ueber
    // equipment_model_exercises bis auf instruction_assets durch. Wer eine
    // Uebung aus dem Katalog nahm, loeschte damit stillschweigend die
    // Videozeile -- die Datei im Bucket blieb als Waise liegen, ohne dass
    // irgendwo stand, wozu sie gehoert hatte.
    /** Postgres foreign_key_violation. */
    const FK_VIOLATION = "23503";

    /** Frische Uebung samt Verknuepfung in Studio A. */
    async function seedLink(): Promise<{ linkId: string; exerciseId: string }> {
      const admin = serviceClient();

      const { data: model, error: modelError } = await admin
        .from("equipment_models")
        .insert({ studio_id: studioA, name: "Loeschkette-Modell", weight_step_kg: 5 })
        .select("id")
        .single();
      if (modelError) throw modelError;

      const { data: exercise, error: exerciseError } = await admin
        .from("exercises")
        .insert({
          studio_id: studioA,
          name: "Loeschkette-Uebung",
          target_reps_min: 8,
          target_reps_max: 12,
        })
        .select("id")
        .single();
      if (exerciseError) throw exerciseError;

      const { data: link, error: linkError } = await admin
        .from("equipment_model_exercises")
        .insert({ equipment_model_id: model.id, exercise_id: exercise.id })
        .select("id")
        .single();
      if (linkError) throw linkError;

      return { linkId: link.id, exerciseId: exercise.id };
    }

    it("negativ: eine Verknuepfung mit Einweisungsvideo laesst sich nicht loeschen", async () => {
      const { linkId: link } = await seedLink();
      const client = await userClient(staffAEmail);

      const { error: assetError } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: link,
        kind: "video",
        storage_path: "instructions/loeschkette-verknuepfung.mp4",
        duration_s: 20,
      });
      expect(assetError).toBeNull();

      const { error } = await client
        .from("equipment_model_exercises")
        .delete()
        .eq("id", link);
      expect(error?.code).toBe(FK_VIOLATION);

      const admin = serviceClient();
      const { data: stillThere } = await admin
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", link);
      expect(stillThere).toHaveLength(1);
    });

    it("negativ: auch die Uebung selbst laesst sich nicht loeschen, solange ein Video haengt", async () => {
      const { linkId: link, exerciseId } = await seedLink();
      const client = await userClient(staffAEmail);

      const { error: assetError } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: link,
        kind: "video",
        storage_path: "instructions/loeschkette-uebung.mp4",
        duration_s: 20,
      });
      expect(assetError).toBeNull();

      const { error } = await client.from("exercises").delete().eq("id", exerciseId);
      expect(error?.code).toBe(FK_VIOLATION);

      const admin = serviceClient();
      const { data: stillThere } = await admin
        .from("exercises")
        .select("id")
        .eq("id", exerciseId);
      expect(stillThere).toHaveLength(1);
    });

    it("positiv: nach dem Loeschen des Videos geht die Uebung wieder weg", async () => {
      const { linkId: link, exerciseId } = await seedLink();
      const client = await userClient(staffAEmail);

      const { data: asset, error: assetError } = await client
        .from("instruction_assets")
        .insert({
          equipment_model_exercise_id: link,
          kind: "video",
          storage_path: "instructions/loeschkette-frei.mp4",
          duration_s: 20,
        })
        .select("id")
        .single();
      expect(assetError).toBeNull();

      const { error: assetDeleteError } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", asset!.id);
      expect(assetDeleteError).toBeNull();

      const { error } = await client.from("exercises").delete().eq("id", exerciseId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: gone } = await admin
        .from("exercises")
        .select("id")
        .eq("id", exerciseId);
      expect(gone).toEqual([]);
    });

    it("positiv: eine Verknuepfung ohne Video laesst sich weiterhin loeschen", async () => {
      const { linkId: link } = await seedLink();
      const client = await userClient(staffAEmail);

      const { error } = await client
        .from("equipment_model_exercises")
        .delete()
        .eq("id", link);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: gone } = await admin
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", link);
      expect(gone).toEqual([]);
    });
  });

  describe("Eindeutigkeit von storage_path je Verknuepfung", () => {
    // Ohne diese Eindeutigkeit legt ein wiederholter Upload -- der zweite
    // Anlauf nach einem Abbruch im Studio-WLAN -- eine zweite Zeile auf
    // dasselbe Objekt an. getTagContext nimmt instruction_assets[0] und
    // zoege dann willkuerlich eine der beiden.
    const PFAD = "instructions/wiederholter-upload.mp4";
    /** Postgres unique_violation. */
    const UNIQUE_VIOLATION = "23505";

    it("negativ: derselbe Pfad ein zweites Mal an derselben Verknuepfung", async () => {
      const client = await userClient(staffAEmail);

      const first = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: PFAD,
        duration_s: 20,
      });
      expect(first.error).toBeNull();

      const second = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: PFAD,
        duration_s: 20,
      });
      expect(second.error?.code).toBe(UNIQUE_VIOLATION);

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("equipment_model_exercise_id", linkId)
        .eq("storage_path", PFAD);
      expect(found).toHaveLength(1);
    });

    it("positiv: derselbe Pfad an einer anderen Verknuepfung bleibt erlaubt", async () => {
      const client = await userClient(staffBEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkBId,
        kind: "video",
        storage_path: PFAD,
        duration_s: 20,
      });
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("equipment_model_exercise_id", linkBId)
        .eq("storage_path", PFAD);
      expect(found).toHaveLength(1);
    });
  });

  describe("Formatgrenze duration_s", () => {
    it("positiv: 45 Sekunden werden akzeptiert (obere Grenze)", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: "instructions/grenze-45.mp4",
        duration_s: 45,
      });
      expect(error).toBeNull();
    });

    it("negativ: 46 Sekunden werden abgelehnt", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: "instructions/grenze-46.mp4",
        duration_s: 46,
      });
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("storage_path", "instructions/grenze-46.mp4");
      expect(found).toEqual([]);
    });

    it("negativ: 0 Sekunden werden abgelehnt", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: "instructions/grenze-0.mp4",
        duration_s: 0,
      });
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("storage_path", "instructions/grenze-0.mp4");
      expect(found).toEqual([]);
    });

    it("negativ: ein negativer Wert wird abgelehnt", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: "instructions/grenze-negativ.mp4",
        duration_s: -5,
      });
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("storage_path", "instructions/grenze-negativ.mp4");
      expect(found).toEqual([]);
    });

    it("negativ: fehlendes duration_s wird abgelehnt (not null)", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("instruction_assets").insert({
        equipment_model_exercise_id: linkId,
        kind: "video",
        storage_path: "instructions/grenze-fehlt.mp4",
      });
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: found } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("storage_path", "instructions/grenze-fehlt.mp4");
      expect(found).toEqual([]);
    });
  });
});
