import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { studioMitTrainer } from "./helpers/studio";
import { anmelden, E2E_PASSWORD } from "./helpers/login";
import { GYMTAVO, gymtavoTyp, typWaehlen } from "./helpers/gymtavo";
import { radWaehlen } from "./helpers/rad";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Nachtrag 10.1.

test("Ein neues Modell bekommt seinen Gymtavo-Typ, ohne Typ geht es nicht weiter", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-anlegen");
  const { typName, typId } = await gymtavoTyp(admin, "Kabelzug");

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await page.getByLabel("Name").fill("Kabelturm");
  await radWaehlen(page, "Schritt", "5");
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page.getByText(/Wähle den Gymtavo-Gerätetyp/)).toBeVisible();

  // Der Browser haelt das Absenden an -- die Eingaben bleiben stehen.
  await expect(page.getByLabel("Name")).toHaveValue("Kabelturm");
  await typWaehlen(page, typName);
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));

  const { data } = await admin.from("equipment_models").select("catalog_model_id").eq("studio_id", studioId).single();
  expect(data?.catalog_model_id).toBe(typId);
});

test("Ein altes Modell zeigt den Hinweis, bis es zugeordnet ist", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-altbestand");
  const { typName } = await gymtavoTyp(admin, "Beinpresse");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beinpresse alt", load_step: 5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}`);
  await page.getByText(/Punkte? offen/).click();
  const band = page.getByRole("list", { name: "Noch zu tun" });
  await expect(band).toContainText("Kein Gymtavo-Typ");

  await typWaehlen(page, typName);
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(page.getByText("Gespeichert ✓")).toBeVisible();
  await page.reload();
  await expect(page.getByText("Kein Gymtavo-Typ")).toHaveCount(0);
});

test("Gymtavo-Uebungen stehen am Modell, eine weitere laesst sich anhaengen, ein eigenes Video ergaenzen", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-uebungen");
  const typ = await gymtavoTyp(admin, "Langhantel", ["Bankdrücken"]);
  const anderer = await gymtavoTyp(admin, "Kabelzug", ["Face Pull"]);
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Hantelbank", load_step: 2.5, catalog_model_id: typ.typId })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/uebungen`);
  const gymtavo = page.getByRole("list", { name: "Gymtavo-Übungen am Modell" });
  await expect(gymtavo).toContainText(typ.uebungen[0]!.name);
  await expect(gymtavo).toContainText("vom Typ");

  await page.getByRole("button", { name: "Gymtavo-Übung anhängen" }).click();
  await page.getByRole("button", { name: "Gymtavo-Übung", exact: true }).click();
  await page.getByRole("searchbox", { name: "Übung suchen" }).fill(anderer.uebungen[0]!.name);
  await page.getByRole("option", { name: new RegExp(anderer.uebungen[0]!.name) }).click();
  await page.getByRole("button", { name: "Anhängen", exact: true }).click();
  await expect(gymtavo).toContainText(anderer.uebungen[0]!.name);
  await expect(gymtavo).toContainText("angehängt");

  await page.getByRole("button", { name: `${typ.uebungen[0]!.name} bearbeiten` }).click();
  await page.getByRole("button", { name: "Eigenes Video ergänzen" }).click();
  // Das Dateifeld selbst ist unsichtbar, es steht hinter dem Knopf.
  await expect(page.getByLabel("Einweisungsvideo hochladen")).toBeAttached();

  const { data: links } = await admin
    .from("equipment_model_exercises")
    .select("exercise_id")
    .eq("equipment_model_id", modell.id);
  expect(links?.map((l) => l.exercise_id).sort()).toEqual(
    [typ.uebungen[0]!.id, anderer.uebungen[0]!.id].sort(),
  );
});

test("Der Uebungsschritt der Halle zeigt, was vom Gymtavo-Typ mitkommt", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-halle");
  const typ = await gymtavoTyp(admin, "Rudergeraet", ["Rudern sitzend"]);
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Ruderzug", load_step: 5, catalog_model_id: typ.typId })
    .select("id")
    .single();
  if (error) throw error;
  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "3" })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/uebungen`);
  await expect(page.getByRole("heading", { name: "Kommen automatisch mit" })).toBeVisible();
  await expect(page.getByText(typ.uebungen[0]!.name)).toBeVisible();
  await expect(page.getByText("Noch keine Übung")).toHaveCount(0);
});

test("Das Gymtavo-Studio zeigt keine Mitglieder, keine Geraete im Raum und keine Tags", async ({ page }) => {
  const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  });
  const email = `gymtavo-team-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;
  const { error: rolleFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: GYMTAVO, user_id: nutzer.user.id, role: "trainer" });
  if (rolleFehler) throw rolleFehler;
  const typ = await gymtavoTyp(admin, "Katalogtyp");
  await anmelden(page, email);

  await page.goto(`/portal/${GYMTAVO}`);
  await expect(page).toHaveURL(new RegExp(`/portal/${GYMTAVO}/geraete$`));
  await expect(page.getByRole("heading", { name: "Gerätetypen" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Leute/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: /Tags/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: /Gerät hinzufügen/ })).toHaveCount(0);

  await page.goto(`/portal/${GYMTAVO}/geraete/${typ.typId}`);
  await expect(page.getByRole("link", { name: /Einzelne Geräte/ })).toHaveCount(0);
  await expect(page.getByText("Kein Gymtavo-Typ")).toHaveCount(0);

  // Inhalt statt HTTP-Status: (schreibtisch)/loading.tsx laesst die Seite
  // streamen, der Status steht dann schon auf 200, bevor notFound() greift.
  for (const pfad of ["leute", "tags", "kurse", "einrichten", `geraete/${typ.typId}/instanzen`]) {
    await page.goto(`/portal/${GYMTAVO}/${pfad}`);
    await expect(page.getByText("Diese Seite gibt es nicht."), pfad).toBeVisible();
  }
});
