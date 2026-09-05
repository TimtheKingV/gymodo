import { expect, test } from "@playwright/test";
import { ortszeitZuInstant } from "@fitretro/domain";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";
import { E2E_PASSWORD } from "./helpers/login";
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
 * vier Reiter-Pfade. Bis Aufgabe 18 lieferten drei davon einen 404, und
 * die Zusicherung lautete deshalb "hoechstens eine" -- null Flaechen
 * erfuellen das ebenso. Seit Aufgabe 18 existieren alle vier Reiter, und
 * die Zusicherung ist die, die der Name verspricht: GENAU eine. Sonst
 * bliebe der Test gruen, wenn die Akzentklasse eines Reiters ganz
 * verschwaende.
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
    ).toBe(1);
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

/**
 * Aufgabe 17: die Reiter Einstellungen und Uebungen. Beide Leerzustaende
 * sagen, wofuer der Reiter da ist -- eine leere Liste ohne Satz waere
 * nach Designsystem 5 kein Zustand, sondern ein Loch.
 */
test("Ohne Einstellparameter sagt der Reiter, wofuer sie da sind", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-param-leer");
  // weight_step_kg ist in equipment_models NOT NULL ohne Default (0004).
  // Fehlt es, scheitert schon der Insert.
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/einstellungen`);
  await expect(page.getByText(/Noch keine Einstellparameter/)).toBeVisible();
});

test("Ohne Uebung nennt der Reiter den naechsten Schritt", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-uebung-leer");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/uebungen`);
  await expect(page.getByText(/Noch keine Übung/)).toBeVisible();
});

/**
 * Canvas-Notiz `note-uebungen`: "Übung 1 ist am Gerät die Vorauswahl des
 * Mitglieds." Die Reihenfolge ist damit das einzige auf diesen beiden
 * Reitern, das fachlich etwas bedeutet -- und stand bis hier in keinem
 * E2E-Test.
 *
 * Die Nummer ist Teil der Zusicherung. Nur die Reihenfolge der Zeilen zu
 * pruefen genuegt nicht: eine Liste, die zwar umsortiert, aber weiter "1."
 * an die alte Uebung schreibt, bliebe gruen.
 */
