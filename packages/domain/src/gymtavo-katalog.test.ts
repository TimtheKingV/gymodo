import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BAUSTEINE, NUR_MEHRGELENK_PFLICHT, PFLICHT_BAUSTEINE } from "./trainingsplan-typen.js";
import { pruefeKatalog, type KatalogDatei } from "./katalog-datei.js";

/**
 * Prueft den echten Katalog, nicht das Beispiel: die Zusammenlegung der
 * Kabelzuege (Testnotiz 12.10., #1/#2) ist Inhalt, und ein vergessener
 * Uebungsschluessel faellt sonst erst nach dem Import in Prod auf.
 */
const datei = fileURLToPath(new URL("../../../catalog/gymtavo.json", import.meta.url));

function katalog(): KatalogDatei {
  const pruefung = pruefeKatalog(JSON.parse(readFileSync(datei, "utf8")));
  if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));
  return pruefung.wert;
}

describe("catalog/gymtavo.json", () => {
  it("besteht die Pruefung", () => {
    expect(() => katalog()).not.toThrow();
  });

  it("hat genau einen aktiven Kabelzug mit allen Uebungen der abgeloesten Kabeltypen", () => {
    const k = katalog();
    const kabel = k.equipment.filter((g) => g.group === "kabelzug");
    const aktiv = kabel.filter((g) => !g.retired);
    expect(aktiv.map((g) => [g.key, g.name])).toEqual([["dual_cable_station", "Kabelzug"]]);
    const abgeloest = kabel.filter((g) => g.retired).map((g) => g.key).sort();
    expect(abgeloest).toEqual(["cable_adjustable", "dual_cable", "high_cable"]);
    // Der Latzug im Obergriff braucht das Oberschenkelpolster und steht an
    // der Latzugstation (Rueckfrage A).
    const erwartet = kabel
      .flatMap((g) => g.exercises)
      .filter((u) => u !== "lat_pulldown_pronated");
    expect(new Set(aktiv[0]!.exercises)).toEqual(new Set(erwartet));
    const latzug = k.equipment.find((g) => g.key === "cable_lat");
    expect(latzug?.exercises).toContain("lat_pulldown_pronated");
  });

  it("legt die Hanteln unter Freihantel", () => {
    const freihantel = katalog().equipment.filter((g) => g.group === "freihantel" && !g.retired);
    expect(freihantel.map((g) => g.key).sort()).toEqual(["barbell", "dumbbell", "ez_bar"]);
  });

  it("gibt jedem aktiven Geraetetyp ein Etikett und jeder Uebung genau einen aktiven Typ", () => {
    const k = katalog();
    const aktiv = k.equipment.filter((g) => !g.retired);
    expect(aktiv.filter((g) => !g.label).map((g) => g.key)).toEqual([]);
    const typen = new Map<string, string[]>();
    for (const g of aktiv) for (const u of g.exercises) typen.set(u, [...(typen.get(u) ?? []), g.key]);
    expect(k.exercises.filter((u) => typen.get(u.key)?.length !== 1).map((u) => u.key)).toEqual([]);
  });

  // docs/katalog-stilleitfaden.md, Abschnitt Name.
  it("haelt das Namensschema ein: kein Geraet im Namen, nur \" – \" als Trenner", () => {
    const k = katalog();
    const geraet = /Kurzhantel|Langhantel|Kettlebell|\bSZ\b|Kabel|am Gerät|[Mm]aschine/;
    expect(k.exercises.filter((u) => geraet.test(u.name)).map((u) => u.name)).toEqual([]);
    const trenner = k.exercises.filter((u) => / · | - |—/.test(u.name) || u.name.split(" – ").length > 2);
    expect(trenner.map((u) => u.name)).toEqual([]);
  });

  it("macht jede Uebung ueber Name und Etikett eindeutig", () => {
    const k = katalog();
    const etikett = new Map<string, string>();
    for (const g of k.equipment.filter((x) => !x.retired)) for (const u of g.exercises) etikett.set(u, g.label ?? g.name);
    const paare = k.exercises.map((u) => `${u.name} [${etikett.get(u.key)}]`);
    expect(paare.filter((p, i) => paare.indexOf(p) !== i)).toEqual([]);
  });

  // docs/katalog-stilleitfaden.md, Abschnitt Beschreibung.
  it("haelt in jeder Beschreibung das Drei-Abschnitte-Format ein", () => {
    const neu = katalog().exercises;
    for (const u of neu) {
      const text = u.description ?? "";
      expect(text.length, u.key).toBeLessThanOrEqual(500);
      expect(text, u.key).not.toMatch(/erfassen|Vorschau|Benötigte Ausstattung|Positionen:|Häufige Fehler|Hinweise:/);
      const abschnitte = text.split("\n\n");
      expect(abschnitte.map((a) => a.split("\n")[0]), u.key).toEqual(["Einstellen:", "Bewegung:", "Achte auf:"]);
      for (const a of abschnitte) {
        const punkte = a.split("\n").slice(1);
        expect(punkte.length, u.key).toBeGreaterThanOrEqual(1);
        expect(punkte.length, u.key).toBeLessThanOrEqual(3);
        for (const punkt of punkte) expect(punkt, u.key).toMatch(/^- \S.*\.$/);
      }
    }
  });
});

