import { type Locator, type Page, expect, test } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";
import { akzentflaechen, hauptlandmarken } from "./helpers/abnahme";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Der Gang durch das Portal: Vorlage anlegen, Serie anlegen, Termin
 * oeffnen, absagen.
 *
 * Laeuft dieser Test lokal rot, pruefe ZUERST, was auf Port 3000
 * lauscht -- reuseExistingServer ist lokal true, und Playwright nimmt
 * einen haengengebliebenen Server samt Code von vor der Aenderung
 * (Fahrplan 4g).
 */

/**
 * fill() auf einem input[type=datetime-local|date] setzt den Wert zwar
 * im DOM -- real gemessen, dreimal in Folge reproduziert -- aber React
 * bemerkt es bei SerienVorschau.tsx nicht: der Wert landet nie in
 * useState, die Vorschau erscheint nie. Ursache ist der bekannte
 * React-"value tracker": fill() setzt .value auf einem Weg, der den
 * Tracker im selben Zug mitzieht, wodurch das folgende input-Event keine
 * Abweichung mehr findet und onChange ausbleibt -- bei Text-/Zahlenfeldern
 * tippt Playwright dagegen echte Tastatur-Events, die dieses Problem gar
 * nicht erst haben (siehe die Felder Name/Beschreibung/Dauer weiter oben,
 * die anstandslos funktionieren).
 *
 * Der Standardausweg (react-testing-library, verbreitet dokumentiert):
 * den Wert ueber den NATIVEN Prototyp-Setter schreiben -- der laesst den
 * Tracker auf dem alten Stand -- und danach selbst ein "input"-Event
 * feuern. Kein Fill-Aufruf, keine Anwendungsaenderung, nur der Weg, wie
 * der Testfall mit einem React-kontrollierten Feld dieses Typs spricht.
 */
async function setzeNativenWert(feld: Locator, wert: string): Promise<void> {
  // Erst warten, bis React am Feld haengt -- dann setzen.
  //
  // Der native Setter plus ein input-Ereignis ist der uebliche Weg, ein von
  // React kontrolliertes Feld zu fuellen. Er trifft aber ins Leere, solange
  // die Komponente nicht hydriert ist: der Wert steht dann zwar im DOM, es
  // hoert nur niemand zu, und die Vorschau bleibt leer.
  //
  // Im Einzellauf faellt das nie auf, weil die Seite schneller hydriert, als
  // der Test sie erreicht. Im vollen Dateilauf ist die Maschine langsam
  // genug, dass der Test gewinnt -- am 5. September reproduzierbar rot
  // ("Dieser eine Termin wird angelegt." nicht gefunden), isoliert gruen.
  // Ein Test, der von der Tagesform der Maschine abhaengt, ist schlimmer als
  // keiner.
  //
  // Die React-Eigenschaften am DOM-Knoten sind der einzige oeffentlich
  // sichtbare Zeitpunkt, ab dem das Ereignis ankommt.
  await feld.evaluate(
    (el) =>
      new Promise<void>((fertig) => {
        const hydriert = () =>
          Object.keys(el).some((schluessel) => schluessel.startsWith("__react"));
        if (hydriert()) return fertig();
        const uhr = setInterval(() => {
          if (hydriert()) {
            clearInterval(uhr);
            fertig();
          }
        }, 20);
      }),
  );

  await feld.evaluate((el: HTMLInputElement, wert: string) => {
    const setter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      "value",
    )!.set!;
    setter.call(el, wert);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }, wert);
}