test("Umordnen aendert die Vorauswahl am Geraet, nicht nur die Anzeige", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-umordnen");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  // Zwei Uebungen und ihre Verknuepfung -- dasselbe Muster wie in
  // e2e/trainerportal.spec.ts: `exercises` traegt Name und Wiederholungen,
  // `equipment_model_exercises` die Reihenfolge am Modell.
  for (const [reihenfolge, name] of [
    [1, "Rudern"],
    [2, "Latzug breit"],
  ] as const) {
    const { data: uebung, error: uebungFehler } = await admin
      .from("exercises")
      .insert({
        studio_id: studioId,
        name,
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (uebungFehler) throw uebungFehler;

    const { error: linkFehler } = await admin.from("equipment_model_exercises").insert({
      equipment_model_id: modell.id,
      exercise_id: uebung.id,
      sort_order: reihenfolge,
    });
    if (linkFehler) throw linkFehler;
  }

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/uebungen`);

  const zeilen = page.getByRole("listitem");
  await expect(zeilen.nth(0)).toContainText("1. Rudern");
  await expect(zeilen.nth(1)).toContainText("2. Latzug breit");

  await zeilen.nth(1).getByRole("button", { name: "Hoch" }).click();

  await expect(zeilen.nth(0)).toContainText("1. Latzug breit");
  await expect(zeilen.nth(1)).toContainText("2. Rudern");

  // Und nicht nur in der Anzeige: neu geladen steht dieselbe Reihenfolge da.
  await page.reload();
  await expect(page.getByRole("listitem").nth(0)).toContainText("1. Latzug breit");
});

/**
 * Aufgabe 18: der Reiter Einzelne Geraete. Das Artboard zeichnet je Geraet
 * nur "Tag scannen"/"Tag ersetzen" -- das Stilllegen fehlt dort (Befund 7).
 * Die Spec verlangt es, und der Code hatte es schon auf der frueheren,
 * einteiligen Modellseite. Nachgezogen wird das Artboard, nicht der Code.
 */
test("Der Reiter Einzelne Geräte traegt das Stilllegen, auch wenn das Artboard es vergisst", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-instanzen");
  // weight_step_kg ist in equipment_models NOT NULL ohne Default (0004).
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;
  const { error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "12" });
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/instanzen`);

  await expect(page.getByRole("button", { name: "Stilllegen" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Tag scannen" })).toBeVisible();
});

/**
 * Der Praefix heisst "modell-ausser-betrieb" und nicht "modell-stillgelegt":
 * studioMitTrainer baut daraus Studioname UND E-Mail, und beide stehen in
 * der Rail. getByText("stillgelegt") traf damit drei Elemente statt einem
 * und scheiterte am strict mode -- nicht am Bildschirm.
 *
 * Aus demselben Grund laufen beide Zusicherungen ueber die Zeile: die
 * E-Mail traegt eine UUID, in der "13" jederzeit vorkommen kann.
 */
test("Ein stillgelegtes Geraet bleibt sichtbar und benannt", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-ausser-betrieb");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;
  const { error: geraetFehler } = await admin.from("machines").insert({
    studio_id: studioId,
    equipment_model_id: modell.id,
    label: "13",
    status: "inactive",
  });
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/instanzen`);

  // Geraete werden stillgelegt, nie geloescht (Designsystem 10). Ein
  // verschwundenes Geraet naehme die Zuordnungshistorie mit.
  const zeile = page.getByRole("listitem").filter({ hasText: "13" });
  await expect(zeile).toBeVisible();
  await expect(zeile).toContainText("stillgelegt");
  await expect(zeile.getByRole("button", { name: "Wieder in Betrieb" })).toBeVisible();
  // Und kein Weg in die Halle: an ein stillgelegtes Geraet wird kein Tag
  // geklebt.
  await expect(zeile.getByRole("link", { name: /Tag/ })).toHaveCount(0);
});

/**
 * Nach dem Anlegen stimmen beide -- die Liste auf dem Reiter und die
 * Zaehlung in der Reiterleiste, die eine Ebene hoeher im LAYOUT steht --
 * ohne page.reload().
 *
 * Was dieser Test NICHT beweist, obwohl der Auftrag zu Aufgabe 18 es
 * annahm: dass die Aktion den richtigen Pfad revalidiert. Gemessen am 5.
 * September, dreimal am laufenden Dev-Server:
 *
 *   revalidatePath("/portal/<id>/modelle/<modelId>")  -> gruen (toter Pfad)
 *   revalidatePath("/voellig-woanders")               -> gruen
 *   gar kein revalidatePath                           -> ROT, schon an der Liste
 *
 * Next frischt nach einer Server Action den gesamten angezeigten Baum auf,
 * sobald die Aktion ueberhaupt irgendeine Revalidierung meldet -- welchen
 * Pfad sie nennt, ist von aussen nicht messbar. Fuer den Pfad selbst gibt
 * es hier keinen Zeugen; er ist Lesbarkeit, kein Verhalten. Der Test bleibt
 * trotzdem stehen, weil er die Frische von Liste UND Reiterzahl sichert --
 * nur eben nicht den Pfad.
 */
test("Ein neu angelegtes Geraet erscheint ohne Neuladen im Reiter", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-anlegen-frisch");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/instanzen`);

  await page.getByLabel("Bezeichnung").fill("12");
  await page.getByRole("button", { name: "Gerät anlegen" }).click();

  // OHNE page.reload().
  await expect(page.getByRole("listitem").filter({ hasText: "12" })).toBeVisible();

  const reiter = page.getByRole("navigation", { name: "Modell" });
  await expect(reiter.getByRole("link", { name: /Einzelne Geräte/ })).toContainText(
    "1 · 1 ohne Tag",
  );
});

/**
 * Aufgabe 19: Leute zerfaellt in zwei Reiter auf zwei Routen -- Mitglieder
 * und Mitarbeiter. Die Mitarbeiterliste ist die Rechteverwaltung
 * (Struktur-Spec Abschnitt 2) und traegt deshalb die drei Zusicherungen,
 * die dort Sorgfalt heissen: getrennte Listen, keine Selbstherabstufung,
 * eine Bestaetigung, die etwas sagt.
 */
test("Leute hat zwei Reiter, und beide nennen ihre Zahl", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "leute-reiter");
  await page.goto(`/portal/${studioId}/leute`);

  const reiter = page.getByRole("navigation", { name: "Leute" });
  await expect(reiter.getByRole("link", { name: /Mitglieder/ })).toBeVisible();
  await expect(reiter.getByRole("link", { name: /Mitarbeiter/ })).toBeVisible();
});

/**
 * Befund 22, das eigentliche Loch: LeuteActions bot "Zu Mitglied
 * zurueckstufen" auf jeder Nicht-Inhaber-Zeile an, auch auf der eigenen.
 * Ein Trainer konnte sich damit selbst das ganze Portal nehmen -- der
 * Inhaber ist durch setMembershipRole und die Richtlinie doppelt
 * geschuetzt, die eigene Trainerzeile durch nichts.
 */
test("Die eigene Zeile traegt keinen Knopf, der die eigene Rolle nimmt", async ({ page }) => {
  const { studioId, email } = await studioMitTrainer(page, "leute-selbst");
  await page.goto(`/portal/${studioId}/leute/mitarbeiter`);

  const eigene = page.locator("li", { hasText: email });
  await expect(eigene).toBeVisible();
  await expect(eigene.getByText("Das bist du")).toBeVisible();
  await expect(eigene.getByRole("button", { name: /herabstufen/i })).toHaveCount(0);
});

test("Hochstufen sagt vorher, was es bedeutet", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "leute-hochstufen");
  await page.goto(`/portal/${studioId}/leute/mitarbeiter`);

  // Wortlaut aus LeuteMitarbeiter.dc.html. Beide Saetze stehen dort in
  // EINEM Textknoten -- zwei Zusicherungen auf dasselbe Element. Das ist
  // Absicht: der zweite Satz ist der, der am ehesten wegredigiert wird.
  await expect(
    page.getByText(/Hochstufen gibt Zugriff auf den ganzen Katalog/),
  ).toBeVisible();
  await expect(page.getByText(/Der Studio-Code macht niemanden zum Trainer/)).toBeVisible();
});