describe("Katalog und iOS-Muskelmodell", () => {
  const ios = new URL("../../../apps/ios-member/", import.meta.url);
  const geometrie = JSON.parse(readFileSync(new URL("FitnessMember/Resources/muskelmodell.json", ios), "utf8"));
  const dargestellt = new Set<string>(["maennlich", "weiblich"].flatMap((geschlecht) =>
    ["vorne", "hinten"].flatMap((ansicht) =>
      geometrie[geschlecht][ansicht].muscles.map((m: { muscle: string }) => m.muscle))));

  it("fuehrt jeden darstellbaren Muskel im Katalog", () => {
    const bekannt = new Set(katalog().muscles.map((m) => m.key));
    expect([...dargestellt].filter((key) => !bekannt.has(key))).toEqual([]);
  });

  it("schliesst nur Muskeln ohne jede Kraftuebung aus, auch Nebenmuskeln zaehlen", () => {
    const k = katalog();
    // Aus der Geraetezuordnung statt aus Namenskonventionen oder volume_kind:
    // auch Farmer's Walk ist zeitbasiert, aber keine Cardio-Uebung.
    const kraftuebungen = new Set(k.equipment.filter((g) => g.category !== "cardio")
      .flatMap((g) => g.exercises));
    const kraftmuskeln = new Set(k.exercises.filter((u) => kraftuebungen.has(u.key))
      .flatMap((u) => u.muscles.map((m) => m.muscle)));
    const ohne = [...dargestellt].filter((key) => !kraftmuskeln.has(key)).sort();
    // Vertragspruefung zwischen gepflegter Katalogdatei und iOS-Ausnahme:
    // neue Zuordnungen duerfen nie unbemerkt weiter grau bleiben.
    const swift = readFileSync(new URL("FitnessMember/Muskelauswertung/Ausgewogenheit.swift", ios), "utf8");
    const liste = swift.match(/static let ohneKraftuebung: Set<String> = \[([\s\S]*?)\]/);
    expect(liste, "iOS-Ausnahmeliste muss pruefbar bleiben").not.toBeNull();
    const ausgeschlossen = [...liste![1]!.matchAll(/"([a-z_]+)"/g)].map((m) => m[1]!).sort();
    expect(ausgeschlossen).toEqual(ohne);
  });
});

// Testnotiz 12.10. abends, #3: kein aktiver Typ startet bei 0.
describe("catalog/gymtavo.json Startwerte", () => {
  // Ausnahme Eigengewicht: dort ist die Last das Zusatzgewicht, und 0 kg ist der richtige Start.
  it("gibt jedem aktiven Typ ausser Eigengewicht einen Startwert ueber dem Minimum", () => {
    const ohne = katalog()
      .equipment.filter((g) => !g.retired && g.group !== "eigengewicht")
      .filter((g) => g.load_start === null || g.load_start <= g.load_min)
      .map((g) => g.key);
    expect(ohne).toEqual([]);
  });

  it("startet die Beinpresse hoeher als den Bizepscurl", () => {
    const start = (key: string) => katalog().equipment.find((g) => g.key === key)?.load_start ?? 0;
    expect(start("leg_press_45")).toBeGreaterThan(start("preacher_curl"));
  });
});

