import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BAUSTEINE, PFLICHT_BAUSTEINE } from "./trainingsplan-typen.js";
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

  it("nennt in der Ausstattung keinen abgeloesten Kabelzug mehr", () => {
    const k = katalog();
    const alteNamen = k.equipment.filter((g) => g.retired).map((g) => g.name);
    const kabelzug = new Set(k.equipment.find((g) => g.key === "dual_cable_station")!.exercises);
    for (const u of k.exercises.filter((x) => kabelzug.has(x.key))) {
      const ausstattung = u.description?.split("Benötigte Ausstattung:")[1] ?? "";
      for (const name of alteNamen) expect(ausstattung, u.key).not.toContain(`1 × ${name}`);
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
  it("gibt jedem aktiven Typ einen Startwert ueber dem Minimum", () => {
    const ohne = katalog()
      .equipment.filter((g) => !g.retired)
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

  it("hat fuer jeden Pflichtbaustein mindestens zwei Planuebungen", () => {
    for (const b of PFLICHT_BAUSTEINE) {
      expect(planUebungen().filter((u) => u.plan?.baustein === b).length, b).toBeGreaterThanOrEqual(2);
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

  it("traegt druecken, ziehen und beine_knie nie als isolation ein", () => {
    for (const u of planUebungen()) {
      if (["druecken", "ziehen", "beine_knie"].includes(u.plan!.baustein)) {
        expect(u.plan!.typ, u.key).toBe("mehrgelenk");
      }
    }
  });

  it("traegt Cardio ohne Bereiche ein", () => {
    for (const u of planUebungen().filter((x) => x.plan?.baustein === "cardio")) {
      expect(u.plan!.bereiche, u.key).toEqual([]);
    }
  });
});
