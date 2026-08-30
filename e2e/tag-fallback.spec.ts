import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
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

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    machine_id: machine.id,
    token_hash: hashTagToken(token),
    status: "active",
  });
  if (tagError) throw tagError;

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

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    token_hash: hashTagToken(token),
    status: "unassigned",
  });
  if (tagError) throw tagError;

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

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    token_hash: hashTagToken(token),
    status: "revoked",
  });
  if (tagError) throw tagError;

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});
