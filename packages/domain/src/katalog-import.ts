import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { GYMTAVO_STUDIO_ID, type KatalogDatei } from "./katalog-datei.js";
import type { Medien, Medium } from "./katalog-medien.js";
import {
  planeImport,
  type ImportPlan,
  type IstEinstellung,
  type IstGeraetetyp,
  type IstStand,
  type IstUebung,
  type IstVerknuepfung,
  type IstVideo,
  type Posten,
} from "./katalog-plan.js";
import { PHOTO_BUCKET, VIDEO_BUCKET } from "./media.js";

/**
 * Der Katalogimport gegen eine echte Datenbank: Ist-Stand lesen, Plan
 * ausfuehren. Nur mit einem Service-Client sinnvoll -- deshalb wie
 * "@fitretro/domain/chargen" ein eigener Unterpfad, nicht der Hauptexport.
 *
 * Eine Transaktion ueber alles gibt es nicht (Spec 9.1, Weg 1). Das ist
 * vertretbar, weil jeder Schritt ein Upsert ist und nie geloescht wird: ein
 * abgebrochener Lauf hinterlaesst "noch nicht alles aktualisiert", und der
 * naechste Lauf setzt dort fort.
 */

export { GYMTAVO_STUDIO_ID, pruefeKatalog, type KatalogDatei } from "./katalog-datei.js";
export { pruefeMedien, type Medien, type Medium } from "./katalog-medien.js";
export { ladeKatalog } from "./katalog-laden.js";
export { berichtText, planeImport, type ImportPlan, type IstStand, type Posten } from "./katalog-plan.js";

/** PostgREST liefert hoechstens max_rows Zeilen (1000, supabase/config.toml). */
const BLOCK = 500;

type Antwort<T> = { data: T[] | null; error: { message: string } | null };

async function alleZeilen<T>(seite: (von: number, bis: number) => PromiseLike<Antwort<T>>): Promise<T[]> {
  const zeilen: T[] = [];
  for (let von = 0; ; von += BLOCK) {
    const { data, error } = await seite(von, von + BLOCK - 1);
    if (error) throw new DomainError("internal", error.message);
    zeilen.push(...(data ?? []));
    if ((data ?? []).length < BLOCK) return zeilen;
  }
}

async function objekteUnter(admin: SupabaseClient, bucket: string, ordner: string): Promise<string[]> {
  const pfade: string[] = [];
  for (let offset = 0; ; offset += BLOCK) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(ordner, { limit: BLOCK, offset, sortBy: { column: "name", order: "asc" } });
    if (error) throw new DomainError("internal", error.message);
    pfade.push(...data.map((o) => `${bucket}/${ordner}/${o.name}`));
    if (data.length < BLOCK) return pfade;
  }
}

