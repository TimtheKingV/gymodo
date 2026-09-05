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

/** Der Wochentag eines Ortsdatums, 0 = Sonntag -- wie wochentag() in
 * (schreibtisch)/kurse/woche.ts, hier dupliziert (Anwendungscode, kein
 * Testhelfer). */
function ortsWochentag(jahr: number, monat: number, tag: number): number {
  return new Date(Date.UTC(jahr, monat - 1, tag)).getUTCDay();
}

/**
 * Der Montag der laufenden Kalenderwoche, in derselben Zeitzone gerechnet
 * wie wochenFenster() -- unabhaengig davon, an welchem Wochentag dieser
 * Test laeuft.
 */
function montagDieserWoche(zeitzone: string): { jahr: number; monat: number; tag: number } {
  const heute = heutigesOrtsdatum(zeitzone);
  const versatz = (ortsWochentag(heute.jahr, heute.monat, heute.tag) + 6) % 7;
  const montag = new Date(Date.UTC(heute.jahr, heute.monat - 1, heute.tag - versatz));
  return { jahr: montag.getUTCFullYear(), monat: montag.getUTCMonth() + 1, tag: montag.getUTCDate() };
}

/**
 * Mittwoch derselben Woche -- sicher in der Mitte des Fensters, egal an
 * welchem Wochentag der Test laeuft (anders als "heute", das an einem
 * Sonntag kurz vor 23:30 am Fensterrand gelegen haette).
 */
function mittwochDieserWoche(zeitzone: string): { jahr: number; monat: number; tag: number } {
  const montag = montagDieserWoche(zeitzone);
  const mittwoch = new Date(Date.UTC(montag.jahr, montag.monat - 1, montag.tag + 2));
  return {
    jahr: mittwoch.getUTCFullYear(),
    monat: mittwoch.getUTCMonth() + 1,
    tag: mittwoch.getUTCDate(),
  };
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
 * Befund 19 (Fix-Runde 1), geschaerft in Fix-Runde 2: der Satz war zwar
 * sichtbar, stand aber in text-faint (3,6 : 1) -- ein Kontrast, den
 * Designsystem 2 fuer Pflichttext verbietet. "Sichtbar" allein sichert
 * das nicht zu; erst der Farbvergleich tut es. Geprueft wird auf
 * Gleichheit mit dem ERWARTETEN Wert (--text-muted, #9ba3af, im Browser
 * rgb(155, 163, 175)), nicht nur auf Ungleichheit mit dem verbotenen
 * --text-faint (rgb(92, 99, 110)) -- sonst bliebe ein anderer, ebenso zu
 * blasser Ton unentdeckt.
 */
test("Die Produktgrenze steht in text-muted", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-kontrast");
  await page.goto(`/portal/${studioId}`);

  const satz = page.getByText(/gymodo misst nichts/);
  const farbe = await satz.evaluate((el) => getComputedStyle(el).color);
  expect(farbe).toBe("rgb(155, 163, 175)");
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
 * Die eine Zusicherung, die am meisten wert ist (Fix-Runde 1, Befund 1),
 * geschaerft in Fix-Runde 2: Fachschichtabfrage (listCourseWeek),
 * Fensterberechnung (wochenFenster) und Zeitzonenformatierung greifen
 * hier gemeinsam ineinander. Die Studio-Zeitzone ist bewusst weder
 * Europe/Berlin (der Default) noch UTC (die Zeitzone der Datenbank) --
 * ein Fehler, der Ortszeit mit Serverzeit verwechselt, faellt sonst nur
 * an einer Testmaschine auf, deren lokale Zeitzone zufaellig
 * uebereinstimmt.
 *
 * Der Termin liegt bewusst um 23:30 Ortszeit, nicht um 10 Uhr: America/
 * New_York ist im September UTC-4, und 23:30 Ortszeit faellt damit auf
 * 03:30 UTC des naechsten Tages -- Kalendertag UND Wochentag
 * unterscheiden sich zwischen den Zonen. Eine Implementierung, die das
 * Datum still gegen UTC statt gegen die Studio-Zeitzone formatiert,
 * zeigte hier den falschen Wochentag und das falsche Datum; bei einem
 * Termin um 10 Uhr waere der Kalendertag in beiden Zonen derselbe
 * gewesen, und der Fehler waere unentdeckt geblieben.
 *
 * Mittwoch dieser Woche, nicht "heute": 23:30 an einem Sonntag laege am
 * Fensterrand (Fix-Runde 2, Befund 2). Mittwoch ist an jedem
 * Wochentag, an dem dieser Test laeuft, sicher innerhalb der Woche.
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

  const { jahr, monat, tag } = mittwochDieserWoche(zeitzone);
  const beginn = ortszeitZuInstant({ jahr, monat, tag, stunde: 23, minute: 30 }, zeitzone);

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
    page.getByText(`${datumOrtszeit} · 23:30 · Kraftzirkel`),
  ).toBeVisible();
  await expect(page.getByText(/Marek T\. · Kursraum 2/)).toBeVisible();
});

