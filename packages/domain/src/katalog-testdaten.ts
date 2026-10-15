/**
 * Ein kleiner, gueltiger Katalog fuer Unit- und Integrationstests.
 *
 * Er deckt mit Absicht die Faelle ab, an denen ein Import scheitern kann:
 * eine Uebung an zwei Geraetetypen (Video an beiden Verknuepfungen), ein
 * Cardiotyp mit Nachkomma-Rastung und Nebenbelastung, eine Enum-Einstellung
 * und eine Uebung ohne Video. Der Praefix trennt Testlaeufe in der geteilten
 * lokalen Datenbank voneinander.
 */

function ascii(text: string): number[] {
  return [...text].map((zeichen) => zeichen.charCodeAt(0));
}

function uint32(wert: number): number[] {
  return [(wert >>> 24) & 0xff, (wert >>> 16) & 0xff, (wert >>> 8) & 0xff, wert & 0xff];
}

function box(typ: string, inhalt: number[]): number[] {
  return [...uint32(8 + inhalt.length), ...ascii(typ), ...inhalt];
}

/** Gueltige PNG-Signatur; das Rauschen macht den Hash und damit den Pfad verschieden. */
export function pngBytes(rauschen = 0): Uint8Array {
  return new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...uint32(rauschen)]);
}

export function jpegBytes(rauschen = 0): Uint8Array {
  return new Uint8Array([0xff, 0xd8, 0xff, 0xe0, ...uint32(rauschen), 0xff, 0xd9]);
}

/**
 * MP4 mit ftyp und, wenn Sekunden gegeben sind, moov/mvhd -- genug fuer
 * sniffMediaType und readVideoDurationSeconds. null laesst mvhd weg: eine
 * Datei, deren Dauer sich nicht lesen laesst.
 */
export function mp4Bytes(sekunden: number | null, rauschen = 0): Uint8Array {
  const ftyp = box("ftyp", [...ascii("isom"), ...uint32(512), ...ascii("isomiso2")]);
  const moov =
    sekunden === null
      ? []
      : box("moov", box("mvhd", [0, 0, 0, 0, ...uint32(0), ...uint32(0), ...uint32(1000), ...uint32(sekunden * 1000)]));
  return new Uint8Array([...ftyp, ...moov, ...box("free", uint32(rauschen))]);
}

export function beispielKatalog(p = "") {
  const roh = {
    format: 1,
    muscles: [
      { key: "brust", name: "Brust" },
      { key: "trizeps", name: "Trizeps" },
      { key: "beine", name: "Beine" },
    ],
    sources: [{ key: "quelle_a", title: "Quelle A", url: "https://example.org/a", accessed_at: "2026-09-13" }],
    equipment: [
      {
        key: `${p}brustpresse`,
        name: "Brustpresse",
        category: "kraft",
        group: "geraete" as string,
        manufacturer: null as string | null,
        photo: "media/photos/brustpresse.png" as string | null,
        load_unit: "kg",
        load_step: 2.5,
        load_min: 0,
        load_max: 120 as number | null,
        secondary: null as { unit: string; step: number; min: number; max: number } | null,
        settings: [
          { key: "sitzhoehe", label: "Sitzhoehe", kind: "number", min: 1, max: 10, step: 1, unit: null } as Record<string, unknown>,
          { key: "griff", label: "Griff", kind: "enum", allowed_values: ["eng", "weit"] } as Record<string, unknown>,
        ],
        exercises: [`${p}brustpresse_neutral`, `${p}trizeps_druecken`],
      },
      {
        key: `${p}trizepsmaschine`,
        name: "Trizepsmaschine",
        category: "kraft",
        group: "geraete" as string,
        manufacturer: null as string | null,
        photo: null as string | null,
        load_unit: "kg",
        load_step: 5,
        load_min: 0,
        load_max: null as number | null,
        secondary: null as { unit: string; step: number; min: number; max: number } | null,
        settings: [] as Record<string, unknown>[],
        exercises: [`${p}trizeps_druecken`],
      },
      {
        key: `${p}laufband`,
        name: "Laufband",
        category: "cardio",
        group: "cardio" as string,
        manufacturer: "Precor" as string | null,
        photo: null as string | null,
        load_unit: "kmh",
        load_step: 0.1,
        load_min: 0,
        load_max: 25 as number | null,
        secondary: { unit: "pct", step: 0.5, min: 0, max: 15 } as { unit: string; step: number; min: number; max: number } | null,
        cardio_values: ["zeit", "strecke"],
        settings: [] as Record<string, unknown>[],
        exercises: [`${p}gehen`],
      },
    ],
    exercises: [
      {
        key: `${p}brustpresse_neutral`,
        name: "Brustpresse neutral",
        description: "Einstellen:\n- Sitz auf Brusthoehe." as string | null,
        volume_kind: "reps",
        target_min: 8,
        target_max: 12,
        video: { file: "media/videos/brustpresse_neutral.mp4", duration_s: 6 } as { file: string; duration_s: number } | null,
        grip: "neutral" as string | null,
        muscles: [
          { muscle: "brust", role: "primary" },
          { muscle: "trizeps", role: "secondary" },
        ],
        review: "draft",
        sources: ["quelle_a"],
      },
      {
        key: `${p}trizeps_druecken`,
        name: "Trizepsdruecken",
        description: null as string | null,
        volume_kind: "reps",
        target_min: 10,
        target_max: 15,
        video: { file: "media/videos/trizeps.mp4", duration_s: 5 } as { file: string; duration_s: number } | null,
        grip: "pronated" as string | null,
        muscles: [{ muscle: "trizeps", role: "primary" }],
        review: "reviewed",
        sources: [] as string[],
      },
      {
        key: `${p}gehen`,
        name: "Laufband Gehen",
        description: null as string | null,
        volume_kind: "seconds",
        target_min: 60,
        target_max: 1800,
        video: null as { file: string; duration_s: number } | null,
        grip: null as string | null,
        muscles: [{ muscle: "beine", role: "primary" }],
        review: "draft",
        sources: [] as string[],
      },
    ],
  };
  const dateien = new Map<string, Uint8Array>([
    ["media/photos/brustpresse.png", pngBytes(1)],
    ["media/videos/brustpresse_neutral.mp4", mp4Bytes(6, 2)],
    ["media/videos/trizeps.mp4", mp4Bytes(5, 3)],
  ]);
  return { roh, dateien };
}

