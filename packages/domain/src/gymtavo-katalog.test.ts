import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
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
