import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { requireStudioStaff } from "./studio.js";

/**
 * Leute -- Mitglieder und Mitarbeiter eines Studios, Spec
 * 2026-08-31-trainerportal-struktur-design.md Abschnitt 2 und 7.
 *
 * Der Beitritt per Code laeuft wie der Scan (join_studio_by_tag, 0023) ueber
 * eine SECURITY DEFINER-Funktion, nicht ueber eine Insert-Policy. Rollen-
 * wechsel und Entfernen laufen ueber gewoehnliche Policies (0031) -- der
 * nutzergebundene Client reicht, RLS haelt die Inhaberzeile unerreichbar.
 */

function parseOrThrow<T extends z.ZodTypeAny>(schema: T, input: unknown): z.infer<T> {
  const parsed = schema.safeParse(input);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  return parsed.data;
}

export type StudioMember = {
  userId: string;
  email: string;
  role: "owner" | "trainer" | "member";
  joinedAt: string;
};

export async function listStudioMembers(
  client: SupabaseClient,
  studioId: string,
): Promise<StudioMember[]> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client.rpc("list_studio_members", { p_studio_id: studioId });
  if (error) throw new DomainError("internal", error.message);

  return (data ?? []).map(
    (zeile: { user_id: string; email: string; role: string; joined_at: string }) => ({
      userId: zeile.user_id,
      email: zeile.email,
      role: zeile.role as StudioMember["role"],
      joinedAt: zeile.joined_at,
    }),
  );
}

const codeSchema = z.string().trim().min(1, "Bitte einen Code eingeben.");

/**
 * Unbekannt und gesperrt antworten identisch -- derselbe Grund wie bei
 * join_studio_by_tag: eine unterschiedliche Antwort machte den Code erratbar.
 */
export async function joinStudioByCode(
  client: SupabaseClient,
  code: string,
): Promise<{ studioId: string; joined: boolean }> {
  const parsed = parseOrThrow(codeSchema, code);
  const { data, error } = await client.rpc("join_studio_by_code", { p_code: parsed });
  if (error) throw new DomainError("internal", error.message);

  const zeile = (data ?? [])[0] as { studio_id: string; joined: boolean } | undefined;
  if (!zeile) {
    throw new DomainError("not_found", "Dieser Code ist ungueltig.");
  }
  return { studioId: zeile.studio_id, joined: zeile.joined };
}

export async function regenerateStudioJoinCode(
  client: SupabaseClient,
  studioId: string,
): Promise<string> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client.rpc("regenerate_studio_join_code", {
    p_studio_id: studioId,
  });
  if (error) throw new DomainError("internal", error.message);
  return data as string;
}

export async function setStudioJoinCodeActive(
  client: SupabaseClient,
  studioId: string,
  active: boolean,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { error } = await client.rpc("set_studio_join_code_active", {
    p_studio_id: studioId,
    p_active: active,
  });
  if (error) throw new DomainError("internal", error.message);
}

const roleSchema = z.enum(["member", "trainer"]);

/**
 * Nur die beiden Rollen unterhalb des Inhabers: memberships_update_staff
 * (0031) laesst eine Inhaberzeile ohnehin nicht zu. Diese Zod-Pruefung
 * sorgt nur fuer eine verstaendliche Meldung statt eines rohen Fehlers,
 * traefe hier je "owner" ein.
 */
export async function setMembershipRole(
  client: SupabaseClient,
  studioId: string,
  targetUserId: string,
  role: "member" | "trainer",
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);
  const parsedRole = parseOrThrow(roleSchema, role);

  const { data, error } = await client
    .from("studio_memberships")
    .update({ role: parsedRole })
    .eq("studio_id", studioId)
    .eq("user_id", targetUserId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError(
      "not_found",
      "Diese Mitgliedschaft gibt es nicht, oder sie gehoert dem Inhaber.",
    );
  }
}

export async function removeMembership(
  client: SupabaseClient,
  studioId: string,
  targetUserId: string,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client
    .from("studio_memberships")
    .delete()
    .eq("studio_id", studioId)
    .eq("user_id", targetUserId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError(
      "not_found",
      "Diese Mitgliedschaft gibt es nicht, oder sie gehoert dem Inhaber.",
    );
  }
}