test("Vom leeren Kursplan bis zum abgesagten Termin", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "kurse");
  const basis = `/portal/${studioId}/kurse`;

  // Ein frisches Studio hat nichts -- und sagt das je Tag, statt eine
  // leere Tabelle zu zeigen.
  await page.goto(basis);
  await expect(page.getByRole("heading", { name: "Kurse", level: 1 })).toBeVisible();
  await expect(page.getByText("Keine Kurse").first()).toBeVisible();

  // Ohne Vorlage gibt es nichts anzulegen, und die Seite sagt, was fehlt.
  await page.goto(`${basis}/termin/neu`);
  await expect(page.getByText("Es gibt noch keine Kursvorlage.")).toBeVisible();

  // Vorlage anlegen.
  await page.goto(`${basis}/vorlagen`);
  await expect(page.getByText("Noch keine Vorlage angelegt.")).toBeVisible();
  // exact: true, weil "Standard-Trainer (Anzeigename)" als Label die
  // Zeichenkette "name" enthaelt -- getByLabel matcht sonst als Teilstring
  // und trifft auf beide Felder (strict-mode violation, real gemessen).
  await page.getByLabel("Name", { exact: true }).fill("Kraftzirkel");
  await page.getByLabel("Beschreibung").fill("Sechs Stationen im Wechsel.");
  await page.getByLabel("Dauer in Minuten").fill("60");
  await page.getByLabel("Plätze").fill("16");
  await page.getByLabel("Standard-Trainer (Anzeigename)").fill("Marek T.");
  await page.getByRole("button", { name: "Vorlage anlegen" }).click();

  await expect(page.getByRole("heading", { name: "Kraftzirkel" })).toBeVisible();
  // Das Foto ist deaktiviert, aber nicht stumm.
  await expect(page.getByText("Noch kein Foto")).toBeVisible();
  await expect(page.getByText(/dafür fehlt noch der Ablageort/)).toBeVisible();

  // Serie anlegen -- und die Vorschau zeigt sie, BEVOR sie entsteht.
  //
  // Zwei Felder statt eines datetime-local: seit Aufgabe 22b zeichnet der
  // Bildschirm "Datum" und "Uhrzeit" getrennt, wie TerminAnlegen.dc.html.
  await page.goto(`${basis}/termin/neu`);
  await setzeNativenWert(page.getByLabel("Datum"), "2026-11-05");
  await setzeNativenWert(page.getByLabel("Uhrzeit"), "18:00");
  await expect(page.getByText("Dieser eine Termin wird angelegt.")).toBeVisible();
  // Der Knopf traegt die Zahl -- bei einem einzelnen Termin im Singular.
  await expect(page.getByRole("button", { name: "1 Termin anlegen" })).toBeVisible();

  await setzeNativenWert(page.getByLabel(/Wöchentlich wiederholen bis/), "2026-12-03");
  await expect(page.getByText("Diese 5 Termine werden angelegt.")).toBeVisible();
  // Die Zahl steht seit Aufgabe 22b auch im Satz darunter: "diese
  // Termine" liess offen, welche gemeint sind, sobald der Absatz nicht
  // mehr direkt an der Liste klebt.
  await expect(page.getByText(/bleiben diese 5 Termine unverändert/)).toBeVisible();

  await page.getByRole("button", { name: "5 Termine anlegen" }).click();
  // Auf die Umleitung warten, BEVOR der naechste goto kommt:
  // terminAnlegenAction endet mit redirect() auf den Kursplan
  // (kurse-actions.ts). Ohne dieses Warten bricht der goto die noch
  // laufende Server Action ab, und der Test fand danach keinen Termin --
  // real gemessen, mit und ohne die Aenderungen dieser Aufgabe, auch am
  // Stand 6f60799. Eine Zusicherung kommt hinzu (die Umleitung landet auf
  // dem Kursplan), keine faellt weg.
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/kurse$`));

  // Zurueck auf der Wochenansicht -- in der Woche des ersten Termins.
  await page.goto(`${basis}?woche=2026-11-05`);
  await expect(page.getByText("Donnerstag, 5. November")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
  await expect(page.getByText("0 von 16")).toBeVisible();

  // Termin oeffnen: noch niemand da, und die Liste sagt, wem sie gehoert.
  await page.getByRole("link", { name: /18:00 · Kraftzirkel/ }).click();
  await expect(page.getByText("Noch niemand angemeldet.")).toBeVisible();
  await expect(
    page.getByText("Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie nicht."),
  ).toBeVisible();

  // Absagen ist eine bestaetigte Handlung.
  await page.getByRole("button", { name: "Termin absagen" }).click();
  await expect(
    page.getByText(/Der Termin bleibt sichtbar und wird als abgesagt gekennzeichnet/),
  ).toBeVisible();
  await page.getByRole("button", { name: "Ja, Termin absagen" }).click();

  await expect(page.getByText(/Dieser Termin ist abgesagt/)).toBeVisible();

  // Und in der Wochenansicht steht "abgesagt" statt einer Belegung.
  await page.goto(`${basis}?woche=2026-11-05`);
  await expect(page.getByText("abgesagt")).toBeVisible();

  // Die uebrigen vier Termine der Serie stehen unberuehrt.
  await page.goto(`${basis}?woche=2026-11-12`);
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
  await expect(page.getByText("0 von 16")).toBeVisible();
});

test("Die Rail führt zu den Kursen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "kurse-rail");
  await page.goto(`/portal/${studioId}`);
  // exact: true, weil der Ueberblick seit d6cd1c4 einen zweiten Link
  // auf dieselbe Route traegt ("Zu den Kursen") -- getByRole matcht den
  // Namen sonst als Teilstring und trifft beide (strict-mode violation,
  // real gemessen, ebenso am Stand 6f60799). Gemeint ist die Rail-Zeile,
  // und die heisst genau "Kurse".
  await page.getByRole("link", { name: "Kurse", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/kurse$`));
});

