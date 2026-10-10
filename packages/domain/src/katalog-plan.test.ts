import { describe, expect, it } from "vitest";
import { GYMTAVO_STUDIO_ID, pruefeKatalog } from "./katalog-datei.js";
import { pruefeMedien } from "./katalog-medien.js";
import { planeImport, type ImportPlan, type IstStand } from "./katalog-plan.js";
import { beispielKatalog, mp4Bytes, pngBytes } from "./katalog-testdaten.js";

const LEER: IstStand = { geraetetypen: [], einstellungen: [], uebungen: [], verknuepfungen: [], videos: [], objekte: new Set() };

function plane(beispiel: ReturnType<typeof beispielKatalog>, ist: IstStand): ImportPlan {
  const k = pruefeKatalog(beispiel.roh);
  if (!k.ok) throw new Error(k.fehler.join("\n"));
  const m = pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  if (!m.ok) throw new Error(m.fehler.join("\n"));
  return planeImport(k.wert, m.wert, ist);
}

/** Ein Ist-Stand, der genau dem Plan entspricht -- als waere er schon importiert. */
function istAus(plan: ImportPlan): IstStand {
  const typId = (k: string) => `typ-${k}`;
  const uebId = (k: string) => `ueb-${k}`;
  const linkId = (s: string) => `link-${s}`;
  return {
    geraetetypen: plan.geraetetypen.map((p) => ({ id: typId(p.schluessel), ...p.zeile })),
    einstellungen: plan.einstellungen.map((p) => {
      const { geraetetyp, ...zeile } = p.zeile;
      return { id: `e-${p.schluessel}`, equipment_model_id: typId(geraetetyp), ...zeile };
    }),
    uebungen: plan.uebungen.map((p) => ({ id: uebId(p.schluessel), ...p.zeile })),
    verknuepfungen: plan.verknuepfungen.map((p) => ({
      id: linkId(p.schluessel),
      equipment_model_id: typId(p.zeile.geraetetyp),
      exercise_id: uebId(p.zeile.uebung),
      sort_order: p.zeile.sort_order,
    })),
    videos: plan.videos.map((p) => ({
      id: `v-${p.schluessel}`,
      equipment_model_exercise_id: linkId(p.schluessel),
      storage_path: p.zeile.storage_path,
      duration_s: p.zeile.duration_s,
    })),
    objekte: new Set(plan.uploads.map((m) => `${m.bucket}/${m.storagePath}`)),
  };
}

const arten = (liste: { art: string }[]) => liste.map((p) => p.art);

