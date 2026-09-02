import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./helpers/login";
import { tagAnlegen } from "../tests/helpers/tags";

/**
 * Verifikationspunkt 5 aus dem Plan: ein Studio komplett ueber die
 * Oberflaeche einrichten -- Modell, Parameter, Uebung, Geraet, Tag -- und
 * danach pruefen, dass der Geraete-Screen den Kontext bekommt.
 *
 * Das Einweisungsvideo bleibt hier aussen vor: sein Upload laeuft per TUS
 * direkt gegen den Storage-Dienst und wird in tests/integration abgedeckt
 * (domain-media.test.ts). Was dieser Test beweist, ist der Weg des Trainers
 * durch die Oberflaeche.
 */
function ascii(text: string): number[] {
  return [...text].map((zeichen) => zeichen.charCodeAt(0));
}

function jpegSegment(marker: number, payload: number[]): number[] {
  const laenge = payload.length + 2;
  return [0xff, marker, (laenge >> 8) & 0xff, laenge & 0xff, ...payload];
}

/** Ein JPEG mit Exif-Segment -- so kommt es aus dem Trainerhandy. */
function jpegMitExif(): Buffer {
  return Buffer.from([
    0xff, 0xd8,
    ...jpegSegment(0xe0, [
      ...ascii("JFIF"), 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    ]),
    ...jpegSegment(0xe1, [...ascii("Exif"), 0x00, 0x00, ...ascii("MM"), 0x2a, 0x47]),
    ...jpegSegment(0xda, [0x01, 0x01, 0x00, 0x00, 0x3f, 0x00]),
    0xab, 0xcd, 0xef,
    0xff, 0xd9,
  ]);
}

/**
 * memberships_select_staff (0030) laesst Mitarbeiter alle Mitgliedschaften
 * ihres Studios sehen, nicht nur die eigene -- die Portal-Einstiegsseite
 * muss ihre Abfrage seither selbst auf den Aufrufer filtern, sonst kommt
 * fuer einen Trainer in einem Studio mit weiterem Personal (hier: einem
 * Inhaber) dieselbe Studio-Zeile doppelt zurueck, und der Redirect fuer
 * "genau ein Studio" bleibt aus.
 */
test("Trainer in einem Studio mit weiterem Personal landet trotzdem direkt im Katalog", async ({
  page,
}) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const trainerEmail = `portal-mehrpersonal-${crypto.randomUUID()}@example.test`;
  const { data: trainer, error: trainerError } = await admin.auth.admin.createUser({
    email: trainerEmail,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (trainerError) throw trainerError;

  const ownerEmail = `portal-mehrpersonal-owner-${crypto.randomUUID()}@example.test`;
  const { data: owner, error: ownerError } = await admin.auth.admin.createUser({
    email: ownerEmail,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (ownerError) throw ownerError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Mehrpersonal E2E Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studio.id, user_id: trainer.user.id, role: "trainer" },
    { studio_id: studio.id, user_id: owner.user.id, role: "owner" },
  ]);
  if (membershipError) throw membershipError;

  await anmelden(page, trainerEmail);

  await page.goto("/portal");
  await expect(page).toHaveURL(new RegExp(`/portal/${studio.id}$`));
  await expect(page.getByRole("heading", { name: "Gerätekatalog" })).toBeVisible();
});

