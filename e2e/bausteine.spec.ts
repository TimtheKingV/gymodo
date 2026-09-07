import { expect, test } from "@playwright/test";
import {
  akzentflaechen,
  fehlermeldung,
  hauptlandmarken,
  zuKleineBedienelemente,
} from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";
import { tagsAnlegen } from "../tests/helpers/tags";

/**
 * Die Landmarke ist die einzige der drei Abnahmen, die heute schon rot ist.
 *
 * Betroffen sind vier der sechs geprueften Seiten -- die, die ein eigenes
 * <main className={styles.content}> im <main> des Layouts rendern:
 * (schreibtisch)/page.tsx, leute, einstellungen und einstellungen/konto.
 * Die uebrigen zwei, geraete und tags, tragen an derselben Stelle ein
 * <div> und liefern heute schon 1.
 *
 * Geprueft werden trotzdem alle sechs: nach Aufgabe 4 gehoert die
 * Landmarke dem Layout allein, und dann muss jede Seite genau eine haben --
 * auch die, die vorher unauffaellig waren. Der Lauf bricht beim ersten
 * Fehlschlag ab, deshalb belegt ein roter Lauf nur den ersten Fall, nicht
 * alle vier.
 */
test("Jede Schreibtischseite hat genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-landmarke");

  for (const pfad of ["", "/geraete", "/tags", "/leute", "/einstellungen", "/einstellungen/konto"]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});

/**
 * Aufgabe 5: die Tags-Seite als Referenz. Sie hat keine Hauptaktion und
 * traegt deshalb keine Akzentflaeche -- die ungewoehnlichste Akzentzahl im
 * Portal (Canvas-Notiz note-akzent).
 */
test("Die Tags-Seite traegt keine Akzentflaeche -- sie legt nichts an", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags");
  await page.goto(`/portal/${studioId}/tags`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `zu viele Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(0);
});

test("Ein Studio ohne Tags sagt, was zu tun ist, statt eine leere Liste zu zeigen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-leer");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByText("Noch keine Lieferung")).toBeVisible();
  // fehlermeldung() statt [role=alert]: Next legt einen leeren
  // Route-Announcer mit role="alert" ins Dokument, und er entsteht erst,
  // wenn der Client uebernimmt. Wer roh zaehlt, misst deshalb die
  // Tagesform der Maschine -- isoliert ist die Pruefung schneller da als
  // der Announcer und zaehlt 0, im vollen Lauf ist sie langsamer und
  // zaehlt 1. Am 6. September genau so aufgetreten.
  await expect(fehlermeldung(page)).toHaveCount(0);
});

test("Ein Mitglied sieht auf der Tags-Seite einen Satz, keinen Absturz", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "abnahme-tags-recht");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByRole("heading", { name: "Tags" })).toBeVisible();
  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
});

test("Die Bedienelemente der Tags-Seite sind gross genug zum Treffen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-treffer");
  await page.goto(`/portal/${studioId}/tags`);

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu kleine Bedienelemente: ${zuKlein.join(", ")}`).toHaveLength(0);
});

/**
 * Fix-Runde 2, Befund 1: ein vorraetiger (unassigned) Tag ist keinem Geraet
 * zugeordnet -- der Vorrats-Absatz zwei Abschnitte weiter unten begruendet
 * woertlich, warum er trotzdem nicht als eigene Zeile auftaucht. Vor dem Fix
 * stand er als "ohne Geraet"-Zeile mit dem unuebersetzten Abzeichen
 * "UNASSIGNED" unter "Vergebene Geraete-Tags".
 */
test("Vergebene Geraete-Tags zeigt nur vergebene Tags, keine vorraetigen", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "abnahme-tags-vorrat");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Testmodell", weight_step_kg: 2.5 })
    .select("id")
    .single<{ id: string }>();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "1" })
    .select("id")
    .single<{ id: string }>();
  if (geraetFehler) throw geraetFehler;

  // Ein vergebener Tag, dazu drei vorraetige -- die Lage aus dem
  // Sichtpruefungs-Seed, die Befund 1 aufgedeckt hat.
  await tagsAnlegen(admin, [
    { studioId, machineId: geraet.id, kind: "machine", status: "active" },
    ...Array.from({ length: 3 }, () => ({
      studioId,
      kind: "machine" as const,
      status: "unassigned" as const,
    })),
  ]);

  await page.goto(`/portal/${studioId}/tags`);

  // getByText allein traf auch die <option> im "Gerät auswählen"-Select der
  // TagBinden-Sektion -- die Zeile ist ein <li> (Zeile-Baustein), also darauf
  // eingrenzen.
  await expect(page.getByRole("listitem").filter({ hasText: "1 — Testmodell" })).toBeVisible();
  await expect(page.getByText("ohne Gerät")).toHaveCount(0);
  await expect(page.getByText("UNASSIGNED")).toHaveCount(0);
});
