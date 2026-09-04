import { expect, test } from "@playwright/test";
import { ortszeitZuInstant } from "@fitretro/domain";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";

/**
 * "Heute" als Kalenderdatum in einer beliebigen Zeitzone -- ohne die
 * lokale, nicht exportierte ortszeitAlsDatum aus (schreibtisch)/kurse/woche.ts
 * zu importieren (Anwendungscode, kein Testhelfer). en-CA liefert
 * YYYY-MM-DD direkt aus formatToParts, ohne String-Zusammenbau nach
 * Feldreihenfolge.
 */
function heutigesOrtsdatum(zeitzone: string): { jahr: number; monat: number; tag: number } {
  const teile = new Intl.DateTimeFormat("en-CA", {
    timeZone: zeitzone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const wert = (typ: string) => Number(teile.find((t) => t.type === typ)!.value);
  return { jahr: wert("year"), monat: wert("month"), tag: wert("day") };
}

test("Ein frisches Studio zeigt keine vier Nullen, sondern einen Anfang", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-leer");
  await page.goto(`/portal/${studioId}`);

  // Designsystem 5: nie eine leere Statistik mit Nullen.
  await expect(page.getByText(/Noch nichts zu zählen/)).toBeVisible();
  await expect(page.getByText("Mitglieder aktiv")).toHaveCount(0);
});

test("Der Ueberblick nennt die Produktgrenze und die Datenschutzgrenze", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-grenzen");
  await page.goto(`/portal/${studioId}`);

  await expect(page.getByText(/gymodo misst nichts/)).toBeVisible();
});

/**
 * Befund 19 (Fix-Runde 1): der Satz war zwar sichtbar, stand aber in
 * text-faint (3,6 : 1) -- ein Kontrast, den Designsystem 2 fuer
 * Pflichttext verbietet. "Sichtbar" allein sichert das nicht zu; erst
 * der Farbvergleich tut es. --text-faint ist #5c636e, im Browser
 * rgb(92, 99, 110) (siehe AKZENT in helpers/abnahme.ts fuer denselben
 * Vergleichsweg mit --accent).
 */
test("Die Produktgrenze steht nicht im verbotenen Kontrast", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-kontrast");
  await page.goto(`/portal/${studioId}`);

  const satz = page.getByText(/gymodo misst nichts/);
  const farbe = await satz.evaluate((el) => getComputedStyle(el).color);
  expect(farbe).not.toBe("rgb(92, 99, 110)");
});

test("Ein Mitglied sieht den Ueberblick nicht, aber auch keinen Absturz", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "ueberblick-recht");
  await page.goto(`/portal/${studioId}`);

  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
  await expect(page.getByText(/in der App, nicht hier/)).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});

test("Der Ueberblick traegt hoechstens eine Akzentflaeche", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-akzent");
  await page.goto(`/portal/${studioId}`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen.length, `Akzentflaechen: ${flaechen.join(", ")}`).toBeLessThanOrEqual(1);
});

/**
 * Die eine Zusicherung, die am meisten wert ist (Fix-Runde 1, Befund 1):
 * Fachschichtabfrage (listCourseWeek), Fensterberechnung (wochenFenster)
 * und Zeitzonenformatierung greifen hier gemeinsam ineinander. Die
 * Studio-Zeitzone ist bewusst weder Europe/Berlin (der Default) noch UTC
 * (die Zeitzone der Datenbank) -- ein Fehler, der Ortszeit mit
 * Serverzeit verwechselt, faellt sonst nur an einer Testmaschine auf,
 * deren lokale Zeitzone zufaellig uebereinstimmt.
 */
test("Ein Kurstermin dieser Woche erscheint mit Datum und Uhrzeit in der Studio-Zeitzone", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "ueberblick-woche");
  const zeitzone = "America/New_York";

  const { error: zeitzoneFehler } = await admin
    .from("studios")
    .update({ timezone: zeitzone })
    .eq("id", studioId);
  if (zeitzoneFehler) throw zeitzoneFehler;

  const { data: vorlage, error: vorlageFehler } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: "Kraftzirkel",
      default_duration_min: 60,
      default_capacity: 16,
    })
    .select("id")
    .single();
  if (vorlageFehler) throw vorlageFehler;

  // "Heute, 10 Uhr Ortszeit" liegt an jedem Wochentag im Montag-Sonntag-
  // Fenster der laufenden Kalenderwoche -- unabhaengig davon, an welchem
  // Wochentag dieser Test laeuft.
  const { jahr, monat, tag } = heutigesOrtsdatum(zeitzone);
  const beginn = ortszeitZuInstant({ jahr, monat, tag, stunde: 10, minute: 0 }, zeitzone);

  const { error: terminFehler } = await admin.from("course_sessions").insert({
    studio_id: studioId,
    course_template_id: vorlage!.id,
    starts_at: beginn.toISOString(),
    duration_min: 60,
    capacity: 16,
    room: "Kursraum 2",
    instructor_name: "Marek T.",
  });
  if (terminFehler) throw terminFehler;

  await page.goto(`/portal/${studioId}`);

  // Derselbe Weg wie die Seite selbst (toLocaleDateString mit
  // weekday/day/month/year, in der Studio-Zeitzone) -- ein hartkodiertes
  // Datum waere an einem anderen Testlauftag falsch.
  const datumOrtszeit = beginn.toLocaleDateString("de-DE", {
    weekday: "short",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: zeitzone,
  });
  await expect(
    page.getByText(`${datumOrtszeit} · 10:00 · Kraftzirkel`),
  ).toBeVisible();
  await expect(page.getByText(/Marek T\. · Kursraum 2/)).toBeVisible();
});
