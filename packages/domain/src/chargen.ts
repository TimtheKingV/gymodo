import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { createTagToken } from "./tags.js";

/**
 * Die Betreiberseite des Tokenraums: Chargen herstellen, an Studios ausliefern,
 * Bestand nachrechnen. Kein Bildschirm, kein Portal-Aufruf -- diese Funktionen
 * ergeben nur mit einem Service-Client Sinn und sind deshalb ueber den
 * Unterpfad "@fitretro/domain/chargen" erreichbar, nicht ueber den Hauptexport.
 *
 * Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 4.
 */

export type TagSorte = "machine" | "studio";

export type Charge = {
  id: string;
  code: string;
  kind: TagSorte;
  quantity: number;
  scrappedAt: string | null;
};

type ChargenZeile = {
  id: string;
  code: string;
  kind: TagSorte;
  quantity: number;
  scrapped_at: string | null;
};

/**
 * PostgREST liefert hoechstens max_rows Zeilen (1000, supabase/config.toml).
 * Eine Tausendercharge traefe die Grenze exakt und waere still abgeschnitten,
 * also wird in kleineren Bloecken gelesen und geschrieben.
 */
const BLOCK = 500;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function zuCharge(zeile: ChargenZeile): Charge {
  return {
    id: zeile.id,
    code: zeile.code,
    kind: zeile.kind,
    quantity: zeile.quantity,
    scrappedAt: zeile.scrapped_at,
  };
}

export async function chargeLesen(
  admin: SupabaseClient,
  code: string,
): Promise<Charge> {
  const { data, error } = await admin
    .from("tag_batches")
    .select("id, code, kind, quantity, scrapped_at")
    .eq("code", code)
    .maybeSingle<ChargenZeile>();
  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", `Die Charge ${code} gibt es nicht.`);
  return zuCharge(data);
}

export async function chargeAnlegen(
  admin: SupabaseClient,
  eingabe: {
    code: string;
    kind: TagSorte;
    menge: number;
    lieferant?: string | null | undefined;
    bestelltAm?: string | null | undefined;
  },
): Promise<Charge> {
  if (!Number.isInteger(eingabe.menge) || eingabe.menge < 1) {
    throw new DomainError("validation_failed", "Die Menge ist eine ganze Zahl ab 1.");
  }
  if (eingabe.code.trim() === "") {
    throw new DomainError("validation_failed", "Die Charge braucht einen Code.");
  }

  const { data, error } = await admin
    .from("tag_batches")
    .insert({
      code: eingabe.code,
      kind: eingabe.kind,
      quantity: eingabe.menge,
      supplier: eingabe.lieferant ?? null,
      ordered_on: eingabe.bestelltAm ?? null,
    })
    .select("id, code, kind, quantity, scrapped_at")
    .single<ChargenZeile>();

  if (error?.code === "23505") {
    throw new DomainError("conflict", `Die Charge ${eingabe.code} gibt es schon.`);
  }
  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Charge nicht angelegt.");
  }

  for (let von = 1; von <= eingabe.menge; von += BLOCK) {
    const bis = Math.min(von + BLOCK - 1, eingabe.menge);
    await blockSchreiben(admin, data.id, eingabe.kind, von, bis);
  }

  return zuCharge(data);
}

/**
 * Ein Kollisionstreffer auf token ist bei 128 Bit astronomisch unwahrscheinlich
 * -- aber ein Abbruch mitten in einer Tausendercharge waere teurer als diese
 * vier Zeilen, weil die halb geschriebene Charge von Hand aufzuraeumen waere.
 */
async function blockSchreiben(
  admin: SupabaseClient,
  batchId: string,
  kind: TagSorte,
  von: number,
  bis: number,
): Promise<void> {
  for (let versuch = 0; versuch < 5; versuch += 1) {
    const zeilen = [];
    for (let nummer = von; nummer <= bis; nummer += 1) {
      zeilen.push({
        batch_id: batchId,
        batch_index: nummer,
        kind,
        token: createTagToken(),
        status: "unassigned",
        studio_id: null,
      });
    }
    const { error } = await admin.from("machine_tags").insert(zeilen);
    if (!error) return;
    if (error.code !== "23505") throw new DomainError("internal", error.message);
  }
  throw new DomainError(
    "internal",
    `Block ${von}-${bis} liess sich nach fuenf Versuchen nicht schreiben.`,
  );
}