export async function leseIstStand(admin: SupabaseClient): Promise<IstStand> {
  const studio = await admin.from("studios").select("id").eq("id", GYMTAVO_STUDIO_ID).eq("is_catalog", true).maybeSingle();
  if (studio.error) throw new DomainError("internal", studio.error.message);
  if (studio.data === null) {
    throw new DomainError("not_found", "Das Gymtavo-Studio fehlt. Zuerst die Migrationen bis 0048 anwenden.");
  }

  const geraetetypen = await alleZeilen<IstGeraetetyp>((von, bis) =>
    admin
      .from("equipment_models")
      .select("id, catalog_key, name, category, manufacturer, photo_path, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max")
      .eq("studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  // Gefiltert ueber das eingebettete Modell statt ueber eine id-Liste: eine
  // Liste von Hunderten UUIDs sprengte die URL-Laenge von PostgREST.
  const einstellungen = await alleZeilen<IstEinstellung>((von, bis) =>
    admin
      .from("equipment_setting_definitions")
      .select("id, equipment_model_id, key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order, equipment_models!inner(studio_id)")
      .eq("equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const uebungen = await alleZeilen<IstUebung>((von, bis) =>
    admin
      .from("exercises")
      .select("id, catalog_key, name, description, volume_kind, target_min, target_max")
      .eq("studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const verknuepfungen = await alleZeilen<IstVerknuepfung>((von, bis) =>
    admin
      .from("equipment_model_exercises")
      .select("id, equipment_model_id, exercise_id, sort_order, equipment_models!inner(studio_id)")
      .eq("equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const videos = await alleZeilen<IstVideo>((von, bis) =>
    admin
      .from("instruction_assets")
      .select("id, equipment_model_exercise_id, storage_path, duration_s, equipment_model_exercises!inner(equipment_models!inner(studio_id))")
      .eq("equipment_model_exercises.equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const objekte = new Set([
    ...(await objekteUnter(admin, PHOTO_BUCKET, `${GYMTAVO_STUDIO_ID}/catalog/photos`)),
    ...(await objekteUnter(admin, VIDEO_BUCKET, `${GYMTAVO_STUDIO_ID}/catalog/videos`)),
  ]);
  return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, objekte };
}

export type Geschrieben = {
  uploads: number;
  geraetetypen: number;
  einstellungen: number;
  uebungen: number;
  verknuepfungen: number;
  videos: number;
};

function zuSchreiben<Z>(liste: Posten<Z>[]): Posten<Z>[] {
  return liste.filter((p) => p.art !== "unveraendert");
}

function bloecke<T>(liste: T[]): T[][] {
  const ergebnis: T[][] = [];
  for (let i = 0; i < liste.length; i += BLOCK) ergebnis.push(liste.slice(i, i + BLOCK));
  return ergebnis;
}

function idVon(ids: ReadonlyMap<string, string>, schluessel: string): string {
  const id = ids.get(schluessel);
  if (id === undefined) throw new DomainError("internal", `Keine id fuer "${schluessel}".`);
  return id;
}

async function hochladen(admin: SupabaseClient, m: Medium): Promise<void> {
  const { error } = await admin.storage.from(m.bucket).upload(m.storagePath, m.bytes, { contentType: m.contentType, upsert: false });
  if (error === null) return;
  // Ein abgebrochener Lauf hat das Objekt vielleicht schon hochgeladen. Der
  // Pfad enthaelt den Inhaltshash, also liegt dort dieselbe Datei.
  const status = (error as { statusCode?: string }).statusCode;
  if (status === "409" || /exists|duplicate/i.test(error.message)) return;
  throw new DomainError("internal", `${m.datei}: Upload fehlgeschlagen (${error.message})`);
}

export async function fuehreAus(admin: SupabaseClient, plan: ImportPlan): Promise<Geschrieben> {
  // Medien zuerst: so zeigt nie ein Datensatz auf eine noch fehlende Datei.
  for (const m of plan.uploads) await hochladen(admin, m);

  const typIds = new Map(plan.geraetetypen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const type = zuSchreiben(plan.geraetetypen);
  for (const block of bloecke(type)) {
    const { data, error } = await admin
      .from("equipment_models")
      .upsert(block.map((p) => ({ studio_id: GYMTAVO_STUDIO_ID, ...p.zeile })), { onConflict: "studio_id,catalog_key" })
      .select("id, catalog_key");
    if (error) throw new DomainError("internal", `Geraetetypen: ${error.message}`);
    for (const z of data) typIds.set(z.catalog_key, z.id);
  }

  const einstellungen = zuSchreiben(plan.einstellungen);
  for (const block of bloecke(einstellungen)) {
    const zeilen = block.map((p) => {
      const { geraetetyp, ...zeile } = p.zeile;
      return { equipment_model_id: idVon(typIds, geraetetyp), ...zeile };
    });
    const { error } = await admin.from("equipment_setting_definitions").upsert(zeilen, { onConflict: "equipment_model_id,key" });
    if (error) throw new DomainError("internal", `Einstellungen: ${error.message}`);
  }

  const uebungIds = new Map(plan.uebungen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const uebungen = zuSchreiben(plan.uebungen);
  for (const block of bloecke(uebungen)) {
    const { data, error } = await admin
      .from("exercises")
      .upsert(block.map((p) => ({ studio_id: GYMTAVO_STUDIO_ID, ...p.zeile })), { onConflict: "studio_id,catalog_key" })
      .select("id, catalog_key");
    if (error) throw new DomainError("internal", `Uebungen: ${error.message}`);
    for (const z of data) uebungIds.set(z.catalog_key, z.id);
  }

  const linkIds = new Map(plan.verknuepfungen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const verknuepfungen = zuSchreiben(plan.verknuepfungen);
  for (const block of bloecke(verknuepfungen)) {
    const nachIds = new Map(
      block.map((p) => [`${idVon(typIds, p.zeile.geraetetyp)}|${idVon(uebungIds, p.zeile.uebung)}`, p.schluessel]),
    );
    const { data, error } = await admin
      .from("equipment_model_exercises")
      .upsert(
        block.map((p) => ({
          equipment_model_id: idVon(typIds, p.zeile.geraetetyp),
          exercise_id: idVon(uebungIds, p.zeile.uebung),
          sort_order: p.zeile.sort_order,
        })),
        { onConflict: "equipment_model_id,exercise_id" },
      )
      .select("id, equipment_model_id, exercise_id");
    if (error) throw new DomainError("internal", `Verknuepfungen: ${error.message}`);
    for (const z of data) linkIds.set(idVon(nachIds, `${z.equipment_model_id}|${z.exercise_id}`), z.id);
  }

  const videos = zuSchreiben(plan.videos);
  for (const p of videos) {
    const werte = { storage_path: p.zeile.storage_path, duration_s: p.zeile.duration_s };
    const { error } =
      p.id === null
        ? await admin.from("instruction_assets").insert({ equipment_model_exercise_id: idVon(linkIds, p.schluessel), kind: "video", ...werte })
        : await admin.from("instruction_assets").update(werte).eq("id", p.id);
    if (error) throw new DomainError("internal", `Video ${p.schluessel}: ${error.message}`);
  }

  return {
    uploads: plan.uploads.length,
    geraetetypen: type.length,
    einstellungen: einstellungen.length,
    uebungen: uebungen.length,
    verknuepfungen: verknuepfungen.length,
    videos: videos.length,
  };
}

export async function importiereKatalog(
  admin: SupabaseClient,
  katalog: KatalogDatei,
  medien: Medien,
  optionen: { trocken: boolean },
): Promise<{ plan: ImportPlan; geschrieben: Geschrieben | null }> {
  const plan = planeImport(katalog, medien, await leseIstStand(admin));
  if (optionen.trocken) return { plan, geschrieben: null };
  return { plan, geschrieben: await fuehreAus(admin, plan) };
}
