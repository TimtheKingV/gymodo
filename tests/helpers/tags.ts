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

  const datensaetze = zeilen.map((zeile, index) => ({
    studio_id: zeile.studioId ?? null,
    machine_id: zeile.machineId ?? null,
    kind: zeile.kind ?? "machine",
    status: zeile.status ?? "unassigned",
    token: tokens[index]!,
  }));

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