// Trainingsplan Etappe 2: der Generator braucht je Baustein echte Kandidaten.
describe("catalog/gymtavo.json Planuebungen", () => {
  const planUebungen = () => katalog().exercises.filter((u) => u.plan);

  // Gezaehlt wird, was der Generator auf einen Pflichtplatz setzen darf (Regeln 1.5.0).
  it("hat fuer jeden Pflichtbaustein mindestens zwei vorschlagbare Planuebungen fuer den Pflichtplatz", () => {
    for (const b of PFLICHT_BAUSTEINE) {
      const platz = planUebungen().filter(
        (u) =>
          u.plan?.baustein === b &&
          u.plan.vorschlag &&
          (!NUR_MEHRGELENK_PFLICHT.includes(b) || u.plan.typ === "mehrgelenk"),
      );
      expect(platz.length, b).toBeGreaterThanOrEqual(2);
    }
  });

  it("hat ausser den Halteuebungen fuer jede Uebung Plan-Merkmale (freie Wahl, P4)", () => {
    // Halteuebungen zaehlen Sekunden; Planpositionen ausser Cardio kennen nur Wiederholungen.
    const k = katalog();
    const cardio = new Set(k.equipment.filter((g) => g.category === "cardio").flatMap((g) => g.exercises));
    const sekunden = k.exercises.filter((u) => u.volume_kind === "seconds" && !cardio.has(u.key)).map((u) => u.key);
    expect(sekunden).toEqual([
      "db_farmers_walk", "bw_plank", "bw_side_plank", "bw_hollow_hold", "bw_mountain_climber", "bw_wall_sit",
      "kb_farmers_walk", "kb_suitcase_carry", "kb_overhead_carry",
    ]);
    expect(k.exercises.filter((u) => !u.plan).map((u) => u.key)).toEqual(sekunden);
  });

  // Ohne Video und ohne Tims Durchsicht waehlt der Generator eine Uebung nicht von selbst.
  it("schlaegt keine Uebung ohne Video vor", () => {
    for (const u of planUebungen().filter((x) => x.video === null)) {
      expect(u.plan!.vorschlag, u.key).toBe(false);
    }
  });

  it("fuehrt Uebungen ohne Geraet unter dem Typ Koerpergewicht in der Gruppe Eigengewicht", () => {
    const typen = katalog().equipment.filter((g) => g.group === "eigengewicht");
    expect(typen.map((g) => [g.key, g.label, g.load_start])).toEqual([["bodyweight", "Körpergewicht", 0]]);
    expect(typen[0]!.exercises.every((u) => u.startsWith("bw_"))).toBe(true);
    expect(typen[0]!.exercises).toHaveLength(18);
  });

  // Kettlebells gibt es nur in festen Stufen: 2-kg-Raster ab 4 kg trifft den klassischen
  // 4-kg-Satz und die Zwischengroessen (docs/katalog-kettlebell-2026-11.md).
  it("fuehrt Kettlebell-Uebungen unter dem Typ Kettlebell in der Gruppe Kettlebell", () => {
    const typen = katalog().equipment.filter((g) => g.group === "kettlebell");
    expect(typen.map((g) => [g.key, g.label, g.category, g.load_unit])).toEqual([
      ["kettlebell", "Kettlebell", "kraft", "kg"],
    ]);
    const typ = typen[0]!;
    expect([typ.load_step, typ.load_min, typ.load_max, typ.load_start]).toEqual([2, 4, null, 8]);
    expect(typ.exercises.every((u) => u.startsWith("kb_"))).toBe(true);
    expect(typ.exercises).toHaveLength(23);
    // Umgekehrt: keine kb_-Uebung haengt an einem anderen Typ.
    const kb = katalog().exercises.filter((u) => u.key.startsWith("kb_")).map((u) => u.key);
    expect(new Set(kb)).toEqual(new Set(typ.exercises));
  });

  it("schlaegt keine Langhantel- und SZ-Uebung vor", () => {
    for (const u of planUebungen().filter((x) => /^(bb|ez)_/.test(x.key))) {
      expect(u.plan!.vorschlag, u.key).toBe(false);
    }
  });

  it("hat fuer jeden uebrigen Baustein mindestens eine Planuebung", () => {
    for (const b of BAUSTEINE.filter((x) => !PFLICHT_BAUSTEINE.includes(x))) {
      expect(planUebungen().filter((u) => u.plan?.baustein === b).length, b).toBeGreaterThanOrEqual(1);
    }
  });

  it("gibt Planuebungen mindestens einen primaeren Muskel", () => {
    for (const u of planUebungen()) {
      expect(u.muscles.some((m) => m.role === "primary"), u.key).toBe(true);
    }
  });

  // Flys und Pullover sind Isolation in druecken/ziehen; der Generator setzt sie nicht auf
  // Pflichtplaetze (NUR_MEHRGELENK_PFLICHT). beine_knie kennt keine Isolation.
  it("traegt beine_knie nie als isolation ein", () => {
    for (const u of planUebungen().filter((x) => x.plan!.baustein === "beine_knie")) {
      expect(u.plan!.typ, u.key).toBe("mehrgelenk");
    }
  });

  it("traegt Cardio ohne Bereiche ein", () => {
    for (const u of planUebungen().filter((x) => x.plan?.baustein === "cardio")) {
      expect(u.plan!.bereiche, u.key).toEqual([]);
    }
  });
});
