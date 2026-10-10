import type { KatalogDatei } from "./katalog-datei.js";
import { fotoPraefix, videoPraefix, type Medien, type Medium } from "./katalog-medien.js";
import { PHOTO_BUCKET, VIDEO_BUCKET } from "./media.js";

/**
 * Vergleicht die Katalogdatei mit dem Ist-Stand des Gymtavo-Studios und
 * entscheidet je Zeile: neu, geaendert, unveraendert. Rein und ohne Netz --
 * der Trockenlauf zeigt genau diesen Plan, der echte Lauf fuehrt ihn aus.
 *
 * Geloescht wird nie (Spec 9.1): Saetze und Studio-Zuordnungen zeigen auf
 * Katalogzeilen. Was nur noch in der Datenbank steht, landet in `gemeldet`.
 */

export type GeraetetypZeile = {
  catalog_key: string;
  name: string;
  category: string;
  manufacturer: string | null;
  photo_path: string | null;
  load_unit: string;
  load_step: number;
  load_min: number;
  load_max: number | null;
  secondary_unit: string | null;
  secondary_step: number | null;
  secondary_min: number | null;
  secondary_max: number | null;
};

export type EinstellungZeile = {
  key: string;
  label: string;
  kind: string;
  min_value: number | null;
  max_value: number | null;
  step_value: number | null;
  unit: string | null;
  allowed_values: string[] | null;
  sort_order: number;
};

export type UebungZeile = {
  catalog_key: string;
  name: string;
  description: string | null;
  volume_kind: string;
  target_min: number;
  target_max: number;
};

export type IstGeraetetyp = Omit<GeraetetypZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstEinstellung = EinstellungZeile & { id: string; equipment_model_id: string };
export type IstUebung = Omit<UebungZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstVerknuepfung = { id: string; equipment_model_id: string; exercise_id: string; sort_order: number };
export type IstVideo = { id: string; equipment_model_exercise_id: string; storage_path: string; duration_s: number };

export type IstStand = {
  geraetetypen: IstGeraetetyp[];
  einstellungen: IstEinstellung[];
  uebungen: IstUebung[];
  verknuepfungen: IstVerknuepfung[];
  videos: IstVideo[];
  /** "<bucket>/<pfad>" aller Objekte unter <Gymtavo-ID>/catalog/. */
  objekte: ReadonlySet<string>;
};

export type Art = "neu" | "geaendert" | "unveraendert";
export type Posten<Z> = { schluessel: string; art: Art; felder: string[]; id: string | null; zeile: Z };

export type ImportPlan = {
  geraetetypen: Posten<GeraetetypZeile>[];
  einstellungen: Posten<EinstellungZeile & { geraetetyp: string }>[];
  uebungen: Posten<UebungZeile>[];
  verknuepfungen: Posten<{ geraetetyp: string; uebung: string; sort_order: number }>[];
  videos: Posten<{ geraetetyp: string; uebung: string; storage_path: string; duration_s: number }>[];
  uploads: Medium[];
  gemeldet: {
    geraetetypen: string[];
    uebungen: string[];
    einstellungen: string[];
    verknuepfungen: string[];
    videos: string[];
    ersetzteMedien: string[];
    ohneSchluessel: string[];
  };
};

const GERAETETYP_FELDER = [
  "name", "category", "manufacturer", "photo_path", "load_unit", "load_step", "load_min", "load_max",
  "secondary_unit", "secondary_step", "secondary_min", "secondary_max",
] as const;
const EINSTELLUNG_FELDER = [
  "label", "kind", "min_value", "max_value", "step_value", "unit", "allowed_values", "sort_order",
] as const;
const UEBUNG_FELDER = ["name", "description", "volume_kind", "target_min", "target_max"] as const;

// PostgREST liefert numeric je nach Groesse als Zahl oder als Text. Ohne
// diesen Vergleich meldete jeder zweite Lauf das Laufband (0.1) als geaendert.
function gleich(a: unknown, b: unknown): boolean {
  if (a === null || a === undefined || b === null || b === undefined) return (a ?? null) === (b ?? null);
  if (typeof a === "number" || typeof b === "number") return Number(a) === Number(b);
  if (Array.isArray(a) || Array.isArray(b)) return JSON.stringify(a) === JSON.stringify(b);
  return a === b;
}

function vergleiche<Z extends Record<string, unknown>>(
  schluessel: string,
  zeile: Z,
  ist: (Record<string, unknown> & { id: string }) | undefined,
  felder: readonly (keyof Z & string)[],
): Posten<Z> {
  if (ist === undefined) return { schluessel, art: "neu", felder: [], id: null, zeile };
  const anders = felder.filter((f) => !gleich(zeile[f], ist[f]));
  return { schluessel, art: anders.length > 0 ? "geaendert" : "unveraendert", felder: anders, id: ist.id, zeile };
}