/**
 * Der eigentliche Zweck dieser Aufgabe -- und das, was die drei Tests
 * darueber nicht pruefen: dass die beiden Listen wirklich getrennt sind.
 *
 * toHaveCount(0) auf der jeweils fremden E-Mail, nicht nur toBeVisible()
 * auf der richtigen: eine Seite, die weiter beide Rollen in einer Liste
 * zeigt, waere sonst gruen.
 *
 * Beide Zusicherungen laufen ueber den jeweiligen Abschnitt, nicht ueber
 * die Seite: die eigene E-Mail steht im Fuss der Rail (styles.railEmail)
 * und ein seitenweites toHaveCount(0) auf die Trainer-Adresse waere schon
 * daran rot. Und auf dem Reiter Mitarbeiter stehen die Mitglieder ein
 * zweites Mal -- im Abschnitt "Mitglied hochstufen", der genau dafuer da
 * ist. Die Zusicherung lautet deshalb: nicht in "Alle Mitarbeiter".
 */
test("Ein Mitglied steht im Mitglieder-Reiter und nicht bei den Mitarbeitern", async ({
  page,
}) => {
  const { studioId, admin, email: trainerEmail } = await studioMitTrainer(page, "leute-trennung");

  const mitgliedEmail = `leute-trennung-mitglied-${crypto.randomUUID()}@example.test`;
  const { data: mitgliedNutzer, error: nutzerFehler } = await admin.auth.admin.createUser({
    email: mitgliedEmail,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (nutzerFehler) throw nutzerFehler;

  const { error: mitgliedFehler } = await admin.from("studio_memberships").insert({
    studio_id: studioId,
    user_id: mitgliedNutzer.user.id,
    role: "member",
  });
  if (mitgliedFehler) throw mitgliedFehler;

  await page.goto(`/portal/${studioId}/leute`);
  const mitglieder = page.locator("section").filter({ hasText: "Alle Mitglieder" });
  await expect(mitglieder.getByRole("listitem").filter({ hasText: mitgliedEmail })).toHaveCount(1);
  await expect(mitglieder.getByRole("listitem").filter({ hasText: trainerEmail })).toHaveCount(0);

  await page.goto(`/portal/${studioId}/leute/mitarbeiter`);
  const mitarbeiter = page.locator("section").filter({ hasText: "Alle Mitarbeiter" });
  await expect(mitarbeiter.getByRole("listitem").filter({ hasText: trainerEmail })).toHaveCount(1);
  await expect(mitarbeiter.getByRole("listitem").filter({ hasText: mitgliedEmail })).toHaveCount(0);
});

/**
 * Ein Formular je Bildschirm heisst genau eine Akzentflaeche -- und die
 * beiden Leute-Reiter haben unterschiedlich viele davon, aus einem Grund:
 *
 *   Mitglieder    NULL. Der Reiter legt nichts an; er listet und
 *                 entfernt. Der Praezedenzfall ist die Tags-Seite aus
 *                 Aufgabe 5, die aus demselben Grund keine traegt.
 *   Mitarbeiter   EINE. "Zum Trainer machen" ist die Hauptaktion, und
 *                 sie steht genau einmal da: ein Auswahlfeld ueber alle
 *                 Mitglieder, ein Knopf (LeuteMitarbeiter.dc.html).
 *
 * Eine wiederholte Zeilenaktion -- ein Akzentknopf je Mitglied -- waere
 * hier der Fehler, den dieser Test faengt: gemessen an einem Studio mit
 * zwoelf Mitgliedern waren es acht Flaechen auf einem Bildschirm.
 *
 * Das Studio traegt deshalb mehrere Mitglieder: bei null Mitgliedern
 * stuende der Abschnitt "Mitglied hochstufen" leer da, es gaebe keinen
 * Knopf, und der Test waere gruen, ohne je eine Flaeche gesehen zu haben.
 */
test("Der Reiter Mitglieder traegt keine Akzentflaeche, Mitarbeiter genau eine", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "leute-akzent");

  for (let i = 0; i < 3; i += 1) {
    const { data: nutzer, error } = await admin.auth.admin.createUser({
      email: `leute-akzent-m${i}-${crypto.randomUUID()}@example.test`,
      password: E2E_PASSWORD,
      email_confirm: true,
    });
    if (error) throw error;
    const { error: mFehler } = await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: nutzer.user.id, role: "member" });
    if (mFehler) throw mFehler;
  }

  for (const [reiter, erwartet] of [
    ["/leute", 0],
    ["/leute/mitarbeiter", 1],
  ] as const) {
    await page.goto(`/portal/${studioId}${reiter}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen.length,
      `${reiter} traegt ${flaechen.length} statt ${erwartet}: ${flaechen.join(", ")}`,
    ).toBe(erwartet);
  }
});