describe("planeImport", () => {
  it("legt bei leerem Katalog alles neu an", () => {
    const plan = plane(beispielKatalog(), LEER);
    expect(arten(plan.geraetetypen)).toEqual(["neu", "neu", "neu"]);
    expect(plan.einstellungen.map((p) => p.schluessel)).toEqual(["brustpresse.sitzhoehe", "brustpresse.griff"]);
    expect(plan.einstellungen.map((p) => p.zeile.sort_order)).toEqual([1, 2]);
    expect(plan.verknuepfungen.map((p) => p.schluessel)).toEqual([
      "brustpresse > brustpresse_neutral",
      "brustpresse > trizeps_druecken",
      "trizepsmaschine > trizeps_druecken",
      "laufband > gehen",
    ]);
    // trizeps_druecken haengt an zwei Typen: das Video an beiden Verknuepfungen.
    expect(plan.videos.map((p) => p.schluessel)).toEqual([
      "brustpresse > brustpresse_neutral",
      "brustpresse > trizeps_druecken",
      "trizepsmaschine > trizeps_druecken",
    ]);
    expect(plan.uploads).toHaveLength(3);
    expect(plan.geraetetypen[2]?.zeile).toMatchObject({ load_step: 0.1, secondary_unit: "pct", secondary_max: 15 });
    expect(plan.geraetetypen[0]?.zeile.photo_path).toMatch(new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/photos/brustpresse-`));
  });

  it("meldet beim zweiten Lauf alles unveraendert und laedt nichts hoch", () => {
    const beispiel = beispielKatalog();
    const zweiter = plane(beispiel, istAus(plane(beispiel, LEER)));
    for (const liste of [zweiter.geraetetypen, zweiter.einstellungen, zweiter.uebungen, zweiter.verknuepfungen, zweiter.videos]) {
      expect(arten(liste).every((a) => a === "unveraendert")).toBe(true);
    }
    expect(zweiter.uploads).toEqual([]);
  });

  it("haelt Zahlen aus der Datenbank, die als Text kommen, fuer gleich", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    const laufband = ist.geraetetypen.find((g) => g.catalog_key === "laufband")!;
    (laufband as Record<string, unknown>).load_step = "0.1";
    (laufband as Record<string, unknown>).secondary_step = "0.50";
    expect(plane(beispiel, ist).geraetetypen[2]?.art).toBe("unveraendert");
  });

  it("nennt geaenderte Felder", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    beispiel.roh.equipment[0]!.name = "Brustpresse neu";
    beispiel.roh.equipment[0]!.exercises.reverse();
    const plan = plane(beispiel, ist);
    expect(plan.geraetetypen[0]).toMatchObject({ art: "geaendert", felder: ["name"], id: "typ-brustpresse" });
    expect(plan.verknuepfungen.filter((p) => p.art === "geaendert").map((p) => p.felder)).toEqual([["sort_order"], ["sort_order"]]);
  });

  it("meldet ersetzte eigene Medien, aber keine fremden", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    const altesVideo = ist.videos[1]!.storage_path;
    beispiel.dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 77));
    beispiel.dateien.set("media/photos/brustpresse.png", pngBytes(77));
    // Das Foto der Brustpresse stammt aus dem Portal, nicht vom Import.
    ist.geraetetypen[0]!.photo_path = `${GYMTAVO_STUDIO_ID}/portal-foto.png`;

    const plan = plane(beispiel, ist);
    expect(plan.videos.filter((p) => p.art === "geaendert").map((p) => p.felder)).toEqual([["storage_path"], ["storage_path"]]);
    expect(plan.gemeldet.ersetzteMedien).toEqual([`instruction-videos/${altesVideo}`]);
    expect(plan.uploads.map((m) => m.datei).sort()).toEqual(["media/photos/brustpresse.png", "media/videos/trizeps.mp4"]);
  });

  it("meldet, was nur noch in der Datenbank steht, und plant kein Loeschen", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    beispiel.roh.equipment[0]!.settings.pop();
    beispiel.roh.equipment[0]!.exercises = [`brustpresse_neutral`];
    beispiel.roh.equipment.splice(2, 1);
    beispiel.roh.exercises.splice(2, 1);
    beispiel.roh.exercises[0]!.video = null;

    const plan = plane(beispiel, ist);
    expect(plan.gemeldet).toMatchObject({
      geraetetypen: ["laufband"],
      uebungen: ["gehen"],
      einstellungen: ["brustpresse.griff"],
      verknuepfungen: ["brustpresse > trizeps_druecken"],
      videos: ["brustpresse > brustpresse_neutral"],
    });
  });

  it("laesst fremde Videos und Zeilen ohne Schluessel in Ruhe", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    ist.videos[0]!.storage_path = `${GYMTAVO_STUDIO_ID}/portal/eigenes.mp4`;
    ist.geraetetypen.push({ ...ist.geraetetypen[0]!, id: "hand", catalog_key: null, name: "Von Hand" });
    ist.uebungen.push({ ...ist.uebungen[0]!, id: "hand-u", catalog_key: null, name: "Von Hand Uebung" });

    const plan = plane(beispiel, ist);
    // Das fremde Video zaehlt nicht als eigenes: der Import legt seines daneben an.
    expect(plan.videos[0]).toMatchObject({ art: "neu", id: null });
    expect(plan.gemeldet.ersetzteMedien).toEqual([]);
    expect(plan.gemeldet.ohneSchluessel).toEqual(['Geraetetyp "Von Hand"', 'Uebung "Von Hand Uebung"']);
  });
});