export function planeImport(k: KatalogDatei, medien: Medien, ist: IstStand): ImportPlan {
  const gemeldet: ImportPlan["gemeldet"] = {
    geraetetypen: [], uebungen: [], einstellungen: [], verknuepfungen: [], videos: [], ersetzteMedien: [], ohneSchluessel: [],
  };
  const ersetzt = new Set<string>();
  const typNachKey = new Map(ist.geraetetypen.flatMap((g) => (g.catalog_key === null ? [] : [[g.catalog_key, g] as const])));
  const uebungNachKey = new Map(ist.uebungen.flatMap((u) => (u.catalog_key === null ? [] : [[u.catalog_key, u] as const])));
  const uebungNameNachId = new Map(ist.uebungen.map((u) => [u.id, u.catalog_key ?? u.name]));
  const uebungDatei = new Map(k.exercises.map((u) => [u.key, u]));

  const geraetetypen = k.equipment.map((g) => {
    const zeile: GeraetetypZeile = {
      catalog_key: g.key,
      name: g.name,
      category: g.category,
      manufacturer: g.manufacturer,
      photo_path: medien.fotos.get(g.key)?.storagePath ?? null,
      load_unit: g.load_unit,
      load_step: g.load_step,
      load_min: g.load_min,
      load_max: g.load_max,
      secondary_unit: g.secondary?.unit ?? null,
      secondary_step: g.secondary?.step ?? null,
      secondary_min: g.secondary?.min ?? null,
      secondary_max: g.secondary?.max ?? null,
    };
    const istTyp = typNachKey.get(g.key);
    const posten = vergleiche(g.key, zeile, istTyp, GERAETETYP_FELDER);
    const altesFoto = istTyp?.photo_path;
    if (posten.felder.includes("photo_path") && altesFoto?.startsWith(fotoPraefix(g.key))) {
      ersetzt.add(`${PHOTO_BUCKET}/${altesFoto}`);
    }
    return posten;
  });

  const einstellungen = k.equipment.flatMap((g) => {
    const istTyp = typNachKey.get(g.key);
    const istListe = istTyp === undefined ? [] : ist.einstellungen.filter((e) => e.equipment_model_id === istTyp.id);
    const dateiKeys = new Set(g.settings.map((e) => e.key));
    for (const e of istListe) if (!dateiKeys.has(e.key)) gemeldet.einstellungen.push(`${g.key}.${e.key}`);
    return g.settings.map((e, j) => {
      const zeile = {
        geraetetyp: g.key,
        key: e.key,
        label: e.label,
        kind: e.kind,
        min_value: e.kind === "number" ? e.min : null,
        max_value: e.kind === "number" ? e.max : null,
        step_value: e.kind === "number" ? e.step : null,
        unit: e.kind === "number" ? e.unit : null,
        allowed_values: e.kind === "enum" ? e.allowed_values : null,
        sort_order: j + 1,
      };
      return vergleiche(`${g.key}.${e.key}`, zeile, istListe.find((x) => x.key === e.key), EINSTELLUNG_FELDER);
    });
  });

  const uebungen = k.exercises.map((u) =>
    vergleiche(
      u.key,
      { catalog_key: u.key, name: u.name, description: u.description, volume_kind: u.volume_kind, target_min: u.target_min, target_max: u.target_max },
      uebungNachKey.get(u.key),
      UEBUNG_FELDER,
    ),
  );

  const verknuepfungen: ImportPlan["verknuepfungen"] = [];
  const videos: ImportPlan["videos"] = [];
  for (const g of k.equipment) {
    const istTyp = typNachKey.get(g.key);
    const sollIds = new Set<string>();
    g.exercises.forEach((uKey, j) => {
      const istU = uebungNachKey.get(uKey);
      if (istU) sollIds.add(istU.id);
      const istV =
        istTyp && istU
          ? ist.verknuepfungen.find((v) => v.equipment_model_id === istTyp.id && v.exercise_id === istU.id)
          : undefined;
      const schluessel = `${g.key} > ${uKey}`;
      verknuepfungen.push(vergleiche(schluessel, { geraetetyp: g.key, uebung: uKey, sort_order: j + 1 }, istV, ["sort_order"]));

      // Nur Videos unter dem eigenen Praefix gehoeren dem Import; ein im
      // Portal ergaenztes Video an derselben Verknuepfung bleibt unberuehrt.
      const eigene = istV
        ? ist.videos.filter((x) => x.equipment_model_exercise_id === istV.id && x.storage_path.startsWith(videoPraefix(uKey)))
        : [];
      const medium = medien.videos.get(uKey);
      const video = uebungDatei.get(uKey)?.video ?? null;
      if (medium === undefined || video === null) {
        if (eigene.length > 0) gemeldet.videos.push(schluessel);
        return;
      }
      const posten = vergleiche(
        schluessel,
        { geraetetyp: g.key, uebung: uKey, storage_path: medium.storagePath, duration_s: video.duration_s },
        eigene[0],
        ["storage_path", "duration_s"],
      );
      if (posten.felder.includes("storage_path") && eigene[0]) ersetzt.add(`${VIDEO_BUCKET}/${eigene[0].storage_path}`);
      videos.push(posten);
    });
    if (istTyp) {
      for (const v of ist.verknuepfungen) {
        if (v.equipment_model_id === istTyp.id && !sollIds.has(v.exercise_id)) {
          gemeldet.verknuepfungen.push(`${g.key} > ${uebungNameNachId.get(v.exercise_id) ?? v.exercise_id}`);
        }
      }
    }
  }

  const typKeys = new Set(k.equipment.map((g) => g.key));
  const uebungKeys = new Set(k.exercises.map((u) => u.key));
  for (const g of ist.geraetetypen) {
    if (g.catalog_key === null) gemeldet.ohneSchluessel.push(`Geraetetyp "${g.name}"`);
    else if (!typKeys.has(g.catalog_key)) gemeldet.geraetetypen.push(g.catalog_key);
  }
  for (const u of ist.uebungen) {
    if (u.catalog_key === null) gemeldet.ohneSchluessel.push(`Uebung "${u.name}"`);
    else if (!uebungKeys.has(u.catalog_key)) gemeldet.uebungen.push(u.catalog_key);
  }
  gemeldet.ersetzteMedien = [...ersetzt];

  const uploads = [...medien.fotos.values(), ...medien.videos.values()].filter(
    (m) => !ist.objekte.has(`${m.bucket}/${m.storagePath}`),
  );

  return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, uploads, gemeldet };
}

