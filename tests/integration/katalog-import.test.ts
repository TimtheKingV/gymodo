import { afterAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";
import {
  GYMTAVO_STUDIO_ID,
  fuehreAus,
  importiereKatalog,
  leseIstStand,
  planeImport,
  pruefeKatalog,
  pruefeMedien,
  type Posten,
} from "@fitretro/domain/katalog-import";
import { beispielKatalog, mp4Bytes, pngBytes } from "@fitretro/domain/katalog-testdaten";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
// Die lokale Datenbank teilen sich mehrere Sitzungen: jeder Block arbeitet
// mit eigenem Praefix und raeumt nur seine eigenen Zeilen und Objekte ab.
const admin = serviceClient();
const praefixe: string[] = [];
const objekte = new Set<string>();

function neuerPraefix(): string {
  const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
  praefixe.push(p);
  return p;
}

function geladen(beispiel: ReturnType<typeof beispielKatalog>) {
  const k = pruefeKatalog(beispiel.roh);
  if (!k.ok) throw new Error(k.fehler.join("\n"));
  const m = pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  if (!m.ok) throw new Error(m.fehler.join("\n"));
  return { katalog: k.wert, medien: m.wert };
}

async function importiere(beispiel: ReturnType<typeof beispielKatalog>, trocken = false) {
  const { katalog, medien } = geladen(beispiel);
  const ergebnis = await importiereKatalog(admin, katalog, medien, { trocken });
  if (!trocken) for (const m of ergebnis.plan.uploads) objekte.add(`${m.bucket}/${m.storagePath}`);
  return ergebnis;
}

function eigene<Z>(liste: Posten<Z>[], p: string): Posten<Z>[] {
  return liste.filter((x) => x.schluessel.startsWith(p));
}

async function modell(key: string) {
  const { data, error } = await admin.from("equipment_models").select("*").eq("studio_id", GYMTAVO_STUDIO_ID).eq("catalog_key", key).single();
  if (error) throw error;
  return data;
}

async function uebungId(key: string): Promise<string> {
  const { data, error } = await admin.from("exercises").select("id").eq("studio_id", GYMTAVO_STUDIO_ID).eq("catalog_key", key).single();
  if (error) throw error;
  return data.id;
}

async function verknuepfung(typKey: string, uebungKey: string) {
  const typ = await modell(typKey);
  const { data, error } = await admin
    .from("equipment_model_exercises")
    .select("id, sort_order, instruction_assets(id, storage_path, duration_s)")
    .eq("equipment_model_id", typ.id)
    .eq("exercise_id", await uebungId(uebungKey))
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function objektDa(bucketUndPfad: string): Promise<boolean> {
  const [bucket, ...rest] = bucketUndPfad.split("/");
  const { error } = await admin.storage.from(bucket!).download(rest.join("/"));
  return error === null;
}

afterAll(async () => {
  for (const p of praefixe) {
    const muster = `${p.replaceAll("_", "\\_")}%`;
    // Einstellungen und Verknuepfungen haengen per Kaskade an Typ und Uebung,
    // Videos verweisen mit restrict auf die Verknuepfung: sie gehen zuerst.
    const typen = await admin.from("equipment_models").select("id").eq("studio_id", GYMTAVO_STUDIO_ID).like("catalog_key", muster);
    const typIds = (typen.data ?? []).map((t) => t.id);
    if (typIds.length > 0) {
      const links = await admin.from("equipment_model_exercises").select("id").in("equipment_model_id", typIds);
      const linkIds = (links.data ?? []).map((l) => l.id);
      if (linkIds.length > 0) await admin.from("instruction_assets").delete().in("equipment_model_exercise_id", linkIds);
    }
    await admin.from("equipment_models").delete().eq("studio_id", GYMTAVO_STUDIO_ID).like("catalog_key", muster);
    await admin.from("exercises").delete().eq("studio_id", GYMTAVO_STUDIO_ID).like("catalog_key", muster);
  }
  const nachBucket = new Map<string, string[]>();
  for (const o of objekte) {
    const [bucket, ...rest] = o.split("/");
    nachBucket.set(bucket!, [...(nachBucket.get(bucket!) ?? []), rest.join("/")]);
  }
  for (const [bucket, pfade] of nachBucket) await admin.storage.from(bucket).remove(pfade);
});

describe("Katalogimport", () => {
  const p = neuerPraefix();
  const beispiel = beispielKatalog(p);
  let erstesTrizepsVideo = "";

  it("legt beim ersten Lauf alles an", async () => {
    const { plan, geschrieben } = await importiere(beispiel);

    expect(eigene(plan.geraetetypen, p).map((x) => x.art)).toEqual(["neu", "neu", "neu"]);
    expect(geschrieben).toEqual({ uploads: 3, geraetetypen: 3, einstellungen: 2, uebungen: 3, verknuepfungen: 4, videos: 3 });

    const laufband = await modell(`${p}laufband`);
    expect(laufband).toMatchObject({ category: "cardio", load_unit: "kmh", manufacturer: "Precor", secondary_unit: "pct" });
    expect(Number(laufband.load_step)).toBe(0.1);

    const brustpresse = await modell(`${p}brustpresse`);
    expect(await objektDa(`equipment-photos/${brustpresse.photo_path}`)).toBe(true);

    const a = await verknuepfung(`${p}brustpresse`, `${p}trizeps_druecken`);
    const b = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    expect(a?.sort_order).toBe(2);
    expect(a?.instruction_assets).toHaveLength(1);
    expect(b?.instruction_assets).toEqual(a?.instruction_assets.map((v) => ({ ...v, id: expect.any(String) })));
    erstesTrizepsVideo = a!.instruction_assets[0]!.storage_path;
  });

  it("aendert beim zweiten Lauf nichts", async () => {
    const vorher = await modell(`${p}laufband`);
    const { plan, geschrieben } = await importiere(beispiel);

    for (const liste of [plan.geraetetypen, plan.einstellungen, plan.uebungen, plan.verknuepfungen, plan.videos]) {
      expect(eigene<unknown>(liste, p).every((x) => x.art === "unveraendert")).toBe(true);
    }
    expect(geschrieben).toEqual({ uploads: 0, geraetetypen: 0, einstellungen: 0, uebungen: 0, verknuepfungen: 0, videos: 0 });
    expect((await modell(`${p}laufband`)).updated_at).toBe(vorher.updated_at);
  });

  it("uebernimmt Aenderungen und meldet das ersetzte Video", async () => {
    beispiel.roh.equipment[0]!.name = "Brustpresse neu";
    beispiel.roh.equipment[2]!.load_step = 0.5;
    beispiel.dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 99));

    const { plan } = await importiere(beispiel);

    expect(eigene(plan.geraetetypen, p).map((x) => x.felder)).toEqual([["name"], [], ["load_step"]]);
    expect(plan.gemeldet.ersetzteMedien).toContain(`instruction-videos/${erstesTrizepsVideo}`);
    const a = await verknuepfung(`${p}brustpresse`, `${p}trizeps_druecken`);
    const b = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    expect(a?.instruction_assets[0]?.storage_path).not.toBe(erstesTrizepsVideo);
    expect(b?.instruction_assets[0]?.storage_path).toBe(a?.instruction_assets[0]?.storage_path);
    expect(await objektDa(`instruction-videos/${erstesTrizepsVideo}`)).toBe(true);
  });

  it("meldet Entferntes nur und loescht nichts", async () => {
    beispiel.roh.equipment[0]!.settings.pop();
    beispiel.roh.equipment[2]!.exercises = [];
    beispiel.roh.exercises.splice(2, 1);

    const { plan } = await importiere(beispiel);

    expect(plan.gemeldet.einstellungen).toContain(`${p}brustpresse.griff`);
    expect(plan.gemeldet.uebungen).toContain(`${p}gehen`);
    expect(plan.gemeldet.verknuepfungen).toContain(`${p}laufband > ${p}gehen`);
    expect(await verknuepfung(`${p}laufband`, `${p}gehen`)).not.toBeNull();
    const { data } = await admin.from("equipment_setting_definitions").select("key").eq("equipment_model_id", (await modell(`${p}brustpresse`)).id);
    expect(data?.map((e) => e.key).sort()).toEqual(["griff", "sitzhoehe"]);
  });
});