export async function chargeZeilen(
  admin: SupabaseClient,
  code: string,
): Promise<{ charge: Charge; zeilen: Array<{ nummer: number; token: string }> }> {
  const charge = await chargeLesen(admin, code);
  const zeilen: Array<{ nummer: number; token: string }> = [];

  for (let versatz = 0; ; versatz += BLOCK) {
    const { data, error } = await admin
      .from("machine_tags")
      .select("batch_index, token")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true })
      .range(versatz, versatz + BLOCK - 1);
    if (error) throw new DomainError("internal", error.message);

    const block = (data ?? []) as Array<{ batch_index: number; token: string }>;
    for (const reihe of block) {
      zeilen.push({ nummer: reihe.batch_index, token: reihe.token });
    }
    if (block.length < BLOCK) break;
  }

  return { charge, zeilen };
}

export async function chargeVerschrotten(
  admin: SupabaseClient,
  code: string,
): Promise<void> {
  const charge = await chargeLesen(admin, code);
  if (charge.scrappedAt) {
    throw new DomainError("conflict", `Die Charge ${code} ist bereits verschrottet.`);
  }
  const { error } = await admin
    .from("tag_batches")
    .update({ scrapped_at: new Date().toISOString() })
    .eq("id", charge.id);
  if (error) throw new DomainError("internal", error.message);
}

export async function lieferungAnlegen(
  admin: SupabaseClient,
  eingabe: {
    chargeCode: string;
    studioId: string;
    menge?: number | undefined;
    nummern?: number[] | undefined;
  },
): Promise<{ id: string; menge: number }> {
  const charge = await chargeLesen(admin, eingabe.chargeCode);
  if (charge.scrappedAt) {
    throw new DomainError(
      "conflict",
      `Die Charge ${charge.code} ist verschrottet und liefert nichts mehr.`,
    );
  }

  const hatMenge = eingabe.menge !== undefined;
  const hatNummern = eingabe.nummern !== undefined && eingabe.nummern.length > 0;
  if (hatMenge === hatNummern) {
    throw new DomainError(
      "validation_failed",
      "Entweder eine Menge oder eine Nummernliste, nie beides.",
    );
  }
  if (charge.kind === "machine" && !hatMenge) {
    throw new DomainError(
      "validation_failed",
      "Geraetetags werden mit einer Menge geliefert, nicht mit Nummern -- sie lernen ihr Studio erst beim Scan.",
    );
  }
  if (charge.kind === "studio" && !hatNummern) {
    throw new DomainError(
      "validation_failed",
      "Aushangschilder werden mit ihren aufgedruckten Nummern geliefert, nicht mit einer Menge.",
    );
  }

  const menge = hatMenge ? eingabe.menge! : eingabe.nummern!.length;
  if (!Number.isInteger(menge) || menge < 1) {
    throw new DomainError("validation_failed", "Die Menge ist eine ganze Zahl ab 1.");
  }

  let schonGeliefert = 0;
  for (let versatz = 0; ; versatz += BLOCK) {
    const { data: block, error: blockFehler } = await admin
      .from("tag_shipments")
      .select("quantity")
      .eq("batch_id", charge.id)
      .range(versatz, versatz + BLOCK - 1);
    if (blockFehler) throw new DomainError("internal", blockFehler.message);
    for (const zeile of block ?? []) schonGeliefert += zeile.quantity;
    if ((block ?? []).length < BLOCK) break;
  }
  if (schonGeliefert + menge > charge.quantity) {
    throw new DomainError(
      "conflict",
      `Die Charge ${charge.code} hat ${charge.quantity} Tags, davon sind ${schonGeliefert} ausgeliefert. ${menge} passen nicht mehr hinein.`,
    );
  }

  // Erst die Schilder aktivieren, dann die Lieferzeile schreiben. Bricht der
  // zweite Schritt ab, fehlen sie in der Vorratsanzeige -- sie funktionieren
  // aber. Andersherum verspraeche der Vorrat Schilder, die nicht gelten.
  if (charge.kind === "studio") {
    await schilderAktivieren(admin, charge, eingabe.studioId, eingabe.nummern!);
  }

  const { data, error } = await admin
    .from("tag_shipments")
    .insert({ batch_id: charge.id, studio_id: eingabe.studioId, quantity: menge })
    .select("id")
    .single<{ id: string }>();
  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Lieferung nicht angelegt.");
  }

  return { id: data.id, menge };
}