/**
 * Ab hier Aufgabe 22a: die drei gestalteten Bildschirme (Kursplan,
 * Kursvorlagen, Kursvorlage).
 *
 * Die Fixtures legen ihre Daten mit dem Dienstschluessel an, wie
 * schreibtisch.spec.ts es fuer den Kurstermin des Ueberblicks tut -- der
 * Weg durch die Oberflaeche (Vorlage anlegen, Serie anlegen) steht im
 * Gang-Test oben und braucht dort seine Zeit; ein Test, der nur einen
 * fertigen Bildschirm ansieht, soll ihn nicht noch einmal gehen.
 */

async function vorlageAnlegen(
  admin: SupabaseClient,
  studioId: string,
  name: string,
): Promise<string> {
  const { data, error } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name,
      description: "Sechs Stationen im Wechsel.",
      default_duration_min: 60,
      default_capacity: 16,
      default_instructor_name: "Marek T.",
    })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;
  return data!.id;
}

async function terminAnlegen(
  admin: SupabaseClient,
  studioId: string,
  templateId: string,
  startsAt: string,
  // Seit Aufgabe 22b ueberschreibbar: die Tests zur Teilnehmerliste
  // brauchen einen Termin, dessen Kapazitaet zur Zahl der Buchungen passt
  // -- ein voller Termin mit Warteliste ist der Fall, den Termin.dc.html
  // zeichnet, und nachruecken kann nur, wo vorher kein Platz frei war.
  kapazitaet = 16,
): Promise<string> {
  const { data, error } = await admin
    .from("course_sessions")
    .insert({
      studio_id: studioId,
      course_template_id: templateId,
      starts_at: startsAt,
      duration_min: 60,
      capacity: kapazitaet,
      room: "Kursraum 2",
      instructor_name: "Marek T.",
    })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;
  return data!.id;
}

/**
 * Befund 41: alle fuenf Kurse-Dateien tragen ein eigenes
 * <main className={styles.content}> INNERHALB der <main> aus
 * (schreibtisch)/layout.tsx. Aufgabe 4 hat die Landmarke ins Layout
 * gezogen; die Kurse-Seiten entstanden parallel auf einem eigenen Zweig
 * gegen das alte Layout und haben es nicht mitbekommen.
 *
 * Zwei Folgen: ein Screenreader zaehlt zwei Hauptbereiche und kann bei
 * "zum Hauptteil springen" nicht sagen, welcher gemeint ist, und die
 * .content-Polsterung liegt doppelt -- der Kursplan steht 40 px weiter
 * innen als jede andere Seite des Portals. bausteine.spec.ts faehrt
 * dieselbe Abnahme fuer sechs aeltere Schreibtischseiten ab, aber fuer
 * keine Kurse-Route.
 */
