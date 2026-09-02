import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createTagToken } from "@fitretro/domain";
import { tagAnlegen } from "../tests/helpers/tags";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}


function ascii(text: string): number[] {
  return [...text].map((zeichen) => zeichen.charCodeAt(0));
}

function jpegBytes(): Uint8Array {
  return new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...ascii("JFIF"), 0x00, 0x01, 0x01,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
}

function mp4Bytes(): Uint8Array {
  return new Uint8Array([
    0x00, 0x00, 0x00, 0x18, ...ascii("ftyp"), ...ascii("isom"), 0x00, 0x00,
    0x02, 0x00, ...ascii("isomiso2"),
  ]);
}

test("unbekannter Token zeigt eine neutrale Fehlermeldung", async ({ page }) => {
  await page.goto(`/t/${createTagToken()}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("ungueltiges Tokenformat zeigt dieselbe neutrale Meldung", async ({
  page,
}) => {
  await page.goto("/t/viel-zu-kurz");
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("aktiver Tag mit zugewiesenem Geraet zeigt den Installationshinweis", async ({
  page,
}) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Fallback Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { data: model, error: modelError } = await client
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Testgeraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await client
    .from("machines")
    .insert({
      studio_id: studio.id,
      equipment_model_id: model.id,
      label: "Testgeraet 1",
    })
    .select("id")
    .single();
  if (machineError) throw machineError;

  const { token } = await tagAnlegen(client, {
    studioId: studio.id,
    machineId: machine.id,
    status: "active",
  });

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("install-hint")).toBeVisible();
});

test("noch nicht zugewiesener Tag zeigt dieselbe neutrale Meldung", async ({
  page,
}) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Unassigned Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { token } = await tagAnlegen(client, {
    studioId: studio.id,
    status: "unassigned",
  });

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("gesperrter Tag liefert keine Geraetedaten", async ({ page }) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Revoked Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { token } = await tagAnlegen(client, {
    studioId: studio.id,
    status: "revoked",
  });

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

/**
 * Spec 6.4: der Fallback zeigt die Einweisung, bevor er zur Installation
 * auffordert. Der Nutzen kommt vor der Aufforderung -- und das laeuft auf
 * Android genauso.
 */
test("aktiver Tag zeigt Geraet, Foto und Einweisungsvideo vor dem Installationshinweis", async ({
  page,
}) => {
  const client = admin();

  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Fallback Medien Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const fotoPfad = `${studio.id}/models/${crypto.randomUUID()}.jpg`;
  const videoPfad = `${studio.id}/exercises/${crypto.randomUUID()}.mp4`;

  const { data: model, error: modelError } = await client
    .from("equipment_models")
    .insert({
      studio_id: studio.id,
      name: "Beinpresse",
      weight_step_kg: 5,
      photo_path: fotoPfad,
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: uebung, error: uebungError } = await client
    .from("exercises")
    .insert({
      studio_id: studio.id,
      name: "Beidbeinig",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (uebungError) throw uebungError;

  const { data: link, error: linkError } = await client
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: uebung.id })
    .select("id")
    .single();
  if (linkError) throw linkError;

  const { error: assetError } = await client.from("instruction_assets").insert({
    equipment_model_exercise_id: link.id,
    kind: "video",
    storage_path: videoPfad,
    duration_s: 25,
  });
  if (assetError) throw assetError;

  const { data: machine, error: machineError } = await client
    .from("machines")
    .insert({
      studio_id: studio.id,
      equipment_model_id: model.id,
      label: "7",
      location_note: "Beinbereich",
    })
    .select("id")
    .single();
  if (machineError) throw machineError;

  for (const [bucket, pfad, bytes, typ] of [
    ["equipment-photos", fotoPfad, jpegBytes(), "image/jpeg"],
    ["instruction-videos", videoPfad, mp4Bytes(), "video/mp4"],
  ] as const) {
    const { error } = await client.storage
      .from(bucket)
      .upload(pfad, new Blob([bytes], { type: typ }), {
        contentType: typ,
        upsert: true,
      });
    if (error) throw error;
  }

  const { token } = await tagAnlegen(client, {
    studioId: studio.id,
    machineId: machine.id,
    status: "active",
  });

  await page.goto(`/t/${token}`);

  await expect(page.getByTestId("machine-name")).toContainText("Beinpresse");
  await expect(page.getByTestId("machine-name")).toContainText("7");
  await expect(page.getByTestId("machine-photo")).toBeVisible();
  await expect(page.getByTestId("exercise-Beidbeinig")).toBeVisible();
  await expect(page.getByTestId("video-Beidbeinig")).toBeVisible();

  // Der Hinweis steht darunter, nicht darueber.
  await expect(page.getByTestId("install-hint")).toBeVisible();
  const videoOben = await page.getByTestId("video-Beidbeinig").boundingBox();
  const hinweisUnten = await page.getByTestId("install-hint").boundingBox();
  expect(videoOben!.y).toBeLessThan(hinweisUnten!.y);

  // Und niemals persoenliche Daten. Geprueft wird der sichtbare Text, nicht
  // das Rohdokument: dort steht "kg" schon im Base64 der signierten URL.
  const sichtbar = await page.locator("body").innerText();
  // "Verlauf" steht im Installationshinweis selbst -- das ist die
  // Formulierung der Spec, keine Personendaten.
  for (const verboten of ["kg", "Satz", "Wiederholung"]) {
    expect(sichtbar).not.toContain(verboten);
  }
});

/**
 * Ein Aushang traegt denselben Tokenraum wie ein Geraeteaufkleber, zeigt
 * aber kein Geraet (Migration 0022, 0025). Die Seite verzweigt auf `kind`
 * und zeigt das Studio statt einer Geraeteseite ohne Geraet.
 */
test("ein Aushang-Token zeigt das Studio statt eines Geraets", async ({
  page,
}) => {
  const client = admin();

  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Aushang Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { token: aushangToken } = await tagAnlegen(client, {
    studioId: studio.id,
    kind: "studio",
    status: "active",
  });

  await page.goto(`/t/${aushangToken}`);
  await expect(page.getByTestId("tag-aushang")).toBeVisible();
  await expect(page.getByRole("link", { name: "App laden" })).toBeVisible();
});