async function schilderAktivieren(
  admin: SupabaseClient,
  charge: Charge,
  studioId: string,
  nummern: number[],
): Promise<void> {
  const { data, error } = await admin
    .from("machine_tags")
    .select("batch_index, studio_id, status")
    .eq("batch_id", charge.id)
    .in("batch_index", nummern);
  if (error) throw new DomainError("internal", error.message);

  const gefunden = (data ?? []) as Array<{
    batch_index: number;
    studio_id: string | null;
    status: string;
  }>;

  const untauglich = [
    ...nummern.filter((nummer) => !gefunden.some((zeile) => zeile.batch_index === nummer)),
    ...gefunden
      .filter((zeile) => zeile.studio_id !== null || zeile.status !== "unassigned")
      .map((zeile) => zeile.batch_index),
  ].sort((a, b) => a - b);

  if (untauglich.length > 0) {
    throw new DomainError(
      "conflict",
      `Diese Nummern sind in Charge ${charge.code} nicht lieferbar: ${untauglich.join(", ")}.`,
    );
  }

  const { error: schreibFehler } = await admin
    .from("machine_tags")
    .update({ studio_id: studioId, status: "active" })
    .eq("batch_id", charge.id)
    .in("batch_index", nummern);
  if (schreibFehler) throw new DomainError("internal", schreibFehler.message);
}

export async function bestand(
  admin: SupabaseClient,
  studioId: string,
): Promise<{ geliefert: number; verbraucht: number; vorraetig: number }> {
  let geliefert = 0;
  for (let versatz = 0; ; versatz += BLOCK) {
    const { data: block, error: blockFehler } = await admin
      .from("tag_shipments")
      .select("quantity, tag_batches!inner (kind)")
      .eq("studio_id", studioId)
      .eq("tag_batches.kind", "machine")
      .range(versatz, versatz + BLOCK - 1);
    if (blockFehler) throw new DomainError("internal", blockFehler.message);
    for (const zeile of block ?? []) geliefert += zeile.quantity;
    if ((block ?? []).length < BLOCK) break;
  }

  const { count, error: zaehlFehler } = await admin
    .from("machine_tags")
    .select("id", { count: "exact", head: true })
    .eq("studio_id", studioId)
    .eq("kind", "machine");
  if (zaehlFehler) throw new DomainError("internal", zaehlFehler.message);

  const verbraucht = count ?? 0;
  return { geliefert, verbraucht, vorraetig: geliefert - verbraucht };
}

export async function studioAufloesen(
  admin: SupabaseClient,
  bezeichnung: string,
): Promise<string> {
  if (UUID.test(bezeichnung)) {
    const { data, error } = await admin
      .from("studios")
      .select("id")
      .eq("id", bezeichnung)
      .maybeSingle<{ id: string }>();
    if (error) throw new DomainError("internal", error.message);
    if (!data) throw new DomainError("not_found", "Dieses Studio gibt es nicht.");
    return data.id;
  }

  const { data, error } = await admin
    .from("studios")
    .select("id, name")
    .eq("name", bezeichnung);
  if (error) throw new DomainError("internal", error.message);

  const treffer = (data ?? []) as Array<{ id: string; name: string }>;
  if (treffer.length === 0) {
    throw new DomainError("not_found", `Kein Studio heisst "${bezeichnung}".`);
  }
  if (treffer.length > 1) {
    throw new DomainError(
      "conflict",
      `Mehrere Studios heissen "${bezeichnung}": ${treffer.map((zeile) => zeile.id).join(", ")}. Nimm die UUID.`,
    );
  }
  return treffer[0]!.id;
}