test("Die Kurse-Routen tragen genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-landmarke");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");

  for (const pfad of ["/kurse", "/kurse/vorlagen", `/kurse/vorlagen/${vorlageId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});

/**
 * Je Bildschirm genau eine Akzentflaeche, am Markup der Artboards
 * nachgezaehlt: Kurse -> "Termin anlegen", Kursvorlagen ->
 * "Vorlage anlegen", Kursvorlage -> "Änderungen speichern".
 *
 * toHaveLength(1), nicht toBeLessThanOrEqual(1): die zweite Fassung
 * bleibt auch gruen, wenn die Flaeche ganz verschwindet.
 */
test("Jeder der drei Kurse-Bildschirme traegt genau eine Akzentflaeche", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-akzent");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");

  for (const pfad of ["/kurse", "/kurse/vorlagen", `/kurse/vorlagen/${vorlageId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen,
      `/portal/<id>${pfad}: ${flaechen.length} statt 1 -- ${flaechen.join(", ")}`,
    ).toHaveLength(1);
  }
});

/**
 * Kursvorlage.dc.html zeichnet zwei Reiter -- Stammdaten und
 * "Termine (16)" mit dem Zusatz "in den naechsten 4 Wochen" UNTER der
 * Beschriftung. Der Fliesstext des Artboards verraet das nicht, das
 * Markup schon.
 *
 * Die Leiste braucht einen Namen: die Seite traegt zwei Navigationen
 * (Rail und Reiter), und "Navigation" zweimal ist keine Auskunft.
 */
test("Die Kursvorlage hat zwei Reiter, und Termine zeigt die Terminliste", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-reiter");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(
    admin,
    studioId,
    vorlageId,
    new Date(Date.now() + 3 * 24 * 3_600_000).toISOString(),
  );
  const basis = `/portal/${studioId}/kurse`;

  await page.goto(`${basis}/vorlagen/${vorlageId}`);
  await expect(page.getByRole("navigation", { name: "Kursvorlage" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Stammdaten/ })).toBeVisible();
  await expect(page.getByRole("link", { name: /Termine \(1\)/ })).toBeVisible();
  await expect(page.getByText("in den nächsten 4 Wochen")).toBeVisible();

  // Stammdaten ist der erste Reiter: das Formular steht hier, die
  // Terminliste nicht.
  await expect(page.getByLabel("Name", { exact: true })).toBeVisible();
  await expect(page.locator(`a[href="${basis}/termin/${terminId}"]`)).toHaveCount(0);

  await page.getByRole("link", { name: /Termine \(1\)/ }).click();
  await expect(page).toHaveURL(new RegExp(`/kurse/vorlagen/${vorlageId}/termine$`));
  await expect(page.locator(`a[href="${basis}/termin/${terminId}"]`)).toBeVisible();
  await expect(page.getByLabel("Name", { exact: true })).toHaveCount(0);
  // Der Kopf bleibt stehen -- er gehoert dem Layout, nicht dem Reiter.
  await expect(page.getByRole("heading", { name: "Kraftzirkel", level: 1 })).toBeVisible();
});

/**
 * Der vierte Test, selbst gewaehlt: der Wochenwechsel.
 *
 * Warum dieser. Die Kopfzeile des Kursplans ist genau das Stueck, das
 * diese Aufgabe umbaut -- aus zwei nackten Textlinks werden zwei
 * Nebenaktionen neben der Hauptaktion. Geprueft wird der Wechsel heute
 * von keinem Test: der Gang-Test oben springt mit ?woche=2026-11-05
 * direkt in die Zielwoche und umgeht damit genau die Rechnung, die
 * wochenFenster fuer "vorige" und "naechste" anstellt, UND deren
 * Verdrahtung an die beiden Links. woche.test.ts prueft die Rechnung als
 * Einheit, nie den Weg vom href zum Bildschirm. Ein beim Umbau
 * verlorenes href faellt sonst nirgends auf -- der Link saehe richtig
 * aus und taete nichts.
 *
 * Feste Daten statt "heute": der Anker steht in der URL, also ist der
 * Bildschirm ohne Zeitzonenrechnerei im Test reproduzierbar. 17:00 UTC
 * sind im November 18:00 in Europe/Berlin, der Vorgabe-Zeitzone eines
 * neuen Studios.
 */
