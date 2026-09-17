import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { auswaehlen } from "./helpers/auswahl";
import { E2E_PASSWORD, anmelden } from "./helpers/login";
import { radWaehlen } from "./helpers/rad";
import { tagAnlegen } from "../tests/helpers/tags";

/**
 * Verifikationspunkt 5 aus dem Plan: ein Studio komplett ueber die
 * Oberflaeche einrichten -- Modell, Einstellung, Uebung, Geraet, Tag -- und
 * danach pruefen, dass der Geraete-Screen den Kontext bekommt.
 *
 * Das Einweisungsvideo bleibt hier aussen vor: sein Upload laeuft per TUS
 * direkt gegen den Storage-Dienst und wird in tests/integration abgedeckt
 * (domain-media.test.ts). Was dieser Test beweist, ist der Weg des Trainers
 * durch die Oberflaeche.
 *
 * Aufgabe 16: die Modellseite ist in vier Reiter zerfallen (Stammdaten,
 * Einstellungen, Uebungen, Einzelne Geraete). Nur Stammdaten samt Foto
 * entsteht in dieser Aufgabe; die anderen drei Reiter liefern Aufgabe 17
 * und 18. Bis dahin legt dieser Test Parameter, Uebung und Geraeteinstanz
 * direkt in der Datenbank an statt ueber die (noch nicht existierende)
 * Oberflaeche -- der Weg des Trainers durch Stammdaten, Foto und Tag bleibt
 * ueber die Oberflaeche geprueft, der Rest wird geprueft, sobald sein Reiter
 * steht.
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
 * memberships_select_staff (0031) laesst Mitarbeiter alle Mitgliedschaften
 * ihres Studios sehen, nicht nur die eigene -- die Portal-Einstiegsseite
 * muss ihre Abfrage seither selbst auf den Aufrufer filtern, sonst kommt
 * fuer einen Trainer in einem Studio mit weiterem Personal (hier: einem
 * Inhaber) dieselbe Studio-Zeile doppelt zurueck, und der Redirect fuer
 * "genau ein Studio" bleibt aus.
 */
