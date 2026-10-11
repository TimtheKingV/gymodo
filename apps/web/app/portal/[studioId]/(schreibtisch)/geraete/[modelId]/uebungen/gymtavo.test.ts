import { describe, expect, it } from "vitest";
import type { CatalogType } from "@fitretro/domain";
import { anhaengbareUebungen, eigeneUebungen, gymtavoZeilen, uebungenStand } from "./gymtavo";

function uebung(id: string, video: string | null = null) {
  return {
    exerciseId: id,
    name: `Übung ${id}`,
    description: null,
    volumeKind: "reps" as const,
    targetMin: 8,
    targetMax: 12,
    sortOrder: 1,
    videoStoragePath: video,
    videoDurationS: video ? 20 : null,
  };
}

const typen: CatalogType[] = [
  { id: "t1", name: "Kabelzug", manufacturer: null, category: "kraft", loadUnit: "kg", loadStep: 2.5, loadMin: 0, loadMax: null, secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null, photoPath: null, exercises: [uebung("e1", "gy/e1.mp4"), uebung("e2")] },
  { id: "t2", name: "Langhantel", manufacturer: null, category: "kraft", loadUnit: "kg", loadStep: 2.5, loadMin: 0, loadMax: null, secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null, photoPath: null, exercises: [uebung("e3", "gy/e3.mp4"), uebung("e1", "gy/e1.mp4")] },
];

function link(exerciseId: string, fromCatalog: boolean, video: string | null = null) {
  return {
    linkId: `l-${exerciseId}`,
    exerciseId,
    name: `Übung ${exerciseId}`,
    description: null,
    volumeKind: "reps" as const,
    targetMin: 8,
    targetMax: 12,
    sortOrder: 1,
    hasVideo: video !== null,
    videoAssetId: video ? "a" : null,
    videoStoragePath: video,
    videoDurationS: video ? 30 : null,
    fromCatalog,
  };
}

describe("gymtavoZeilen", () => {
  it("zeigt die Uebungen des Typs mit Katalogvideo, ohne Verknuepfung", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t1", exercises: [] }, typen);
    expect(zeilen.map((z) => [z.exerciseId, z.herkunft, z.linkId])).toEqual([
      ["e1", "typ", null],
      ["e2", "typ", null],
    ]);
    expect(zeilen[0]!.katalogVideo).toEqual({ storagePath: "gy/e1.mp4", durationS: 20 });
  });

  it("eine Typ-Uebung mit eigenem Video erscheint genau einmal, als vom Typ", () => {
    const zeilen = gymtavoZeilen(
      { catalogModelId: "t1", exercises: [link("e1", true, "st/e1.mp4")] },
      typen,
    );
    expect(zeilen.filter((z) => z.exerciseId === "e1")).toHaveLength(1);
    expect(zeilen[0]).toMatchObject({
      herkunft: "typ",
      linkId: "l-e1",
      eigenesVideo: { storagePath: "st/e1.mp4", durationS: 30 },
    });
  });

  it("angehaengte Uebungen anderer Typen folgen, mit Katalogvideo", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t1", exercises: [link("e3", true)] }, typen);
    expect(zeilen.at(-1)).toMatchObject({
      exerciseId: "e3",
      herkunft: "angehaengt",
      linkId: "l-e3",
      katalogVideo: { storagePath: "gy/e3.mp4", durationS: 20 },
    });
  });

  it("nach einem Typwechsel stehen alte Verknuepfungen als angehaengt da", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t2", exercises: [link("e2", true)] }, typen);
    expect(zeilen.map((z) => [z.exerciseId, z.herkunft])).toEqual([
      ["e3", "typ"],
      ["e1", "typ"],
      ["e2", "angehaengt"],
    ]);
  });

  it("ohne Zuordnung nur die angehaengten", () => {
    expect(gymtavoZeilen({ catalogModelId: null, exercises: [link("e2", true)] }, typen)).toHaveLength(1);
  });
});

describe("eigeneUebungen", () => {
  it("laesst Gymtavo-Verknuepfungen weg", () => {
    expect(eigeneUebungen([link("x", false), link("e1", true)]).map((u) => u.exerciseId)).toEqual(["x"]);
  });
});

describe("anhaengbareUebungen", () => {
  it("bietet jede noch nicht gezeigte Gymtavo-Uebung einmal an, nach Namen", () => {
    expect(anhaengbareUebungen({ catalogModelId: "t1", exercises: [] }, typen)).toEqual([
      { exerciseId: "e3", name: "Übung e3", typName: "Langhantel" },
    ]);
  });

  it("ohne Zuordnung alle, eine an zwei Typen nur einmal", () => {
    const angebot = anhaengbareUebungen({ catalogModelId: null, exercises: [] }, typen);
    expect(angebot.map((u) => u.exerciseId)).toEqual(["e1", "e2", "e3"]);
    expect(angebot[0]!.typName).toBe("Kabelzug");
  });
});

describe("uebungenStand", () => {
  // Liste, Modellkopf und Ueberblick muessen dasselbe zaehlen -- vorher
  // stand in der Liste "keine Übung" neben einem Typ mit drei Uebungen.
  it("zaehlt eigene und Gymtavo-Uebungen, Videos aus beiden Quellen", () => {
    expect(
      uebungenStand({ catalogModelId: "t1", exercises: [link("x", false, "st/x.mp4")] }, typen, false),
    ).toEqual({ anzahl: 3, mitVideo: 2, eigeneOhneVideo: 0 });
  });

  it("nennt nur eigene Uebungen ohne Video als fehlend", () => {
    expect(
      uebungenStand({ catalogModelId: null, exercises: [link("x", false), link("e2", true)] }, typen, false),
    ).toEqual({ anzahl: 2, mitVideo: 0, eigeneOhneVideo: 1 });
  });

  it("im Gymtavo-Studio sind alle Uebungen eigene", () => {
    expect(
      uebungenStand({ catalogModelId: null, exercises: [link("e1", false, "gy/e1.mp4")] }, typen, true),
    ).toEqual({ anzahl: 1, mitVideo: 1, eigeneOhneVideo: 0 });
  });
});