const HOECHSTENS = 20;

/** Der Text fuer Trockenlauf und echten Lauf -- derselbe, damit man vergleichen kann. */
export function berichtText(plan: ImportPlan): string {
  const zeilen: string[] = [];
  const liste = (eintraege: string[]) => {
    for (const e of eintraege.slice(0, HOECHSTENS)) zeilen.push(`  ${e}`);
    if (eintraege.length > HOECHSTENS) zeilen.push(`  ... und ${eintraege.length - HOECHSTENS} weitere`);
  };
  const tabelle = (titel: string, posten: Posten<unknown>[]) => {
    const zahl = (art: Art) => posten.filter((p) => p.art === art).length;
    zeilen.push(`${titel}: ${zahl("neu")} neu, ${zahl("geaendert")} geaendert, ${zahl("unveraendert")} unveraendert`);
    liste(
      posten.flatMap((p) =>
        p.art === "neu" ? [`+ ${p.schluessel}`] : p.art === "geaendert" ? [`~ ${p.schluessel} (${p.felder.join(", ")})`] : [],
      ),
    );
  };
  const melden = (titel: string, eintraege: string[]) => {
    if (eintraege.length === 0) return;
    zeilen.push(`${titel}: ${eintraege.length}`);
    liste(eintraege.map((e) => `- ${e}`));
  };

  tabelle("Geraetetypen", plan.geraetetypen);
  tabelle("Einstellungen", plan.einstellungen);
  tabelle("Uebungen", plan.uebungen);
  tabelle("Verknuepfungen", plan.verknuepfungen);
  tabelle("Videos", plan.videos);
  const bytes = plan.uploads.reduce((summe, m) => summe + m.bytes.length, 0);
  zeilen.push(`Uploads: ${plan.uploads.length} Dateien (${(bytes / 1024 / 1024).toFixed(1)} MB)`);

  melden("Nur in der Datenbank, nicht geloescht -- Geraetetypen", plan.gemeldet.geraetetypen);
  melden("Nur in der Datenbank, nicht geloescht -- Uebungen", plan.gemeldet.uebungen);
  melden("Nur in der Datenbank, nicht geloescht -- Einstellungen", plan.gemeldet.einstellungen);
  melden("Nur in der Datenbank, nicht geloescht -- Verknuepfungen", plan.gemeldet.verknuepfungen);
  melden("Video in der Datei entfernt, in der Datenbank behalten", plan.gemeldet.videos);
  melden("Ersetzte Medienobjekte, nicht geloescht", plan.gemeldet.ersetzteMedien);
  melden("Katalogzeilen ohne Schluessel, nicht verwaltet", plan.gemeldet.ohneSchluessel);
  return zeilen.join("\n");
}