test("Trainer richtet ein Studio komplett ueber das Portal ein", async ({ page }) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `portal-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Portal E2E Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin.from("studio_memberships").insert({
    studio_id: studio.id,
    user_id: user.user.id,
    role: "trainer",
  });
  if (membershipError) throw membershipError;

  await anmelden(page, email);

  // Wer in genau einem Studio Trainer ist, landet direkt im Katalog.
  await page.goto("/portal");
  await expect(page).toHaveURL(new RegExp(`/portal/${studio.id}$`));
  await expect(page.getByRole("heading", { name: "Gerätekatalog" })).toBeVisible();

  // 1. Geraetemodell
  await page.getByLabel("Name").fill("Latzug");
  await page.getByLabel("Hersteller").fill("Technogym");
  await page.getByLabel("Gewichtsschritt").fill("2,5");
  await page.getByLabel("Minimum").fill("5");
  await page.getByLabel("Maximum").fill("100");
  await page.getByRole("button", { name: "Modell anlegen" }).click();

  await expect(page.getByRole("link", { name: /Latzug/ }).first()).toBeVisible();
  await page.getByRole("link", { name: "Bearbeiten" }).first().click();
  await expect(page.getByRole("heading", { name: "Latzug" })).toBeVisible();

  // 1b. Foto -- laeuft durch den Server, damit die Aufnahmedaten wegfallen
  await page.getByLabel("Bilddatei").setInputFiles({
    name: "latzug.jpg",
    mimeType: "image/jpeg",
    buffer: jpegMitExif(),
  });
  await page.getByRole("button", { name: "Foto hochladen" }).click();
  await expect(page.getByRole("img", { name: "Foto von Latzug" })).toBeVisible();

  // 2. Einstellparameter
  await page.getByLabel("Schlüssel").fill("sitz");
  await page.getByLabel("Beschriftung").fill("Sitzposition");
  await page.getByLabel("Art").selectOption("number");
  await page.getByLabel("Minimum").last().fill("1");
  await page.getByLabel("Maximum").last().fill("8");
  await page.getByRole("button", { name: "Parameter anlegen" }).click();
  await expect(page.getByText("Sitzposition")).toBeVisible();

  // 3. Uebung samt Reihenfolge
  await page.getByLabel("Name").last().fill("Latzug breit");
  await page.getByLabel("Wiederholungen ab").fill("8");
  await page.getByLabel("bis", { exact: true }).fill("12");
  await page.getByRole("button", { name: "Übung anlegen" }).click();
  await expect(page.getByText("1. Latzug breit")).toBeVisible();
  // Vollstaendigkeit wird nie erzwungen: ohne Video geht es weiter.
  await expect(page.getByText("ohne Video")).toBeVisible();

  // 4. Geraeteinstanz
  await page.getByLabel("Bezeichnung").fill("12");
  await page.getByLabel("Standort").fill("Rückwand links");
  await page.getByRole("button", { name: "Gerät anlegen" }).click();
  await expect(page.getByText("kein aktiver Tag")).toBeVisible();

  // 5. Tag -- er kommt aus der Lieferung und wird vor dem Geraet verbunden.
  const { token } = await tagAnlegen(admin, { studioId: null });

  await page.goto(`/portal/${studio.id}/tags`);
  await page.getByLabel("Token vom Tag").fill(token);
  await page.getByLabel("Gerät auswählen").selectOption({ label: "12 — Latzug" });
  await page.getByRole("button", { name: "Verbinden" }).click();
  await expect(page.getByText("aktiv")).toBeVisible();

  // Das Geraet ist jetzt erreichbar.
  await page.goto(`/portal/${studio.id}/geraete`);
  await expect(page.getByText("Das Gerät in Betrieb ist erreichbar.")).toBeVisible();
  await expect(
    page.getByRole("listitem").filter({ hasText: "Rückwand links" }),
  ).toContainText("erreichbar");

  // Ohne Bearer-Token bleibt der Kontext verschlossen. Der Tag allein reicht
  // nie -- er ist eine Ortsangabe, kein Ausweis (Spec 10.4).
  const ohneAusweis = await page.request.get(`/api/v1/tags/${token}/context`);
  expect(ohneAusweis.status()).toBe(401);

  // Mit Ausweis liefert derselbe Token den Geraete-Screen -- samt Foto als
  // signierter URL, denn der Bucket ist privat.
  const passwort = `e2e-${crypto.randomUUID()}`;
  const { error: passwortFehler } = await admin.auth.admin.updateUserById(
    user.user.id,
    { password: passwort },
  );
  if (passwortFehler) throw passwortFehler;

  const nutzer = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } },
  );
  const { data: sitzung, error: anmeldeFehler } =
    await nutzer.auth.signInWithPassword({ email, password: passwort });
  if (anmeldeFehler) throw anmeldeFehler;

  const kontext = await page.request.get(`/api/v1/tags/${token}/context`, {
    headers: { authorization: `Bearer ${sitzung.session!.access_token}` },
  });
  expect(kontext.status()).toBe(200);

  const inhalt = (await kontext.json()) as {
    machine: { label: string };
    equipmentModel: { name: string; photoUrl: string | null };
    exercises: Array<{ name: string; instructionVideoUrl: string | null }>;
    settingDefinitions: Array<{ key: string }>;
  };
  expect(inhalt.machine.label).toBe("12");
  expect(inhalt.equipmentModel.name).toBe("Latzug");
  expect(inhalt.settingDefinitions.map((s) => s.key)).toContain("sitz");
  expect(inhalt.exercises.map((u) => u.name)).toContain("Latzug breit");
  expect(inhalt.equipmentModel.photoUrl).toContain("token=");
  // Ein Geraet ohne Video bleibt vollstaendig nutzbar (Spec 6.8).
  expect(inhalt.exercises[0]!.instructionVideoUrl).toBeNull();
});