test("Der Wochenwechsel wechselt wirklich die Woche", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-woche");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  await terminAnlegen(admin, studioId, vorlageId, "2026-11-04T17:00:00.000Z");
  const basis = `/portal/${studioId}/kurse`;

  await page.goto(`${basis}?woche=2026-11-04`);
  await expect(page.getByText("Mo., 2. November – So., 8. November 2026")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();

  await page.getByRole("link", { name: /Nächste Woche/ }).click();
  await expect(page.getByText("Mo., 9. November – So., 15. November 2026")).toBeVisible();
  await expect(page.getByText("Mittwoch, 11. November")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toHaveCount(0);

  await page.getByRole("link", { name: /Vorige Woche/ }).click();
  await expect(page.getByText("Mo., 2. November – So., 8. November 2026")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
});

/**
 * Ab hier Aufgabe 22b: die letzten beiden Kurse-Bildschirme -- "Termin
 * anlegen" (TerminAnlegen.dc.html) und das Termindetail (Termin.dc.html).
 */

/**
 * Ein Konto samt Buchung auf einem Termin, direkt in die Tabellen.
 *
 * Ohne Passwort: diese Konten melden sich nie an, sie sollen nur
 * existieren -- course_bookings.user_id zeigt auf auth.users, und
 * list_course_participants (0037) holt die Adresse von dort. Ein Passwort
 * waere ein bcrypt-Hash je Konto, und zwoelf davon kosten Sekunden fuer
 * nichts.
 *
 * booked_at wird gesetzt statt dem Default ueberlassen: die Warteliste
 * ist danach sortiert und nummeriert (0037), und "Position 1" soll im
 * naechsten Lauf derselben Person gehoeren.
 */
async function gastMitBuchung(
  admin: SupabaseClient,
  studioId: string,
  sessionId: string,
  status: "booked" | "waitlisted",
  nummer: number,
): Promise<string> {
  const email = `kursgast-${nummer}-${crypto.randomUUID()}@example.test`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
  });
  if (error) throw error;

  const { error: buchungFehler } = await admin.from("course_bookings").insert({
    // course_bookings.id hat bewusst keinen Default (0035) -- die Kennung
    // kommt vom Aufrufer.
    id: crypto.randomUUID(),
    studio_id: studioId,
    course_session_id: sessionId,
    user_id: data!.user.id,
    status,
    booked_at: new Date(Date.UTC(2026, 7, 25, 12, 0, 0) + nummer * 60_000).toISOString(),
  });
  if (buchungFehler) throw buchungFehler;
  return email;
}

/** Der Abschnitt mit dieser Ueberschrift -- Abschnitt.tsx rendert ein <section>. */
function abschnitt(page: Page, ueberschrift: RegExp) {
  return page
    .locator("section")
    .filter({ has: page.getByRole("heading", { name: ueberschrift }) });
}

/** Ein Termin in drei Tagen -- in der Zukunft, damit nachgerueckt werden darf (0038). */
function inDreiTagen(): string {
  return new Date(Date.now() + 3 * 24 * 3_600_000).toISOString();
}

/**
 * Befund 41, letzter Rest: drei der acht <main className={styles.content}>
 * standen noch in diesen beiden Dateien -- zwei in termin/neu/page.tsx
 * (Fehler- und Normalzweig), eine in termin/[sessionId]/page.tsx.
 * (schreibtisch)/layout.tsx traegt die Landmarke schon fuer alle Kinder.
 */