test("Ein Mitglied sieht die Geräteliste nicht", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "geraete-recht");
  await page.goto(`/portal/${studioId}/geraete`);

  await expect(page.getByRole("heading", { name: "Geräte" })).toBeVisible();
  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
});

test("Die Bedienelemente der Geräteliste sind gross genug", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "geraete-treffer");
  await page.goto(`/portal/${studioId}/geraete`);

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu klein: ${zuKlein.join(", ")}`).toHaveLength(0);
});

/**
 * Aufgabe 16: die alte Modellseite (371 Zeilen, fuenf Abschnitte) zerfaellt
 * in vier Reiter -- Stammdaten, Einstellungen, Uebungen, Einzelne Geraete.
 * Nur der erste entsteht in dieser Aufgabe; die anderen drei liefern
 * Aufgabe 17 und 18.
 */
test("Das Modell zeigt vier Reiter, und jeder traegt seinen Zustand", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-reiter");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", manufacturer: "Technogym", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}`);

  const reiter = page.getByRole("navigation", { name: "Modell" });
  for (const name of ["Stammdaten", "Einstellungen", "Übungen", "Einzelne Geräte"]) {
    await expect(reiter.getByRole("link", { name: new RegExp(name) })).toBeVisible();
  }
  await expect(reiter.getByRole("link", { name: /Stammdaten/ })).toHaveAttribute(
    "aria-current",
    "page",
  );
});

/**
 * Der eigentliche Punkt dieses Abschnitts: auf der alten, einteiligen
 * Modellseite war dieser Test fuenffach rot (fuenf Formulare, fuenf
 * Akzentflaechen auf einem Bildschirm). Er laeuft schon jetzt ueber alle
 * vier Reiter-Pfade, obwohl drei davon erst in Aufgabe 17 und 18 entstehen
 * -- bis dahin scheitert er dort am 404 (0 Akzentflaechen), was die Zusage
 * "hoechstens eine" ebenso erfuellt.
 */
test("Jeder Modellreiter traegt genau eine Akzentflaeche -- ein Formular je Bildschirm", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-akzent");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beinpresse", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  for (const reiter of ["", "/einstellungen", "/uebungen", "/instanzen"]) {
    await page.goto(`/portal/${studioId}/geraete/${modell.id}${reiter}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen.length,
      `Reiter "${reiter || "Stammdaten"}" traegt ${flaechen.length}: ${flaechen.join(", ")}`,
    ).toBeLessThanOrEqual(1);
  }
});

/**
 * modelle/[modelId] ist seit Aufgabe 16 eine Weiterleitung, nach demselben
 * Muster wie /modelle -> /geraete aus Aufgabe 13.
 */
test("Der alte Modellpfad fuehrt auf den neuen", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-alt");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/modelle/${modell.id}`);
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/${modell.id}$`));
});