test("Trainer in einem Studio mit weiterem Personal landet trotzdem direkt im Überblick", async ({
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
  await expect(page.getByRole("heading", { name: "Überblick" })).toBeVisible();
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

  // Wer in genau einem Studio Trainer ist, landet direkt im Ueberblick.
  await page.goto("/portal");
  await expect(page).toHaveURL(new RegExp(`/portal/${studio.id}$`));
  await expect(page.getByRole("heading", { name: "Überblick" })).toBeVisible();

  // Der Katalog liegt seit dem Ueberblick unter /modelle -- seit Aufgabe 13
  // ist das eine Weiterleitung auf /geraete, den zusammengelegten Bereich
  // aus Geraeten und Modellen (Struktur-Spec, Entscheidung 5).
  await page.goto(`/portal/${studio.id}/modelle`);
  await expect(page.getByRole("heading", { name: "Geräte", exact: true })).toBeVisible();

  // 1. Geraetemodell
  await page.getByLabel("Name").fill("Latzug");
  await page.getByLabel("Hersteller").fill("Technogym");
  await radWaehlen(page, "Schritt", "2,5");
  await radWaehlen(page, "Minimum", "5");
  await radWaehlen(page, "Maximum", "100");
  await page.getByRole("button", { name: "Modell anlegen" }).click();

  // Anlegen fuehrt zum Angelegten: der Schreibtisch blieb frueher auf der
  // Liste stehen, und das neue Modell war eine Zeile unter anderen. Kein
  // Klick auf "Bearbeiten" mehr -- die Weiterleitung IST der Befund.
  await expect(page.getByRole("heading", { name: "Latzug" })).toBeVisible();

  // Und die Seite sagt, was als Naechstes fehlt, statt vier Nullen in der
  // Reiterleiste zu zeigen. Das Foto steht oben, weil ohne es niemand das
  // Geraet wiedererkennt.
  const nochZuTun = page.getByRole("list", { name: "Noch zu tun" });
  await expect(nochZuTun.getByRole("listitem").first()).toContainText("Kein Foto");
  await expect(nochZuTun.getByRole("listitem")).toHaveCount(4);

  // Der Modell-Detailpfad ist seit Aufgabe 16 /geraete/<modelId> (vier
  // Reiter statt fuenf Abschnitte auf einem Bildschirm); die Modell-Id
  // steht jetzt nur noch in der URL, nicht mehr in einem Formularfeld.
  const modelId = new URL(page.url()).pathname.split("/").pop()!;

  // 1b. Foto -- laeuft durch den Server, damit die Aufnahmedaten wegfallen.
  // Stammdaten und Foto teilen sich seit Aufgabe 16 eine Akzentflaeche
  // ("Änderungen speichern" statt vormals "Foto hochladen") -- ein Reiter,
  // ein Formular (Struktur-Spec Abschnitt 1).
  await page.getByLabel("Bilddatei").setInputFiles({
    name: "latzug.jpg",
    mimeType: "image/jpeg",
    buffer: jpegMitExif(),
  });
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(page.getByRole("img", { name: "Foto von Latzug" })).toBeVisible();

  // 2. Einstellungen und 3. Uebung -- ueber ihre Reiter, nicht ueber
  // die Datenbank. Bis Aufgabe 17 und 18 gab es die Reiter nicht, und
  // dieser Test hat beides direkt eingefuegt, mit der Notiz "sobald die
  // Reiter stehen, gehoert das wieder ueber die Oberflaeche geprueft".
  // Sie stehen seit 5c87922 und 48d6b6b.
  //
  // Der Unterschied ist nicht kosmetisch: die beiden ANLEGE-Formulare
  // waren bis hier von keinem E2E-Test beruehrt. schreibtisch.spec.ts
  // prueft die Leerzustaende beider Reiter und das Umordnen -- und legt
  // dafuer selbst per Datenbank an. Der Weg, den ein Trainer wirklich
  // geht, lief also nirgends durch.
  await page.goto(`/portal/${studio.id}/geraete/${modelId}/einstellungen`);
  await page.getByLabel("Beschriftung").fill("Sitzposition");
  await auswaehlen(page, page.getByRole("button", { name: "Art" }), "Zahl mit Bereich");
  await radWaehlen(page, "Minimum", "1");
  await radWaehlen(page, "Maximum", "8");
  await page.getByRole("button", { name: "Einstellung anlegen" }).click();

  // Warten, bis die Aktion GEANTWORTET hat -- und erst dann urteilen.
  //
  // Die Fassung davor wartete auf "Zeile ODER Meldung" und schlug zu,
  // sobald irgendein Element mit role="alert" auf der Seite stand. Der
  // Abzug aus Lauf 35267333125 zeigt, was das anrichtete: unten im
  // Formular stand `button "Wird gespeichert …" [disabled]` -- der
  // Absendeknopf war noch im Lauf. Der Test hat also den Zwischenstand
  // fotografiert und ihn fuer das Ergebnis gehalten. Zwei Runden
  // Spurensuche haben damit vor allem die eigene Ungeduld vermessen.
  //
  // Der Knopf ist das ehrliche Signal: waehrend der Aktion heisst er
  // "Wird gespeichert …" und ist gesperrt (Form.tsx, useFormStatus).
  // Traegt er wieder seinen Namen, ist das Ergebnis da -- ob Zeile oder
  // Meldung, entscheidet sich danach.
  const absenden = page.getByRole("button", { name: "Einstellung anlegen" });
  await expect(absenden).toBeEnabled();

  const einstellungen = page.getByRole("list", { name: "Einstellungen am Modell" });
  const zeilen = await einstellungen.getByRole("listitem").count();
  if (zeilen === 0) {
    // Der Abzug kommt in die Fehlermeldung, weil die error-context.md im
    // Artefakt aus der Arbeitsumgebung nicht ladbar ist (Egress-Policy).
    // Ohne die option-Zeilen: die beiden Raeder tragen je 200 Werte, und
    // 400 Zeilen Rauschen verdecken die Auskunft.
    const meldungen = page.getByRole("alert");
    const abzug = (await page.getByRole("main").ariaSnapshot())
      .split("\n")
      .filter((zeile) => !/^\s*- option "/.test(zeile))
      .join("\n");
    throw new Error(
      [
        "Einstellung nicht angelegt: die Liste ist leer, nachdem die Aktion geantwortet hat.",
        `Meldungen (${await meldungen.count()}): ${JSON.stringify(await meldungen.allInnerTexts())}`,
        `Seite:\n${abzug}`,
      ].join("\n"),
    );
  }

  await expect(einstellungen).toContainText("Sitzposition");

  await page.goto(`/portal/${studio.id}/geraete/${modelId}/uebungen`);
  await page.getByLabel("Name").fill("Latzug breit");
  await radWaehlen(page, "Wiederholungen ab", "8");
  await radWaehlen(page, "bis", "12");
  await page.getByRole("button", { name: "Übung anlegen" }).click();
  await expect(page.getByText("Latzug breit")).toBeVisible();

  // 4. Geraeteinstanz -- weiter ueber die Datenbank. Ihr Reiter legt
  // Geraete an, aber der Weg dorthin ist der Gang durch die Halle
  // (einrichten/), und den prueft einrichten.spec.ts in voller Laenge.
  // Hier waere er eine zweite Kopie, keine zweite Zusicherung.

  const { error: geraetFehler } = await admin.from("machines").insert({
    studio_id: studio.id,
    equipment_model_id: modelId,
    label: "12",
    location_note: "Rückwand links",
  });
  if (geraetFehler) throw geraetFehler;

  // 5. Tag -- er kommt aus der Lieferung und wird vor dem Geraet verbunden.
  const { token } = await tagAnlegen(admin, { studioId: null });

  await page.goto(`/portal/${studio.id}/tags`);
  await page.getByLabel("Token vom Tag").fill(token);
  await auswaehlen(page, page.getByLabel("Gerät auswählen"), "12 — Latzug");
  await page.getByRole("button", { name: "Verbinden" }).click();
  await expect(page.getByText("aktiv")).toBeVisible();

  // Das Geraet ist jetzt erreichbar. Die Zeile "Geräte im Raum -- 1 aktiver
  // Tag" lebt seit Aufgabe 16 im Reiter Einzelne Geräte (Aufgabe 18) und
  // steht bis dahin nirgends. Der Geraete-Screen-Kontext weiter unten
  // ersetzt sie NICHT: getTagContext fragt machine_tags direkt ueber den
  // Token-Hash ab (packages/domain/src/tag-context.ts), waehrend die
  // gestrichene Zusicherung die Aggregation des Portals prueft
  // (activeTagCount aus getStudioCatalog, gebuendelt in erreichbarkeit()).
  // Zwei Codepfade, zwei Fehlerquellen. Ersetzt wird sie deshalb wie in
  // einrichten.spec.ts durch die Aggregatanzeige auf /geraete -- dieselbe
  // Groesse, dieselbe Rechnung, nur an der Stelle, wo sie heute steht.
  await page.goto(`/portal/${studio.id}/geraete`);
  await expect(
    page.getByRole("listitem").filter({ hasText: "Latzug" }),
  ).toContainText("1 Gerät, 1 erreichbar");

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
  // Der Schluessel kommt seit dem Wegfall des eigenen Schluesselfelds aus
  // schluesselAus("Sitzposition") -- ein Slug der Beschriftung, kein
  // getipptes Kuerzel mehr.
  expect(inhalt.settingDefinitions.map((s) => s.key)).toContain("sitzposition");
  expect(inhalt.exercises.map((u) => u.name)).toContain("Latzug breit");
  expect(inhalt.equipmentModel.photoUrl).toContain("token=");
  // Ein Geraet ohne Video bleibt vollstaendig nutzbar (Spec 6.8).
  expect(inhalt.exercises[0]!.instructionVideoUrl).toBeNull();
});
