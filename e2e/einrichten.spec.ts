import { expect, test } from "@playwright/test";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Ein JPEG in der gewuenschten Groesse: SOI, JFIF, SOS, Nutzlast, EOI.
 *
 * Bewusst in Handygroesse und nicht als 22-Byte-Rumpf. Genau diese Luecke
 * hat verdeckt, dass stripImageMetadata an jedem echten Foto zerbrach und
 * dass eine Server Action standardmaessig bei 1 MB abschneidet.
 */
function jpegMitGroesse(bytes: number): Buffer {
  const kopf = [
    0xff, 0xd8,
    0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,
  ];
  const datei = Buffer.alloc(bytes, 0x7a);
  Buffer.from(kopf).copy(datei, 0);
  datei[bytes - 2] = 0xff;
  datei[bytes - 1] = 0xd9;
  return datei;
}

/** So gross wie ein Foto aus einer Handykamera. */
const HANDYFOTO = jpegMitGroesse(2 * 1024 * 1024);

test("Der Einstieg zaehlt den Bestand und fuehrt in den Gang", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einrichten-einstieg");

  await page.goto(`/portal/${studioId}/einrichten`);
  await expect(page.getByRole("heading", { name: "Einrichten" })).toBeVisible();

  // Ein frisches Studio hat nichts -- und sagt das, statt eine leere Liste
  // zu zeigen.
  await expect(page.getByText("Kein Tag vorrätig")).toBeVisible();
  await expect(
    page.getByText("Noch keine Lieferung angekommen."),
  ).toBeVisible();

  // Die Rail des Schreibtischs darf hier nicht stehen.
  await expect(page.getByRole("navigation", { name: "Katalog" })).toHaveCount(0);

  await page.getByRole("link", { name: "Gerät einrichten" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell$`),
  );
});

test("Schritt 1 legt ein Modell mit Pflichtfoto an und geht zu den Einstellungen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einrichten-modell");

  await page.goto(`/portal/${studioId}/einrichten/modell`);
  await expect(page.getByText("Noch kein Modell im Studio")).toBeVisible();
  await page.getByRole("link", { name: "Neues Modell anlegen" }).click();

  await page.getByLabel("Name").fill("Kabelzug");
  await page.getByLabel("Hersteller").fill("Technogym");
  // Der Gewichtsschritt ist eine Chipreihe, kein Feld: drei Werte, und die
  // Schrittweite kommt von den Platten am Geraet, nicht aus dem Kopf.
  await page.getByRole("button", { name: "5 kg", exact: true }).click();
  await page.getByLabel("Ab").fill("5");
  await page.getByLabel("Bis").fill("100");

  // Ohne Foto geht es nicht weiter -- Entscheidung 10.
  await expect(
    page.getByRole("button", { name: "Weiter zu den Einstellungen" }),
  ).toBeDisabled();

  await page.getByLabel("Foto des Modells").setInputFiles({
    name: "kabelzug.jpg",
    mimeType: "image/jpeg",
    buffer: HANDYFOTO,
  });
  await expect(
    page.getByRole("button", { name: "Weiter zu den Einstellungen" }),
  ).toBeEnabled();

  await page
    .getByRole("button", { name: "Weiter zu den Einstellungen" })
    .click();

  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell/[0-9a-f-]+/einstellungen$`),
  );

  await expect(page.getByText("Schritt 2 von 6 · Einstellungen")).toBeVisible();
  await expect(page.getByText("Foto · Steht")).toBeVisible();
});

test("Schritt 2 fragt ein fehlendes Foto nach und nimmt Parameter auf", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-einst");

  // Ein Altmodell ohne Foto -- genau der Fall aus Entscheidung 12.
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse", weight_step_kg: 5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(
    `/portal/${studioId}/einrichten/modell/${modell.id}/einstellungen`,
  );
  await expect(page.getByText("Schritt 2 von 6 · Einstellungen")).toBeVisible();
  await expect(page.getByText("Foto · Fehlt")).toBeVisible();
  await expect(page.getByText("Noch keine Einstellparameter")).toBeVisible();

  await page.getByRole("button", { name: "Parameter hinzufügen" }).click();
  await page.getByLabel("Beschriftung").fill("Sitzhöhe");
  await page.getByLabel("Schlüssel").fill("sitz");
  await page.getByLabel("Von").fill("1");
  await page.getByLabel("Bis").fill("8");
  await page.getByLabel("Schritt", { exact: true }).fill("1");
  await page.getByRole("button", { name: "Hinzufügen" }).click();

  await expect(page.getByText("Sitzhöhe")).toBeVisible();
  await expect(page.getByText("Zahl · 1 – 8 · Schritt 1")).toBeVisible();

  // Das Foto laesst sich hier nachreichen -- der einzige Weg fuer ein
  // Altmodell.
  await page.getByLabel("Foto nachreichen").setInputFiles({
    name: "brustpresse.jpg",
    mimeType: "image/jpeg",
    buffer: HANDYFOTO,
  });
  await expect(page.getByText("Foto · Steht")).toBeVisible();

  await page.getByRole("link", { name: "Weiter zum Gerät" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/einrichten/modell/${modell.id}/geraet$`),
  );
});

test("Schritt 3 schlaegt die naechste Nummer vor und legt das Geraet an", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-geraet");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  // Zwei Geraete stehen schon, das hoechste traegt die 13.
  const { error: geraeteFehler } = await admin.from("machines").insert([
    {
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "12",
      location_note: "Rückwand links",
    },
    { studio_id: studioId, equipment_model_id: modell.id, label: "13" },
  ]);
  if (geraeteFehler) throw geraeteFehler;

  await page.goto(`/portal/${studioId}/einrichten/modell/${modell.id}/geraet`);
  await expect(page.getByText("Schritt 3 von 6 · Gerät")).toBeVisible();

  // Vorgeschlagen ist die naechste nach der hoechsten -- 14, nicht die
  // naechste Luecke.
  await expect(page.getByLabel("Nummer")).toHaveValue("14");

  // Der bereits vergebene Standort steht als Chip bereit.
  await page.getByRole("button", { name: "Rückwand links" }).click();
  await expect(page.getByLabel("Standort")).toHaveValue("Rückwand links");

  await page.getByLabel("Standort").fill("Rückwand rechts");
  await page.getByRole("button", { name: "Weiter zum Tag" }).click();

  await expect(page).toHaveURL(new RegExp(`/einrichten/geraet/[0-9a-f-]+/tag$`));

  // AUFGABE 9 schaltet die Zeile wieder ein -- die Tag-Seite gibt es dann.
  // await expect(page.getByText("Schritt 4 von 6 · Tag")).toBeVisible();
});