test("Die beiden Termin-Routen tragen genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "termin-landmarke");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(admin, studioId, vorlageId, inDreiTagen());

  for (const pfad of ["/kurse/termin/neu", `/kurse/termin/${terminId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});

/**
 * Je Bildschirm genau eine Akzentflaeche, am Markup der Artboards
 * nachgezaehlt: Termin anlegen -> der Absendeknopf ("14 Termine
 * anlegen"), Termin -> "Änderungen speichern". "Abmelden" und "Termin
 * absagen" tragen im Artboard einen danger-Umriss auf 40 px, sind also
 * zerstoerend; "Alle anzeigen" ist sekundaer.
 *
 * toHaveLength(1), nicht toBeLessThanOrEqual(1): die zweite Fassung
 * bliebe auch gruen, wenn die Flaeche ganz verschwaende.
 */
test("Beide Termin-Bildschirme tragen genau eine Akzentflaeche", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "termin-akzent");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(admin, studioId, vorlageId, inDreiTagen());

  for (const pfad of ["/kurse/termin/neu", `/kurse/termin/${terminId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen,
      `/portal/<id>${pfad}: ${flaechen.length} statt 1 -- ${flaechen.join(", ")}`,
    ).toHaveLength(1);
  }
});

/**
 * Befund 39: die Kuerzung aus Aufgabe 19 klappt ueber "?alle=1" auf --
 * ein Parameter ohne Namen. Auf dem Reiter "Mitglieder" trug das, weil es
 * dort nur EINE kuerzbare Liste gibt. Dieser Bildschirm hat zwei, und ein
 * namenloser Parameter klappte beide zugleich auf.
 *
 * Geprueft wird deshalb nicht nur, DASS aufgeklappt wird, sondern dass
 * der Parameter seine Liste BENENNT: ein anderer Wert laesst "Angemeldet"
 * gekuerzt. Genau das kann "?alle=1" nicht.
 */
test("Alle anzeigen klappt die benannte Liste auf, kein anderer Wert", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "termin-kuerzung");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(admin, studioId, vorlageId, inDreiTagen(), 10);
  for (let i = 0; i < 10; i++) {
    await gastMitBuchung(admin, studioId, terminId, "booked", i);
  }
  for (let i = 0; i < 2; i++) {
    await gastMitBuchung(admin, studioId, terminId, "waitlisted", 100 + i);
  }
  const pfad = `/portal/${studioId}/kurse/termin/${terminId}`;

  await page.goto(pfad);
  const angemeldet = abschnitt(page, /^Angemeldet \(/);
  const warteliste = abschnitt(page, /^Warteliste \(/);

  // Gekuerzt: acht von zehn (KUERZUNG_AB aus leute/leute.ts).
  await expect(angemeldet.getByRole("listitem")).toHaveCount(8);
  await expect(angemeldet.getByText("… 2 weitere")).toBeVisible();
  // Die Warteliste kuerzt nicht -- so zeichnet es auch das Artboard.
  await expect(warteliste.getByRole("listitem")).toHaveCount(2);

  await angemeldet.getByRole("link", { name: "Alle anzeigen" }).click();
  await expect(page).toHaveURL(/\?alle=angemeldet$/);
  await expect(angemeldet.getByRole("listitem")).toHaveCount(10);

  // Der Kern des Befunds: der Parameter gehoert EINER Liste.
  await page.goto(`${pfad}?alle=warteliste`);
  await expect(angemeldet.getByRole("listitem")).toHaveCount(8);
});

/**
 * Designsystem 11 und Struktur-Spec 8: Benachrichtigungen existieren
 * nicht, und bis sie existieren darf der Satz nicht in die App. Ein
 * Mitglied, das auf eine Nachricht wartet, die nie kommt, verliert den
 * Platz -- und das Vertrauen.
 *
 * Dieser Test war beim ersten Lauf gruen, und das ist Absicht: er haelt
 * eine Regel fest, statt eine Luecke zu finden -- der einzige Weg, eine
 * Regel zu sichern, die etwas VERBIETET. Der Satz will einem beim Bauen
 * dieses Bildschirms in die Feder ("rueckt automatisch nach und wird
 * informiert"); die erste Haelfte stimmt, die zweite nicht.
 */
