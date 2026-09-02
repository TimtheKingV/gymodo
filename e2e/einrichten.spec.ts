import { expect, test } from "@playwright/test";
import { studioMitTrainer } from "./helpers/studio";
import { tagAnlegen } from "../tests/helpers/tags";

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

  await expect(page.getByText("Schritt 4 von 6 · Tag")).toBeVisible();
});

test("Schritt 4 beantwortet den Tag und verbindet ihn mit dem Geraet", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-tag");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "14",
      location_note: "Rückwand rechts",
    })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/tag`);
  await expect(page.getByText("Schritt 4 von 6 · Tag")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Tag ankleben" })).toBeVisible();
  await expect(page.getByText("Metall braucht die Ferritseite")).toBeVisible();

  // Ein Aushangschild ist vor dem Scan nicht von einem Geraeteaufkleber zu
  // unterscheiden -- das ist Absicht, und deshalb muss die Antwort sagen,
  // was in der Hand liegt (Spec 4, vierte Zeile).
  const schild = await tagAnlegen(admin, {
    studioId,
    kind: "studio",
    status: "active",
  });
  await page.getByLabel("Token vom Tag").fill(schild.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Das ist ein Aushangschild")).toBeVisible();
  await expect(page.getByRole("button", { name: "Verbinden" })).toHaveCount(0);
  // Die Antwort ist eine Sackgasse mit genau einem Ausgang -- und der fuehrt
  // zurueck, nicht weiter.
  await page.getByRole("button", { name: "Anderen Tag nehmen" }).click();

  // Ein vergebener Tag nennt sein Geraet und bietet nichts an.
  const { data: anderes, error: anderesFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "Beinpresse 7",
    })
    .select("id")
    .single();
  if (anderesFehler) throw anderesFehler;
  const vergeben = await tagAnlegen(admin, {
    studioId,
    machineId: anderes.id,
    status: "active",
  });
  await page.getByLabel("Token vom Tag").fill(vergeben.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Dieser Tag gehört zu Beinpresse 7.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Verbinden" })).toHaveCount(0);
  await page.getByRole("button", { name: "Anderen Tag nehmen" }).click();

  // Ein frischer Tag aus der Lieferung ist studiolos und lernt sein Studio
  // erst hier (0028).
  const frisch = await tagAnlegen(admin, { studioId: null });
  await page.getByLabel("Token vom Tag").fill(frisch.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Tag erkannt")).toBeVisible();
  await page.getByRole("button", { name: "Verbinden" }).click();

  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/${geraet.id}/uebungen$`),
  );
});

test("Schritt 5 waehlt aus dem Studio, legt neu an und ordnet um", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-ueb");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "14",
    })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  // Eine Uebung, die dem Studio schon gehoert und an keinem Modell haengt.
  const { error: uebungFehler } = await admin.from("exercises").insert({
    studio_id: studioId,
    name: "Rudern sitzend",
    target_reps_min: 10,
    target_reps_max: 15,
  });
  if (uebungFehler) throw uebungFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/uebungen`);
  await expect(page.getByText("Schritt 5 von 6 · Übungen")).toBeVisible();
  await expect(page.getByText("Noch keine Übung")).toBeVisible();

  // Waehlen statt tippen -- sonst steht dieselbe Uebung mehrfach im Katalog.
  await page.getByRole("button", { name: "Aus dem Studio wählen" }).click();
  await expect(page.getByText("Noch an keinem Modell")).toBeVisible();
  await page.getByRole("button", { name: "Rudern sitzend hinzufügen" }).click();
  await expect(page.getByText("1. Rudern sitzend")).toBeVisible();

  // Eine neue Uebung entsteht und haengt sofort am Modell.
  await page.getByRole("button", { name: "Neue Übung anlegen" }).click();
  await page.getByLabel("Name").fill("Latzug · Neutralgriff");
  await page.getByLabel("Wiederholungen ab").fill("8");
  await page.getByLabel("bis", { exact: true }).fill("12");
  await page.getByRole("button", { name: "Hinzufügen" }).click();
  await expect(page.getByText("2. Latzug · Neutralgriff")).toBeVisible();

  // Die Reihenfolge ist keine Kosmetik: Uebung 1 ist am Geraet die Vorauswahl.
  await page
    .getByRole("button", { name: "Latzug · Neutralgriff nach oben" })
    .click();
  await expect(page.getByText("1. Latzug · Neutralgriff")).toBeVisible();
  await expect(page.getByText("2. Rudern sitzend")).toBeVisible();

  await page.getByRole("link", { name: "Einrichtung abschließen" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/${geraet.id}/fertig$`),
  );
});

test("Ein Video wartet in der Warteschlange und ueberlebt den Seitenwechsel", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-upload");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "14" })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  const { data: uebung, error: uebungFehler } = await admin
    .from("exercises")
    .insert({
      studio_id: studioId,
      name: "Rudern sitzend",
      target_reps_min: 10,
      target_reps_max: 15,
    })
    .select("id")
    .single();
  if (uebungFehler) throw uebungFehler;

  const { error: linkFehler } = await admin
    .from("equipment_model_exercises")
    .insert({
      equipment_model_id: modell.id,
      exercise_id: uebung.id,
      sort_order: 1,
    });
  if (linkFehler) throw linkFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/uebungen`);

  await page.getByLabel("Video für Rudern sitzend").setInputFiles({
    name: "rudern.mp4",
    mimeType: "video/mp4",
    buffer: Buffer.alloc(1024, 1),
  });

  const marke = page.getByRole("link", { name: /Uploads/ });
  await expect(marke).toBeVisible();

  // Der Seitenwechsel ist der Punkt: die Warteschlange lebt im Layout des
  // Gangs, nicht in der Uebungsseite. Geklickt, nicht per goto -- eine harte
  // Navigation wuerde sie loeschen, und dann pruefte der Test das Gegenteil
  // von dem, was er behauptet.
  await marke.click();
  await expect(page).toHaveURL(new RegExp(`/einrichten/uploads$`));
  await expect(page.getByText("Kabelzug 14 · Rudern sitzend")).toBeVisible();
  await expect(page.getByText("Lass diesen Bildschirm offen")).toBeVisible();
});
