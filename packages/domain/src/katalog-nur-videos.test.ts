import { describe, expect, it } from "vitest";
import { pruefeKatalog } from "./katalog-datei.js";
import { pruefeMedien, videoPraefix } from "./katalog-medien.js";
import { nurVideos, planeImport, type ImportPlan, type IstStand } from "./katalog-plan.js";
import { VIDEO_BUCKET } from "./media.js";
import { beispielKatalog } from "./katalog-testdaten.js";

const LEER: IstStand = {
  geraetetypen: [], einstellungen: [], uebungen: [], verknuepfungen: [], videos: [], produkte: [], produktTypen: [], objekte: new Set(),
};

function plane(ist: IstStand): ImportPlan {
  const beispiel = beispielKatalog();
  const k = pruefeKatalog(beispiel.roh);
  if (!k.ok) throw new Error(k.fehler.join("\n"));
  const m = pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  if (!m.ok) throw new Error(m.fehler.join("\n"));
  return planeImport(k.wert, m.wert, ist);
}

/** Ein Ist-Stand wie nach einem frueheren Import, mit einem alten Video und einem abweichenden Geraetenamen. */
function istMitAbweichungen(): IstStand {
  const erster = plane(LEER);
  const typId = (k: string) => `typ-${k}`;
  const uebId = (k: string) => `ueb-${k}`;
  const linkId = (s: string) => `link-${s}`;
  return {
    geraetetypen: erster.geraetetypen.map((p, i) => ({ id: typId(p.schluessel), ...p.zeile, ...(i === 0 ? { name: "anders" } : {}) })),
    einstellungen: erster.einstellungen.map((p) => {
      const { geraetetyp, ...zeile } = p.zeile;
      return { id: `e-${p.schluessel}`, equipment_model_id: typId(geraetetyp), ...zeile };
    }),
    uebungen: erster.uebungen.map((p) => ({ id: uebId(p.schluessel), ...p.zeile })),
    verknuepfungen: erster.verknuepfungen.map((p) => ({
      id: linkId(p.schluessel),
      equipment_model_id: typId(p.zeile.geraetetyp),
      exercise_id: uebId(p.zeile.uebung),
      sort_order: p.zeile.sort_order,
    })),
    videos: erster.videos.map((p) => ({
      id: `v-${p.schluessel}`,
      equipment_model_exercise_id: linkId(p.schluessel),
      storage_path: `${videoPraefix(p.zeile.uebung)}alt0000.mp4`,
      duration_s: 6,
    })),
    produkte: [],
    produktTypen: [],
    objekte: new Set(),
  };
}

describe("nurVideos", () => {
  it("behaelt die geaenderten Videos und macht alles andere zu unveraendert", () => {
    const plan = plane(istMitAbweichungen());
    expect(plan.geraetetypen.some((p) => p.art === "geaendert")).toBe(true);
    expect(plan.videos.some((p) => p.art === "geaendert")).toBe(true);

    const eng = nurVideos(plan);
    expect(eng.videos).toEqual(plan.videos);
    for (const liste of [eng.geraetetypen, eng.einstellungen, eng.uebungen, eng.verknuepfungen, eng.produkte, eng.produktTypen]) {
      expect(liste.every((p) => p.art === "unveraendert")).toBe(true);
    }
  });

  it("behaelt die ids, die die Videos zum Zuordnen brauchen", () => {
    const eng = nurVideos(plane(istMitAbweichungen()));
    expect(eng.geraetetypen.every((p) => p.id !== null)).toBe(true);
    expect(eng.verknuepfungen.every((p) => p.id !== null)).toBe(true);
  });

  it("laedt nur Videos hoch", () => {
    const plan = plane(istMitAbweichungen());
    const eng = nurVideos(plan);
    expect(eng.uploads.length).toBeGreaterThan(0);
    expect(eng.uploads.every((m) => m.bucket === VIDEO_BUCKET)).toBe(true);
  });

  it("meldet nichts zu Geraeten, Produkten und Fotos", () => {
    const eng = nurVideos(plane(istMitAbweichungen()));
    expect(eng.gemeldet.geraetetypen).toEqual([]);
    expect(eng.gemeldet.produkte).toEqual([]);
    expect(eng.gemeldet.entzogeneFotos).toEqual([]);
  });

  it("bricht ab, wenn ein Video eine neue Verknuepfung braucht", () => {
    const plan = plane(LEER);
    expect(() => nurVideos(plan)).toThrow(/Verknuepfung/);
  });
});
