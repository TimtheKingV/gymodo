import { describe, expect, it } from "vitest";
import { offenePunkte } from "./offen";

/**
 * offenePunkte ist die Ableitung hinter dem Band "Noch zu tun" ueber den
 * Modellreitern. Geprueft wird, was sie SAGT und in welcher Reihenfolge --
 * nicht, wie das Band aussieht.
 *
 * Der Typ kommt aus @fitretro/domain (StudioCatalog["models"][number]);
 * hier baut ein Helfer das Mindeste zusammen, damit jeder Test nur die
 * eine Eigenschaft setzt, um die es ihm geht.
 */
type Modell = Parameters<typeof offenePunkte>[1];

function modell(teile: Partial<Modell> = {}): Modell {
  return {
    id: "m1",
    name: "Latzug",
    manufacturer: "Technogym",
    photoPath: "studio/foto.jpg",
    weightStepKg: 2.5,
    minWeightKg: 5,
    maxWeightKg: 100,
    settingDefinitions: [{ id: "s1" }],
    exercises: [{ linkId: "l1", hasVideo: true }],
    machines: [{ id: "g1", label: "12", status: "active", activeTagCount: 1 }],
    ...teile,
  } as unknown as Modell;
}

describe("offenePunkte", () => {
  it("nennt nichts, wenn Foto, Einstellung, Übung, Gerät und Tag da sind", () => {
    expect(offenePunkte("st1", modell())).toEqual([]);
  });

  it("nennt die Pflichten in der Reihenfolge, in der sie aufeinander aufbauen", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        photoPath: null,
        settingDefinitions: [],
        exercises: [],
        machines: [],
      }),
    );

    expect(punkte.map((punkt) => punkt.titel)).toEqual([
      "Kein Foto",
      "Keine Einstellungen",
      "Keine Übung",
      "Kein Gerät im Raum",
    ]);
    expect(punkte.every((punkt) => punkt.art === "blockiert")).toBe(true);
  });

  it("führt bei genau einem Gerät ohne Tag direkt vor das Gerät", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        machines: [
          { id: "g7", label: "12", status: "active", activeTagCount: 0 },
        ] as unknown as Modell["machines"],
      }),
    );

    expect(punkte).toHaveLength(1);
    expect(punkte[0]!.href).toBe("/portal/st1/einrichten/geraet/g7/tag");
    expect(punkte[0]!.label).toBe("Tag scannen");
  });

  it("schickt bei mehreren Geräten ohne Tag auf den Reiter, nicht vor ein Gerät", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        machines: [
          { id: "g7", label: "12", status: "active", activeTagCount: 0 },
          { id: "g8", label: "13", status: "active", activeTagCount: 0 },
        ] as unknown as Modell["machines"],
      }),
    );

    expect(punkte[0]!.titel).toBe("2 Geräte ohne Tag");
    expect(punkte[0]!.href).toBe("/portal/st1/geraete/m1/instanzen");
  });

  /**
   * Ein stillgelegtes Geraet ist keines im Raum -- dieselbe Rechnung wie
   * in erreichbarkeit(). Ohne diesen Fall meldete das Band ein Modell als
   * vollstaendig, dessen einziges Geraet abgebaut ist.
   */
  it("zählt ein stillgelegtes Gerät nicht als Gerät im Raum", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        machines: [
          { id: "g7", label: "12", status: "inactive", activeTagCount: 1 },
        ] as unknown as Modell["machines"],
      }),
    );

    expect(punkte.map((punkt) => punkt.titel)).toEqual(["Kein Gerät im Raum"]);
  });

  /**
   * Das fehlende Video haelt nichts auf -- es steht deshalb hinter allem
   * anderen und traegt die sanfte Marke, nicht die von warn.
   */
  it("stellt ein fehlendes Video hinten an und markiert es als unvollständig", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        photoPath: null,
        exercises: [
          { linkId: "l1", hasVideo: false },
          { linkId: "l2", hasVideo: true },
        ] as unknown as Modell["exercises"],
      }),
    );

    expect(punkte.map((punkt) => punkt.titel)).toEqual([
      "Kein Foto",
      "1 Übung ohne Einweisungsvideo",
    ]);
    expect(punkte[1]!.art).toBe("unvollstaendig");
  });
});