test("Die Warteliste verspricht keine Benachrichtigung", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "termin-stille");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(admin, studioId, vorlageId, inDreiTagen(), 1);
  await gastMitBuchung(admin, studioId, terminId, "booked", 0);
  await gastMitBuchung(admin, studioId, terminId, "waitlisted", 1);

  await page.goto(`/portal/${studioId}/kurse/termin/${terminId}`);
  await expect(page.getByRole("heading", { name: "Warteliste (1)" })).toBeVisible();

  // Ueber den Seitentext, nicht ueber einzelne Elemente: verboten ist der
  // Satz, egal in welchem Kasten er steht.
  const seitentext = (await page.locator("body").innerText()).toLowerCase();
  for (const wort of ["benachricht", "informier", "nachricht", "e-mail"]) {
    expect(seitentext, `"${wort}" steht auf dem Termin-Bildschirm`).not.toContain(wort);
  }
});

/**
 * Der fuenfte Test, selbst gewaehlt: Abmelden meldet ab UND laesst
 * nachruecken.
 *
 * Warum dieser. Das Nachruecken ist die einzige Stelle des Portals, an
 * der eine Handlung des Trainers eine ZWEITE Zeile veraendert, die er
 * nicht angefasst hat -- cancel_course_booking (0038) befoerdert im
 * selben gesperrten Abschnitt den Ersten der Warteliste. Die Oberflaeche
 * zeigt das als eigenen Zustand ("Nachgerückt ..."), und dieser Zweig
 * (promotedAt !== null) wird heute von keinem Test erreicht: der
 * Gang-Test sagt einen LEEREN Termin ab, die uebrigen sehen fertige
 * Bildschirme an, und woche.test.ts rechnet nur Wochen. Faellt der Zweig
 * beim Umbau weg oder bricht das Nachruecken, saehe der Trainer nach dem
 * Abmelden einen Termin mit freiem Platz UND Warteliste -- und niemand
 * merkte es.
 */
test("Abmelden meldet ab, und der Erste der Warteliste rückt nach", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "termin-nachruecken");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(admin, studioId, vorlageId, inDreiTagen(), 1);
  const gebucht = await gastMitBuchung(admin, studioId, terminId, "booked", 0);
  const ersterWartender = await gastMitBuchung(admin, studioId, terminId, "waitlisted", 1);
  const zweiterWartender = await gastMitBuchung(admin, studioId, terminId, "waitlisted", 2);

  await page.goto(`/portal/${studioId}/kurse/termin/${terminId}`);
  const angemeldet = abschnitt(page, /^Angemeldet \(/);
  const warteliste = abschnitt(page, /^Warteliste \(/);

  await expect(angemeldet.getByText(gebucht)).toBeVisible();
  await expect(warteliste.getByText(ersterWartender)).toBeVisible();
  await expect(warteliste.getByText("Position 1")).toBeVisible();
  await expect(warteliste.getByText("Position 2")).toBeVisible();

  // Zweistufig, wie jede zerstoerende Aktion des Portals (Form.tsx). Auf
  // den Abschnitt gescoped, weil die Rail unten links ihren eigenen
  // Abmelden-Knopf traegt.
  await angemeldet.getByRole("button", { name: "Abmelden" }).click();
  await angemeldet.getByRole("button", { name: "Wirklich abmelden?" }).click();

  // Der Platz bleibt nicht frei: der Erste der Warteliste steht jetzt
  // unter "Angemeldet", mit dem Nachrueck- statt dem Anmeldezeitpunkt.
  await expect(page.getByRole("heading", { name: "Angemeldet (1 von 1)" })).toBeVisible();
  await expect(angemeldet.getByText(ersterWartender)).toBeVisible();
  await expect(angemeldet.getByText(/^Nachgerückt /)).toBeVisible();
  await expect(angemeldet.getByText(gebucht)).toHaveCount(0);

  // Und die Warteliste ist um genau diese eine Person kuerzer -- der
  // Zweite steht danach auf Position 1.
  await expect(page.getByRole("heading", { name: "Warteliste (1)" })).toBeVisible();
  await expect(warteliste.getByText(zweiterWartender)).toBeVisible();
  await expect(warteliste.getByText("Position 1")).toBeVisible();
});