describe("Trockenlauf", () => {
  it("laedt nichts hoch und schreibt nichts", async () => {
    const p = neuerPraefix();
    const { plan, geschrieben } = await importiere(beispielKatalog(p), true);

    expect(geschrieben).toBeNull();
    expect(eigene(plan.geraetetypen, p).map((x) => x.art)).toEqual(["neu", "neu", "neu"]);
    const { data } = await admin.from("equipment_models").select("id").like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
    expect(data).toEqual([]);
    for (const m of plan.uploads.filter((u) => u.storagePath.includes(p))) {
      expect(await objektDa(`${m.bucket}/${m.storagePath}`)).toBe(false);
    }
  });
});

describe("Fremdes, Abbrueche und vorhandene Objekte", () => {
  const p = neuerPraefix();
  const beispiel = beispielKatalog(p);

  it("laesst ein im Portal hochgeladenes Video unberuehrt", async () => {
    await importiere(beispiel);
    const link = await verknuepfung(`${p}brustpresse`, `${p}brustpresse_neutral`);
    const fremd = await admin
      .from("instruction_assets")
      .insert({ equipment_model_exercise_id: link!.id, kind: "video", storage_path: `${GYMTAVO_STUDIO_ID}/portal/${p}eigen.mp4`, duration_s: 10 })
      .select("id")
      .single();
    if (fremd.error) throw fremd.error;
    beispiel.dateien.set("media/videos/brustpresse_neutral.mp4", mp4Bytes(6, 55));

    await importiere(beispiel);

    const nachher = await verknuepfung(`${p}brustpresse`, `${p}brustpresse_neutral`);
    expect(nachher?.instruction_assets).toHaveLength(2);
    expect(nachher?.instruction_assets.find((v) => v.id === fremd.data.id)).toMatchObject({ duration_s: 10, storage_path: `${GYMTAVO_STUDIO_ID}/portal/${p}eigen.mp4` });
  });

  it("setzt nach einem Abbruch fort", async () => {
    const link = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    // Ein Lauf, der nach den Verknuepfungen abbrach: Video und Verknuepfung
    // fehlen. instruction_assets verweist mit restrict, also zuerst das Video.
    expect((await admin.from("instruction_assets").delete().eq("equipment_model_exercise_id", link!.id)).error).toBeNull();
    expect((await admin.from("equipment_model_exercises").delete().eq("id", link!.id)).error).toBeNull();

    const { plan } = await importiere(beispiel);

    expect(eigene(plan.verknuepfungen, p).filter((x) => x.art === "neu").map((x) => x.schluessel)).toEqual([`${p}trizepsmaschine > ${p}trizeps_druecken`]);
    expect(eigene(plan.videos, p).filter((x) => x.art === "neu").map((x) => x.schluessel)).toEqual([`${p}trizepsmaschine > ${p}trizeps_druecken`]);
    expect((await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`))?.instruction_assets).toHaveLength(1);
  });

  it("nimmt ein schon hochgeladenes Objekt hin", async () => {
    beispiel.dateien.set("media/photos/brustpresse.png", pngBytes(4242));
    const { katalog, medien } = geladen(beispiel);
    const plan = planeImport(katalog, medien, await leseIstStand(admin));
    const foto = plan.uploads.find((m) => m.bucket === "equipment-photos")!;
    objekte.add(`${foto.bucket}/${foto.storagePath}`);
    const vorab = await admin.storage.from(foto.bucket).upload(foto.storagePath, foto.bytes, { contentType: foto.contentType });
    expect(vorab.error).toBeNull();

    await fuehreAus(admin, plan);

    expect((await modell(`${p}brustpresse`)).photo_path).toBe(foto.storagePath);
  });
});