export type BeispielRoh = ReturnType<typeof beispielKatalog>["roh"];

export type ProduktRoh = {
  key: string;
  manufacturer: string;
  series: string | null;
  name: string;
  model_code: string | null;
  product_url: string | null;
  types: string[];
  note: string | null;
  photo: string | null;
  photo_rights: string;
  load_unit: string | null;
  load_step: number | null;
  load_min: number | null;
  load_max: number | null;
  secondary: { unit: string; step: number; min: number; max: number } | null;
};

/**
 * Der Beispielkatalog mit zwei Herstellermodellen (Spec 2026-10-10 ...,
 * 6.2): eines an zwei Typen, ohne Foto und ohne Belastung -- so sieht der
 * Erstbestand aus --, eines mit geklaertem Foto und vollem Raster.
 * Getrennt von beispielKatalog, damit dessen Zaehlungen in den
 * Bestandstests gleich bleiben.
 */
export function mitProdukten(beispiel: ReturnType<typeof beispielKatalog>, p = "") {
  const products: ProduktRoh[] = [
    {
      key: `${p}gym80_pure_kraft_4345`,
      manufacturer: "gym80",
      series: "Pure Kraft",
      name: "Brustpresse",
      model_code: "4345",
      product_url: "https://example.org/gym80/4345",
      types: [`${p}brustpresse`, `${p}trizepsmaschine`],
      note: "Scheibenbeladen, eigenes Lastprofil.",
      photo: null,
      photo_rights: "pending",
      load_unit: null,
      load_step: null,
      load_min: null,
      load_max: null,
      secondary: null,
    },
    {
      key: `${p}precor_trm_885`,
      manufacturer: "Precor",
      series: null,
      name: "Laufband",
      model_code: "TRM 885",
      product_url: null,
      types: [`${p}laufband`],
      note: null,
      photo: "media/products/precor_trm_885.jpg",
      photo_rights: "cleared",
      load_unit: "kmh",
      load_step: 0.1,
      load_min: 0.8,
      load_max: 25,
      secondary: { unit: "pct", step: 0.5, min: 0, max: 15 },
    },
  ];
  const dateien = new Map(beispiel.dateien);
  dateien.set("media/products/precor_trm_885.jpg", jpegBytes(4));
  return { roh: { ...beispiel.roh, products }, dateien };
}
