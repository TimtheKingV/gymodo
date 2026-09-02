import type { SupabaseClient } from "@supabase/supabase-js";
import { createTagToken } from "@fitretro/domain";

export type TagSorte = "machine" | "studio";
export type TagStatus = "unassigned" | "active" | "revoked" | "replaced";

export type TagZeile = {
  studioId?: string | null | undefined;
  machineId?: string | null | undefined;
  kind?: TagSorte | undefined;
  status?: TagStatus | undefined;
  /** Vorgegebener Token, wenn der Test ihn danach selbst benutzt. */
  token?: string | undefined;
};

export type AngelegterTag = { id: string; token: string };

type ChargenEintrag = { id: string; naechsteNummer: number };

const chargen = new Map<TagSorte, ChargenEintrag>();

/**
 * Eine Charge je Sorte und Testdatei. Sie ist gross genug, dass keine Datei
 * sie ausschoepft, und die laufende Nummer zaehlt hoch -- (batch_id,
 * batch_index) ist unique.
 */
export async function chargeFuerTest(
  admin: SupabaseClient,
  kind: TagSorte,
): Promise<ChargenEintrag> {
  const vorhanden = chargen.get(kind);
  if (vorhanden) return vorhanden;

  const { data, error } = await admin
    .from("tag_batches")
    .insert({ code: `test-${kind}-${crypto.randomUUID()}`, kind, quantity: 10_000 })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;

  const eintrag: ChargenEintrag = { id: data.id, naechsteNummer: 1 };
  chargen.set(kind, eintrag);
  return eintrag;
}

/**
 * Eine machine_tags-Zeile fuer einen Test anlegen -- mit dem Service-Client,
 * also an RLS vorbei.
 *
 * Der einzige Ort im Testbestand, der die Spaltenform von machine_tags kennt.
 * Das ist Absicht: der Tokenraum und die Chargenspalten aendern sich in diesem
 * Plan zweimal, und beide Male soll genau diese Datei sich aendern.
 */
export async function tagAnlegen(
  admin: SupabaseClient,
  zeile: TagZeile = {},
): Promise<AngelegterTag> {
  const [ergebnis] = await tagsAnlegen(admin, [zeile]);
  return ergebnis!;
}

export async function tagsAnlegen(
  admin: SupabaseClient,
  zeilen: TagZeile[],
): Promise<AngelegterTag[]> {
  const tokens = zeilen.map((zeile) => zeile.token ?? createTagToken());

  const nachSorte = new Map<TagSorte, ChargenEintrag>();
  for (const zeile of zeilen) {
    const kind = zeile.kind ?? "machine";
    if (!nachSorte.has(kind)) nachSorte.set(kind, await chargeFuerTest(admin, kind));
  }

  const datensaetze = zeilen.map((zeile, index) => {
    const kind = zeile.kind ?? "machine";
    const charge = nachSorte.get(kind)!;
    return {
      studio_id: zeile.studioId ?? null,
      machine_id: zeile.machineId ?? null,
      kind,
      status: zeile.status ?? "unassigned",
      token: tokens[index]!,
      batch_id: charge.id,
      batch_index: charge.naechsteNummer++,
    };
  });

  const { data, error } = await admin
    .from("machine_tags")
    .insert(datensaetze)
    .select("id");
  if (error) throw error;

  return (data ?? []).map((reihe: { id: string }, index) => ({
    id: reihe.id,
    token: tokens[index]!,
  }));
}
